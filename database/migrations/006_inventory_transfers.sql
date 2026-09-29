-- myERP migration 006: multi-warehouse inventory transfers + serial traceability

CREATE TABLE IF NOT EXISTS stock_transfers(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_no text UNIQUE NOT NULL,
  from_warehouse_id uuid NOT NULL REFERENCES warehouses(id),
  to_warehouse_id uuid NOT NULL REFERENCES warehouses(id),
  status text NOT NULL DEFAULT 'posted' CHECK(status IN('draft','posted','cancelled')),
  transfer_date date NOT NULL DEFAULT current_date,
  notes text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now(),
  CHECK(from_warehouse_id <> to_warehouse_id)
);

CREATE TABLE IF NOT EXISTS stock_transfer_items(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id uuid NOT NULL REFERENCES stock_transfers(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id),
  quantity numeric(14,3) NOT NULL CHECK(quantity > 0),
  UNIQUE(transfer_id, product_id)
);

CREATE TABLE IF NOT EXISTS stock_transfer_serials(
  transfer_item_id uuid NOT NULL REFERENCES stock_transfer_items(id) ON DELETE CASCADE,
  serial_id uuid NOT NULL REFERENCES serial_numbers(id),
  PRIMARY KEY(transfer_item_id, serial_id),
  UNIQUE(serial_id)
);

CREATE INDEX IF NOT EXISTS idx_stock_transfers_date ON stock_transfers(transfer_date);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_from ON stock_transfers(from_warehouse_id, transfer_date);
CREATE INDEX IF NOT EXISTS idx_stock_transfers_to ON stock_transfers(to_warehouse_id, transfer_date);
CREATE INDEX IF NOT EXISTS idx_transfer_items_product ON stock_transfer_items(product_id);
CREATE INDEX IF NOT EXISTS idx_serial_numbers_product_status ON serial_numbers(product_id, status);
CREATE INDEX IF NOT EXISTS idx_serial_numbers_warehouse ON serial_numbers(warehouse_id);

-- Prevent duplicate serial registration at database level.
CREATE UNIQUE INDEX IF NOT EXISTS ux_serial_numbers_serial_no ON serial_numbers(serial_no);

-- Compatibility for existing local databases.
ALTER TABLE serial_numbers ADD COLUMN IF NOT EXISTS warehouse_id uuid REFERENCES warehouses(id);
ALTER TABLE serial_numbers ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'in_stock';
