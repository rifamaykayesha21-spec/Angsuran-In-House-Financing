-- =====================================================================
-- 02_functions_triggers.sql  |  Logika bisnis & jurnal otomatis
-- =====================================================================

-- ---------- Validasi: total debit = total kredit per jurnal ----------
create or replace function fn_check_journal_balance() returns trigger
language plpgsql as $$
declare
  v_jid uuid := coalesce(new.journal_id, old.journal_id);
  v_d numeric; v_c numeric;
begin
  select coalesce(sum(debit),0), coalesce(sum(credit),0) into v_d, v_c
  from journal_lines where journal_id = v_jid;
  if v_d <> v_c then
    raise exception 'Jurnal tidak balance (debit %, kredit %)', v_d, v_c;
  end if;
  return null;
end $$;

drop trigger if exists trg_journal_balance on journal_lines;
create constraint trigger trg_journal_balance
  after insert or update or delete on journal_lines
  deferrable initially deferred
  for each row execute function fn_check_journal_balance();

-- ---------- Helper: buat header + baris jurnal ----------
create or replace function fn_post_line(p_journal uuid, p_account text, p_debit numeric, p_credit numeric)
returns void language plpgsql as $$
begin
  if coalesce(p_debit,0) = 0 and coalesce(p_credit,0) = 0 then return; end if;
  insert into journal_lines(journal_id, account_code, debit, credit)
  values (p_journal, p_account, coalesce(p_debit,0), coalesce(p_credit,0));
end $$;

-- =====================================================================
-- create_contract : buat kontrak + jadwal angsuran + jurnal penjualan kredit
-- Bunga flat: total bunga = pokok x rate/100 x tenor/12
-- =====================================================================
create or replace function create_contract(
  p_customer_id   uuid,
  p_product_id    uuid,
  p_contract_date date,
  p_down_payment  numeric,
  p_annual_rate   numeric,
  p_tenor         int,
  p_late_fee_rate numeric default 0.1
) returns uuid
language plpgsql as $$
declare
  v_cash numeric; v_cost numeric;
  v_fin numeric; v_int numeric; v_total numeric;
  v_id uuid; v_jid uuid;
  v_pp numeric; v_ip numeric; v_sum_p numeric := 0; v_sum_i numeric := 0;
  i int;
begin
  select cash_price, cost_price into v_cash, v_cost from products where product_id = p_product_id;
  if not found then raise exception 'Produk tidak ditemukan'; end if;
  if not exists (select 1 from customers where customer_id = p_customer_id) then
    raise exception 'Pelanggan tidak ditemukan';
  end if;
  if p_down_payment < 0 or p_down_payment >= v_cash then
    raise exception 'Uang muka harus >= 0 dan lebih kecil dari harga tunai';
  end if;
  if p_tenor < 1 then raise exception 'Tenor minimal 1 bulan'; end if;

  v_fin   := v_cash - p_down_payment;
  v_int   := round(v_fin * p_annual_rate / 100 * p_tenor / 12, 0);
  v_total := v_fin + v_int;

  insert into contracts(customer_id, product_id, contract_date, cash_price, down_payment,
                        principal_amount, annual_rate, tenor_months, total_interest,
                        total_receivable, installment_amount, late_fee_rate)
  values (p_customer_id, p_product_id, p_contract_date, v_cash, p_down_payment,
          v_fin, p_annual_rate, p_tenor, v_int, v_total, round(v_total / p_tenor, 0), p_late_fee_rate)
  returning contract_id into v_id;

  -- jadwal angsuran (angsuran terakhir menyerap selisih pembulatan)
  for i in 1..p_tenor loop
    if i < p_tenor then
      v_pp := round(v_fin / p_tenor, 0);
      v_ip := round(v_int / p_tenor, 0);
    else
      v_pp := v_fin - v_sum_p;
      v_ip := v_int - v_sum_i;
    end if;
    v_sum_p := v_sum_p + v_pp;
    v_sum_i := v_sum_i + v_ip;
    insert into installments(contract_id, installment_no, due_date, principal_amount, interest_amount)
    values (v_id, i, (p_contract_date + make_interval(months => i))::date, v_pp, v_ip);
  end loop;

  -- jurnal: penjualan kredit
  insert into journal_entries(journal_date, description, source_type, source_id)
  values (p_contract_date, 'Penjualan kredit kontrak ' || (select contract_no from contracts where contract_id = v_id),
          'contract', v_id)
  returning journal_id into v_jid;

  perform fn_post_line(v_jid, '1101', p_down_payment, 0);   -- Kas (DP)
  perform fn_post_line(v_jid, '1201', v_total, 0);          -- Piutang angsuran
  perform fn_post_line(v_jid, '4101', 0, v_cash);           -- Penjualan
  perform fn_post_line(v_jid, '1202', 0, v_int);            -- Bunga ditangguhkan
  perform fn_post_line(v_jid, '5101', v_cost, 0);           -- HPP
  perform fn_post_line(v_jid, '1301', 0, v_cost);           -- Persediaan

  return v_id;
end $$;

-- =====================================================================
-- process_payment : terima pembayaran, alokasi (denda -> bunga -> pokok)
--                   ke angsuran tertua, lalu buat jurnal.
-- Denda = sisa tagihan x late_fee_rate% x hari terlambat (sejak jatuh tempo /
-- sejak terakhir dihitung). Sisa denda yang tidak terbayar tidak diakumulasi
-- (penyederhanaan untuk pembelajaran).
-- =====================================================================
create or replace function process_payment(
  p_contract_id  uuid,
  p_payment_date date,
  p_amount       numeric,
  p_method       text default 'cash',
  p_notes        text default null
) returns uuid
language plpgsql as $$
declare
  v_c contracts%rowtype;
  v_pid uuid; v_jid uuid; r record;
  v_rem numeric := p_amount;
  v_out_p numeric; v_out_i numeric; v_days int;
  v_pen numeric; v_pay_pen numeric; v_pay_i numeric; v_pay_p numeric;
  v_tot_pen numeric := 0; v_tot_i numeric := 0; v_tot_p numeric := 0;
  v_new_p numeric; v_new_i numeric;
begin
  if p_amount is null or p_amount <= 0 then raise exception 'Jumlah pembayaran harus > 0'; end if;

  select * into v_c from contracts where contract_id = p_contract_id for update;
  if not found then raise exception 'Kontrak tidak ditemukan'; end if;
  if v_c.status <> 'active' then raise exception 'Kontrak tidak aktif (status: %)', v_c.status; end if;

  insert into payments(contract_id, payment_date, amount, method, notes)
  values (p_contract_id, p_payment_date, p_amount, p_method, p_notes)
  returning payment_id into v_pid;

  for r in
    select * from installments
    where contract_id = p_contract_id and status <> 'paid'
    order by installment_no
    for update
  loop
    exit when v_rem <= 0;

    v_out_p := r.principal_amount - r.principal_paid;
    v_out_i := r.interest_amount  - r.interest_paid;
    v_days  := greatest(0, p_payment_date - greatest(r.due_date, coalesce(r.penalty_calc_date, r.due_date)));
    v_pen   := round((v_out_p + v_out_i) * v_c.late_fee_rate / 100 * v_days, 0);

    v_pay_pen := least(v_pen, v_rem);   v_rem := v_rem - v_pay_pen;
    v_pay_i   := least(v_out_i, v_rem); v_rem := v_rem - v_pay_i;
    v_pay_p   := least(v_out_p, v_rem); v_rem := v_rem - v_pay_p;

    if v_pay_pen + v_pay_i + v_pay_p > 0 then
      insert into payment_allocations(payment_id, installment_id, penalty_paid, interest_paid, principal_paid)
      values (v_pid, r.installment_id, v_pay_pen, v_pay_i, v_pay_p);

      v_new_p := r.principal_paid + v_pay_p;
      v_new_i := r.interest_paid  + v_pay_i;
      update installments
         set principal_paid = v_new_p,
             interest_paid  = v_new_i,
             penalty_calc_date = case when p_payment_date > r.due_date then p_payment_date else penalty_calc_date end,
             status = case when v_new_p = principal_amount and v_new_i = interest_amount then 'paid'
                           else 'partial' end
       where installment_id = r.installment_id;

      v_tot_pen := v_tot_pen + v_pay_pen;
      v_tot_i   := v_tot_i + v_pay_i;
      v_tot_p   := v_tot_p + v_pay_p;
    end if;
  end loop;

  if v_rem > 0 then
    raise exception 'Pembayaran melebihi sisa tagihan (kelebihan Rp %)', v_rem;
  end if;

  update payments set penalty_amount = v_tot_pen where payment_id = v_pid;

  if not exists (select 1 from installments where contract_id = p_contract_id and status <> 'paid') then
    update contracts set status = 'paid_off' where contract_id = p_contract_id;
  end if;

  -- jurnal penerimaan angsuran
  insert into journal_entries(journal_date, description, source_type, source_id)
  values (p_payment_date,
          'Penerimaan angsuran ' || v_c.contract_no || ' (' || (select receipt_no from payments where payment_id = v_pid) || ')',
          'payment', v_pid)
  returning journal_id into v_jid;

  perform fn_post_line(v_jid, case when p_method = 'cash' then '1101' else '1102' end, p_amount, 0);
  perform fn_post_line(v_jid, '1201', 0, v_tot_i + v_tot_p);   -- piutang berkurang
  perform fn_post_line(v_jid, '1202', v_tot_i, 0);             -- bunga ditangguhkan berkurang
  perform fn_post_line(v_jid, '4201', 0, v_tot_i);             -- pendapatan bunga diakui
  perform fn_post_line(v_jid, '4202', 0, v_tot_pen);           -- pendapatan denda

  return v_pid;
end $$;
