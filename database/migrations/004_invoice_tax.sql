-- myERP migration 004: explicit invoice tax storage
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS tax_amount numeric(14,2) NOT NULL DEFAULT 0;
