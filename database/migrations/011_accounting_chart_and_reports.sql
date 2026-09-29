-- myERP migration 011: accounting chart + reporting foundation
CREATE TABLE IF NOT EXISTS chart_of_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text UNIQUE NOT NULL,
  name text NOT NULL,
  account_type text NOT NULL CHECK(account_type IN ('asset','liability','equity','revenue','expense')),
  parent_id uuid REFERENCES chart_of_accounts(id),
  is_control_account boolean NOT NULL DEFAULT false,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_coa_parent ON chart_of_accounts(parent_id);
CREATE INDEX IF NOT EXISTS idx_coa_type ON chart_of_accounts(account_type);

INSERT INTO chart_of_accounts(code,name,account_type,is_control_account) VALUES
('1000','الأصول','asset',true),
('1100','النقدية والخزائن','asset',true),
('1200','العملاء','asset',true),
('1300','المخزون','asset',true),
('1400','ضريبة القيمة المضافة - مدخلات','asset',true),
('2000','الالتزامات','liability',true),
('2100','الموردون','liability',true),
('2200','ضريبة القيمة المضافة - مخرجات','liability',true),
('3000','حقوق الملكية','equity',true),
('3100','رأس المال','equity',false),
('4000','الإيرادات','revenue',true),
('4100','المبيعات','revenue',false),
('5000','المصروفات','expense',true),
('5100','تكلفة المبيعات','expense',false),
('5200','المصروفات التشغيلية','expense',false)
ON CONFLICT(code) DO NOTHING;

CREATE OR REPLACE VIEW v_account_balances AS
SELECT c.code,c.name,c.account_type,
       COALESCE(SUM(jl.debit),0)::numeric(16,4) debit,
       COALESCE(SUM(jl.credit),0)::numeric(16,4) credit,
       CASE WHEN c.account_type IN ('asset','expense')
            THEN COALESCE(SUM(jl.debit-jl.credit),0)
            ELSE COALESCE(SUM(jl.credit-jl.debit),0) END::numeric(16,4) balance
FROM chart_of_accounts c
LEFT JOIN journal_entry_lines jl ON jl.account_code=c.code
LEFT JOIN journal_entries je ON je.id=jl.journal_entry_id AND je.status='posted'
GROUP BY c.code,c.name,c.account_type;

CREATE OR REPLACE VIEW v_trial_balance AS
SELECT code,name,account_type,debit,credit,balance
FROM v_account_balances
WHERE debit <> 0 OR credit <> 0 OR balance <> 0;

CREATE OR REPLACE VIEW v_income_statement AS
SELECT account_type,
       SUM(CASE WHEN account_type='revenue' THEN balance ELSE 0 END)::numeric(16,4) revenue,
       SUM(CASE WHEN account_type='expense' THEN balance ELSE 0 END)::numeric(16,4) expenses,
       (SUM(CASE WHEN account_type='revenue' THEN balance ELSE 0 END)-SUM(CASE WHEN account_type='expense' THEN balance ELSE 0 END))::numeric(16,4) net_income
FROM v_account_balances
WHERE account_type IN ('revenue','expense')
GROUP BY account_type;
