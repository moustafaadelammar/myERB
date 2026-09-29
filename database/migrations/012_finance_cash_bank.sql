-- myERP migration 012: banks, accounts and payment allocation
CREATE TABLE IF NOT EXISTS bank_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_name text NOT NULL,
  account_name text NOT NULL,
  account_number text,
  iban text,
  currency text NOT NULL DEFAULT 'EGP',
  opening_balance numeric(14,2) NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS bank_transactions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bank_account_id uuid NOT NULL REFERENCES bank_accounts(id),
  transaction_type text NOT NULL CHECK(transaction_type IN ('deposit','withdrawal','transfer_in','transfer_out')),
  amount numeric(14,2) NOT NULL CHECK(amount>0),
  transaction_date date NOT NULL DEFAULT current_date,
  reference text,
  description text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS payment_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id uuid NOT NULL REFERENCES payments(id) ON DELETE CASCADE,
  invoice_id uuid REFERENCES invoices(id) ON DELETE SET NULL,
  amount numeric(14,2) NOT NULL CHECK(amount>0),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_bank_transactions_account_date ON bank_transactions(bank_account_id,transaction_date);
CREATE INDEX IF NOT EXISTS idx_payment_allocations_payment ON payment_allocations(payment_id);
CREATE INDEX IF NOT EXISTS idx_payment_allocations_invoice ON payment_allocations(invoice_id);

CREATE OR REPLACE VIEW v_customer_balances AS
SELECT c.id,c.name,c.phone,c.opening_balance,
       c.opening_balance
       + COALESCE((SELECT SUM(CASE WHEN i.invoice_type='sale' THEN i.total ELSE 0 END) FROM invoices i WHERE i.customer_id=c.id),0)
       - COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.customer_id=c.id AND p.payment_type='receipt'),0)
       - COALESCE((SELECT SUM(r.total) FROM returns r WHERE r.customer_id=c.id AND r.return_type='sale'),0)
       AS balance
FROM customers c;

CREATE OR REPLACE VIEW v_supplier_balances AS
SELECT s.id,s.name,s.phone,s.opening_balance,
       s.opening_balance
       + COALESCE((SELECT SUM(CASE WHEN i.invoice_type='purchase' THEN i.total ELSE 0 END) FROM invoices i WHERE i.supplier_id=s.id),0)
       - COALESCE((SELECT SUM(p.amount) FROM payments p WHERE p.supplier_id=s.id AND p.payment_type='payment'),0)
       - COALESCE((SELECT SUM(r.total) FROM returns r WHERE r.supplier_id=s.id AND r.return_type='purchase'),0)
       AS balance
FROM suppliers s;
