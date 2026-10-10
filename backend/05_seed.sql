-- =====================================================================
-- 05_seed.sql  |  Data awal
-- BAGIAN A (wajib): bagan akun. BAGIAN B (opsional): data contoh.
-- =====================================================================

-- ---------- A. Bagan akun (WAJIB, dipakai fungsi jurnal) ----------
insert into accounts(account_code, account_name, account_type, normal_balance) values
  ('1101','Kas',                              'asset',   'D'),
  ('1102','Bank',                             'asset',   'D'),
  ('1201','Piutang Angsuran',                 'asset',   'D'),
  ('1202','Pendapatan Bunga Ditangguhkan',    'asset',   'C'),  -- akun kontra piutang
  ('1301','Persediaan Barang Dagang',         'asset',   'D'),
  ('3101','Modal',                            'equity',  'C'),
  ('4101','Penjualan',                        'revenue', 'C'),
  ('4201','Pendapatan Bunga Pembiayaan',      'revenue', 'C'),
  ('4202','Pendapatan Denda Keterlambatan',   'revenue', 'C'),
  ('5101','Harga Pokok Penjualan',            'expense', 'D')
on conflict (account_code) do nothing;

-- ---------- B. Data contoh (OPSIONAL, hapus bagian ini jika tidak perlu) ----------
insert into customers(full_name, nik, phone, address, occupation, monthly_income) values
  ('Budi Santoso', '3201010101900001', '081234567890', 'Jl. Merdeka No. 10, Bandung', 'Karyawan Swasta', 6500000),
  ('Siti Aminah',  '3201010202920002', '081298765432', 'Jl. Melati No. 5, Bogor',     'Guru',            5200000)
on conflict (nik) do nothing;

insert into products(product_name, cost_price, cash_price) values
  ('Sepeda Motor Matic 125cc', 16500000, 20000000),
  ('Lemari Es 2 Pintu',         3800000,  5000000);

-- Saldo awal: modal disetor berupa persediaan Rp 100 juta
with j as (insert into journal_entries(journal_date, description, source_type)
            values (current_date - interval '6 months', 'Saldo awal persediaan', 'manual') returning journal_id)
insert into journal_lines(journal_id, account_code, debit, credit)
select journal_id, '1301', 100000000, 0 from j
union all
select journal_id, '3101', 0, 100000000 from j;

-- Kontrak contoh: dibuat 4 bulan lalu agar tampak ada angsuran jatuh tempo
do $$
declare
  c1 uuid; c2 uuid; p1 uuid; p2 uuid; k1 uuid;
begin
  select customer_id into c1 from customers where nik = '3201010101900001';
  select customer_id into c2 from customers where nik = '3201010202920002';
  select product_id  into p1 from products  where product_name like 'Sepeda Motor%';
  select product_id  into p2 from products  where product_name like 'Lemari Es%';

  k1 := create_contract(c1, p1, (current_date - interval '4 months')::date, 4000000, 12, 12, 0.1);
  perform create_contract(c2, p2, (current_date - interval '1 month')::date, 1000000, 10, 6, 0.1);

  -- Budi membayar 2 angsuran pertama tepat waktu
  perform process_payment(k1, (current_date - interval '3 months')::date, 1493333, 'cash',     'Angsuran ke-1');
  perform process_payment(k1, (current_date - interval '2 months')::date, 1493333, 'transfer', 'Angsuran ke-2');
end $$;
