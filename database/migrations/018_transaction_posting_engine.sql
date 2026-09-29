-- myERP migration 018: transaction posting engine foundation
CREATE TABLE IF NOT EXISTS transaction_postings (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), transaction_type text NOT NULL, transaction_id uuid NOT NULL,
 status text NOT NULL DEFAULT 'posted' CHECK(status IN ('posted','reversed')), posted_at timestamptz NOT NULL DEFAULT now(), posted_by uuid REFERENCES users(id),
 UNIQUE(transaction_type,transaction_id)
);
CREATE INDEX IF NOT EXISTS idx_transaction_postings_type_date ON transaction_postings(transaction_type,posted_at);
CREATE TABLE IF NOT EXISTS posting_queue (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), transaction_type text NOT NULL, transaction_id uuid NOT NULL,
 action text NOT NULL CHECK(action IN ('post','reverse')), status text NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','processing','done','failed')),
 error_message text, created_at timestamptz NOT NULL DEFAULT now(), processed_at timestamptz,
 UNIQUE(transaction_type,transaction_id,action)
);
CREATE INDEX IF NOT EXISTS idx_posting_queue_pending ON posting_queue(status,created_at);
CREATE TABLE IF NOT EXISTS accounting_reconciliations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(), reconciliation_date date NOT NULL, source_type text NOT NULL, source_id uuid,
 expected_amount numeric(16,4) NOT NULL DEFAULT 0, posted_amount numeric(16,4) NOT NULL DEFAULT 0, variance numeric(16,4) NOT NULL DEFAULT 0,
 status text NOT NULL DEFAULT 'matched' CHECK(status IN ('matched','variance','reviewed')), notes text, created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_reconciliation_date ON accounting_reconciliations(reconciliation_date,source_type);
