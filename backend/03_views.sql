-- =====================================================================
-- 03_views.sql  |  View laporan (security_invoker => RLS tetap berlaku)
-- =====================================================================

-- Ringkasan per kontrak (kartu piutang)
create or replace view v_contract_summary with (security_invoker = true) as
select
  c.contract_id, c.contract_no, c.contract_date, c.customer_id,
  cu.full_name as customer_name, p.product_name,
  c.principal_amount, c.total_interest, c.total_receivable,
  c.tenor_months, c.installment_amount, c.status,
  coalesce(sum(i.principal_paid + i.interest_paid), 0)                      as total_paid,
  c.total_receivable - coalesce(sum(i.principal_paid + i.interest_paid), 0) as outstanding,
  coalesce(sum(case when i.due_date < current_date
                    then i.amount_due - i.principal_paid - i.interest_paid else 0 end), 0) as overdue_amount,
  coalesce(max(case when i.status <> 'paid' and i.due_date < current_date
                    then current_date - i.due_date end), 0)                 as days_overdue,
  min(case when i.status <> 'paid' then i.due_date end)                     as next_due_date
from contracts c
join customers cu on cu.customer_id = c.customer_id
join products  p  on p.product_id   = c.product_id
left join installments i on i.contract_id = c.contract_id
group by c.contract_id, cu.customer_id, p.product_id;

-- Umur piutang (aging) per kontrak
create or replace view v_aging_receivable with (security_invoker = true) as
select
  c.contract_id, c.contract_no, cu.full_name as customer_name,
  sum(x.outst) filter (where x.days <= 0)               as current_amt,
  sum(x.outst) filter (where x.days between 1 and 30)   as d1_30,
  sum(x.outst) filter (where x.days between 31 and 60)  as d31_60,
  sum(x.outst) filter (where x.days between 61 and 90)  as d61_90,
  sum(x.outst) filter (where x.days > 90)               as d90_plus,
  sum(x.outst)                                          as total_outstanding
from (
  select contract_id,
         amount_due - principal_paid - interest_paid as outst,
         current_date - due_date                     as days
  from installments where status <> 'paid'
) x
join contracts c  on c.contract_id  = x.contract_id
join customers cu on cu.customer_id = c.customer_id
where c.status = 'active'
group by c.contract_id, c.contract_no, cu.full_name;

-- Buku besar (detail jurnal)
create or replace view v_general_ledger with (security_invoker = true) as
select je.journal_date, je.journal_no, je.description, je.source_type,
       jl.account_code, a.account_name, jl.debit, jl.credit
from journal_lines jl
join journal_entries je on je.journal_id = jl.journal_id
join accounts a on a.account_code = jl.account_code;

-- Neraca saldo
create or replace view v_trial_balance with (security_invoker = true) as
select a.account_code, a.account_name, a.account_type, a.normal_balance,
       coalesce(sum(jl.debit), 0)  as total_debit,
       coalesce(sum(jl.credit), 0) as total_credit,
       case when a.normal_balance = 'D'
            then coalesce(sum(jl.debit),0) - coalesce(sum(jl.credit),0)
            else coalesce(sum(jl.credit),0) - coalesce(sum(jl.debit),0) end as balance
from accounts a
left join journal_lines jl on jl.account_code = a.account_code
group by a.account_code
order by a.account_code;

-- KPI dashboard (1 baris)
create or replace view v_dashboard_kpi with (security_invoker = true) as
select
  (select count(*) from customers)                                         as total_customers,
  (select count(*) from contracts where status = 'active')                 as active_contracts,
  (select coalesce(sum(outstanding),0) from v_contract_summary where status = 'active') as total_outstanding,
  (select coalesce(sum(overdue_amount),0) from v_contract_summary where status = 'active') as total_overdue,
  (select count(*) from v_contract_summary where status = 'active' and days_overdue > 0) as overdue_contracts,
  (select coalesce(sum(amount),0) from payments
     where date_trunc('month', payment_date) = date_trunc('month', current_date)) as collected_this_month,
  (select coalesce(sum(credit - debit),0) from journal_lines where account_code = '4201') as interest_income;
