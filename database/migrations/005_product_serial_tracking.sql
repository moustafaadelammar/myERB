-- myERP migration 005: serial tracking for products
ALTER TABLE products ADD COLUMN IF NOT EXISTS track_serial boolean NOT NULL DEFAULT false;

-- Purchase-created serials are stored in serial_numbers and linked to the purchase invoice item.
-- Stock quantity is increased by the purchase invoice posting exactly once.
