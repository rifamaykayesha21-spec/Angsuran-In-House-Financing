-- =====================================================================
-- 04_rls_policies.sql  |  Keamanan Supabase (Row Level Security)
-- MODE TANPA LOGIN (untuk belajar): role "anon" (kunci anon di frontend)
-- diberi akses. Siapa pun yang punya URL + anon key bisa baca/tulis data.
-- JANGAN dipakai untuk data nyata. Untuk produksi: ganti "anon" jadi "authenticated" dan tambahkan Supabase Auth.
-- =====================================================================

do $$
declare t text;
begin
  foreach t in array array['customers','products','accounts','contracts','installments',
                           'payments','payment_allocations','journal_entries','journal_lines']
  loop
    execute format('alter table %I enable row level security', t);
    execute format('drop policy if exists "open access" on %I', t);
    execute format('drop policy if exists "auth full access" on %I', t);
    execute format('drop policy if exists "read" on %I', t);
    execute format('drop policy if exists "insert" on %I', t);
  end loop;
end $$;

-- Master data: CRUD penuh
create policy "open access" on customers for all to anon, authenticated using (true) with check (true);
create policy "open access" on products  for all to anon, authenticated using (true) with check (true);
create policy "open access" on contracts for all to anon, authenticated using (true) with check (true);
create policy "open access" on installments for all to anon, authenticated using (true) with check (true);
create policy "read"        on accounts  for select to anon, authenticated using (true);

-- Pembayaran & jurnal = audit trail: hanya baca + tambah (tidak bisa ubah/hapus lewat API)
create policy "read"   on payments            for select to anon, authenticated using (true);
create policy "insert" on payments            for insert to anon, authenticated with check (true);
create policy "read"   on payment_allocations for select to anon, authenticated using (true);
create policy "insert" on payment_allocations for insert to anon, authenticated with check (true);
create policy "read"   on journal_entries     for select to anon, authenticated using (true);
create policy "insert" on journal_entries     for insert to anon, authenticated with check (true);
create policy "read"   on journal_lines       for select to anon, authenticated using (true);
create policy "insert" on journal_lines       for insert to anon, authenticated with check (true);

-- Hak eksekusi fungsi & akses view
grant execute on function create_contract(uuid,uuid,date,numeric,numeric,int,numeric) to anon, authenticated;
grant execute on function process_payment(uuid,date,numeric,text,text) to anon, authenticated;
grant select on v_contract_summary, v_aging_receivable, v_general_ledger,
                v_trial_balance, v_dashboard_kpi to anon, authenticated;

-- (Supabase sudah memberi hak ini secara default; ditulis eksplisit agar jelas)
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to anon, authenticated;
grant usage, select on all sequences in schema public to anon, authenticated;
