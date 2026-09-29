-- myERP migration 015: accounting automation rules
CREATE TABLE IF NOT EXISTS accounting_rules (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_code text UNIQUE NOT NULL,
  debit_account_code text NOT NULL REFERENCES chart_of_accounts(code),
  credit_account_code text NOT NULL REFERENCES chart_of_accounts(code),
  description text,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);

INSERT INTO accounting_rules(event_code,debit_account_code,credit_account_code,description) VALUES
('sale','1200','4100','بيع آجل / ذمم العملاء والمبيعات'),
('purchase','1300','2100','شراء آجل / المخزون والموردون'),
('customer_receipt','1100','1200','تحصيل من عميل'),
('supplier_payment','2100','1100','سداد مورد'),
('expense_cash','5200','1100','مصروف نقدي'),
('income_cash','1100','4000','إيراد نقدي')
ON CONFLICT(event_code) DO NOTHING;

CREATE TABLE IF NOT EXISTS journal_entry_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_entry_id uuid NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
  source_type text NOT NULL,
  source_id uuid NOT NULL,
  UNIQUE(source_type,source_id)
);
CREATE INDEX IF NOT EXISTS idx_journal_sources_source ON journal_entry_sources(source_type,source_id);

CREATE OR REPLACE VIEW v_general_ledger AS
SELECT je.entry_no,je.entry_date,je.description,je.source_type,
       jl.account_code,c.name account_name,jl.debit,jl.credit,
       SUM(jl.debit-jl.credit) OVER(PARTITION BY jl.account_code ORDER BY je.entry_date,je.entry_no,je.id,jl.id) running_balance
FROM journal_entries je
JOIN journal_entry_lines jl ON jl.journal_entry_id=je.id
JOIN chart_of_accounts c ON c.code=jl.account_code
WHERE je.status='posted';
