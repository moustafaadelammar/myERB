-- myERP migration 006: multi-warehouse transfers + stocktaking foundation
CREATE TABLE IF NOT EXISTS inventory_transfers(
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
CREATE TABLE IF NOT EXISTS inventory_transfer_items(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_id uuid NOT NULL REFERENCES inventory_transfers(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id),
  quantity numeric(14,3) NOT NULL CHECK(quantity > 0)
);
CREATE TABLE IF NOT EXISTS inventory_transfer_serials(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  transfer_item_id uuid NOT NULL REFERENCES inventory_transfer_items(id) ON DELETE CASCADE,
  serial_id uuid NOT NULL REFERENCES serial_numbers(id),
  UNIQUE(transfer_item_id,serial_id)
);
CREATE TABLE IF NOT EXISTS stocktakes(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stocktake_no text UNIQUE NOT NULL,
  warehouse_id uuid NOT NULL REFERENCES warehouses(id),
  status text NOT NULL DEFAULT 'draft' CHECK(status IN('draft','posted','cancelled')),
  stocktake_date date NOT NULL DEFAULT current_date,
  notes text,
  created_by uuid REFERENCES users(id),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS stocktake_items(
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stocktake_id uuid NOT NULL REFERENCES stocktakes(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id),
  system_quantity numeric(14,3) NOT NULL DEFAULT 0,
  counted_quantity numeric(14,3) NOT NULL DEFAULT 0,
  variance numeric(14,3) NOT NULL DEFAULT 0,
  notes text
);
CREATE INDEX IF NOT EXISTS idx_inventory_transfers_date ON inventory_transfers(transfer_date);
CREATE INDEX IF NOT EXISTS idx_inventory_transfer_items_transfer ON inventory_transfer_items(transfer_id);
CREATE INDEX IF NOT EXISTS idx_stocktakes_warehouse_date ON stocktakes(warehouse_id,stocktake_date);
CREATE INDEX IF NOT EXISTS idx_stocktake_items_stocktake ON stocktake_items(stocktake_id);
