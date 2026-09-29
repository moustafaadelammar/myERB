-- myERP migration 014: reporting indexes
CREATE INDEX IF NOT EXISTS idx_invoices_customer_type_date ON invoices(customer_id,invoice_type,invoice_date);
CREATE INDEX IF NOT EXISTS idx_invoices_supplier_type_date ON invoices(supplier_id,invoice_type,invoice_date);
CREATE INDEX IF NOT EXISTS idx_invoice_payments_invoice ON invoice_payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_returns_customer_date ON returns(customer_id,return_date);
CREATE INDEX IF NOT EXISTS idx_returns_supplier_date ON returns(supplier_id,return_date);
CREATE INDEX IF NOT EXISTS idx_expenses_date_category ON expenses(expense_date,category);
CREATE INDEX IF NOT EXISTS idx_incomes_date_category ON incomes(income_date,category);
CREATE INDEX IF NOT EXISTS idx_journal_lines_entry ON journal_entry_lines(journal_entry_id);
