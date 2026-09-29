-- myERP migration 009: finance periods and posting controls
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS posted_at timestamptz;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS posted_by uuid REFERENCES users(id);
ALTER TABLE returns ADD COLUMN IF NOT EXISTS posted_at timestamptz;
ALTER TABLE returns ADD COLUMN IF NOT EXISTS posted_by uuid REFERENCES users(id);

CREATE TABLE IF NOT EXISTS fiscal_periods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  period_name text UNIQUE NOT NULL,
  start_date date NOT NULL,
  end_date date NOT NULL,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open','closed')),
  closed_at timestamptz,
  closed_by uuid REFERENCES users(id),
  CHECK (end_date >= start_date)
);
CREATE INDEX IF NOT EXISTS idx_fiscal_periods_dates ON fiscal_periods(start_date,end_date);

CREATE TABLE IF NOT EXISTS journal_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  entry_no text UNIQUE NOT NULL,
  entry_date date NOT NULL DEFAULT current_date,
  description text,
  source_type text,
  source_id uuid,
  status text NOT NULL DEFAULT 'posted' CHECK (status IN ('draft','posted','reversed')),
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS journal_entry_lines (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  journal_entry_id uuid NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
  account_code text NOT NULL,
  debit numeric(16,4) NOT NULL DEFAULT 0,
  credit numeric(16,4) NOT NULL DEFAULT 0,
  description text,
  CHECK (debit >= 0 AND credit >= 0 AND NOT (debit > 0 AND credit > 0))
);
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_entry_lines(account_code);
