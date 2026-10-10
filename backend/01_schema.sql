-- =====================================================================
-- 01_schema.sql  |  Tabel, constraint, index
-- Jalankan di Supabase: SQL Editor -> New query -> paste -> Run
-- Urutan file: 01 -> 02 -> 03 -> 04 -> 05
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------- SEQUENCE untuk nomor otomatis ----------
create sequence if not exists seq_customer start 1;
create sequence if not exists seq_product  start 1;
create sequence if not exists seq_contract start 1;
create sequence if not exists seq_receipt  start 1;
create sequence if not exists seq_journal  start 1;

-- ---------- MASTER ----------
create table if not exists customers (
  customer_id    uuid primary key default gen_random_uuid(),
  customer_code  text not null unique
                 default 'CUST-' || lpad(nextval('seq_customer')::text, 5, '0'),
  full_name      text not null,
  nik            char(16) not null unique check (nik ~ '^[0-9]{16}$'),
  phone          text,
  address        text,
  occupation     text,
  monthly_income numeric(15,2) not null default 0 check (monthly_income >= 0),
  created_at     timestamptz not null default now()
);

create table if not exists products (
  product_id   uuid primary key default gen_random_uuid(),
  product_code text not null unique
               default 'PRD-' || lpad(nextval('seq_product')::text, 4, '0'),
  product_name text not null,
  cost_price   numeric(15,2) not null default 0 check (cost_price >= 0),
  cash_price   numeric(15,2) not null check (cash_price > 0),
  is_active    boolean not null default true
);

-- ---------- BAGAN AKUN ----------
create table if not exists accounts (
  account_code   text primary key,
  account_name   text not null,
  account_type   text not null check (account_type in ('asset','liability','equity','revenue','expense')),
  normal_balance char(1) not null check (normal_balance in ('D','C'))
);

-- ---------- PIUTANG (KONTRAK) ----------
create table if not exists contracts (
  contract_id        uuid primary key default gen_random_uuid(),
  contract_no        text not null unique
                     default 'IHF-' || to_char(now(), 'YYYY') || '-' || lpad(nextval('seq_contract')::text, 5, '0'),
  customer_id        uuid not null references customers(customer_id) on delete restrict,
  product_id         uuid not null references products(product_id)   on delete restrict,
  contract_date      date not null default current_date,
  cash_price         numeric(15,2) not null check (cash_price > 0),
  down_payment       numeric(15,2) not null default 0 check (down_payment >= 0),
  principal_amount   numeric(15,2) not null check (principal_amount > 0),  -- cash_price - down_payment
  annual_rate        numeric(6,2)  not null check (annual_rate >= 0),      -- % per tahun (bunga flat)
  tenor_months       int           not null check (tenor_months between 1 and 120),
  total_interest     numeric(15,2) not null check (total_interest >= 0),
  total_receivable   numeric(15,2) not null check (total_receivable > 0),  -- pokok + bunga
  installment_amount numeric(15,2) not null,
  late_fee_rate      numeric(6,3)  not null default 0.1 check (late_fee_rate >= 0), -- % per hari
  status             text not null default 'active' check (status in ('active','paid_off','written_off')),
  created_at         timestamptz not null default now(),
  constraint ck_dp_lt_price check (down_payment < cash_price)
);
create index if not exists ix_contracts_customer on contracts(customer_id);
create index if not exists ix_contracts_status   on contracts(status);

-- ---------- JADWAL ANGSURAN (sub-ledger piutang) ----------
create table if not exists installments (
  installment_id   uuid primary key default gen_random_uuid(),
  contract_id      uuid not null references contracts(contract_id) on delete cascade,
  installment_no   int  not null check (installment_no > 0),
  due_date         date not null,
  principal_amount numeric(15,2) not null check (principal_amount >= 0),
  interest_amount  numeric(15,2) not null check (interest_amount >= 0),
  amount_due       numeric(15,2) generated always as (principal_amount + interest_amount) stored,
  principal_paid   numeric(15,2) not null default 0 check (principal_paid >= 0),
  interest_paid    numeric(15,2) not null default 0 check (interest_paid >= 0),
  penalty_calc_date date,                     -- denda sudah dihitung sampai tanggal ini
  status           text not null default 'unpaid' check (status in ('unpaid','partial','paid')),
  unique (contract_id, installment_no),
  constraint ck_paid_le_due check (principal_paid <= principal_amount and interest_paid <= interest_amount)
);
create index if not exists ix_inst_contract on installments(contract_id);
create index if not exists ix_inst_due      on installments(due_date) where status <> 'paid';

-- ---------- PEMBAYARAN ----------
create table if not exists payments (
  payment_id     uuid primary key default gen_random_uuid(),
  receipt_no     text not null unique default 'RCP-' || lpad(nextval('seq_receipt')::text, 6, '0'),
  contract_id    uuid not null references contracts(contract_id) on delete restrict,
  payment_date   date not null default current_date,
  amount         numeric(15,2) not null check (amount > 0),
  penalty_amount numeric(15,2) not null default 0 check (penalty_amount >= 0),
  method         text not null default 'cash' check (method in ('cash','transfer','qris')),
  notes          text,
  created_by     uuid default auth.uid(),
  created_at     timestamptz not null default now()
);
create index if not exists ix_pay_contract on payments(contract_id);

create table if not exists payment_allocations (
  allocation_id  uuid primary key default gen_random_uuid(),
  payment_id     uuid not null references payments(payment_id) on delete cascade,
  installment_id uuid not null references installments(installment_id) on delete restrict,
  penalty_paid   numeric(15,2) not null default 0 check (penalty_paid  >= 0),
  interest_paid  numeric(15,2) not null default 0 check (interest_paid >= 0),
  principal_paid numeric(15,2) not null default 0 check (principal_paid >= 0)
);
create index if not exists ix_alloc_payment on payment_allocations(payment_id);
create index if not exists ix_alloc_inst    on payment_allocations(installment_id);

-- ---------- JURNAL (buku besar) ----------
create table if not exists journal_entries (
  journal_id   uuid primary key default gen_random_uuid(),
  journal_no   text not null unique default 'JV-' || lpad(nextval('seq_journal')::text, 6, '0'),
  journal_date date not null default current_date,
  description  text not null,
  source_type  text not null default 'manual' check (source_type in ('contract','payment','manual')),
  source_id    uuid,
  created_at   timestamptz not null default now()
);

create table if not exists journal_lines (
  line_id      uuid primary key default gen_random_uuid(),
  journal_id   uuid not null references journal_entries(journal_id) on delete cascade,
  account_code text not null references accounts(account_code),
  debit        numeric(15,2) not null default 0 check (debit  >= 0),
  credit       numeric(15,2) not null default 0 check (credit >= 0),
  constraint ck_one_side check ((debit = 0) <> (credit = 0))   -- salah satu saja yang terisi
);
create index if not exists ix_jl_journal on journal_lines(journal_id);
create index if not exists ix_jl_account on journal_lines(account_code);
