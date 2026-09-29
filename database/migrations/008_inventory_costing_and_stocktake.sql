-- myERP migration 008: inventory costing + stocktake foundation
-- Local-safe migration: additive only.

ALTER TABLE products
  ADD COLUMN IF NOT EXISTS costing_method text NOT NULL DEFAULT 'weighted_average';

CREATE TABLE IF NOT EXISTS inventory_cost_layers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,
  warehouse_id uuid NOT NULL REFERENCES warehouses(id) ON DELETE CASCADE,
  source_type text NOT NULL CHECK (source_type IN ('opening','purchase','adjustment','transfer_in')),
  source_id uuid,
  quantity numeric(14,3) NOT NULL CHECK (quantity > 0),
  remaining_quantity numeric(14,3) NOT NULL CHECK (remaining_quantity >= 0),
  unit_cost numeric(14,4) NOT NULL CHECK (unit_cost >= 0),
  layer_date timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cost_layers_product_wh_date
  ON inventory_cost_layers(product_id, warehouse_id, layer_date, created_at);

CREATE TABLE IF NOT EXISTS inventory_cost_movements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  product_id uuid NOT NULL REFERENCES products(id),
  warehouse_id uuid NOT NULL REFERENCES warehouses(id),
  movement_type text NOT NULL CHECK (movement_type IN ('in','out','adjustment','transfer_in','transfer_out')),
  quantity numeric(14,3) NOT NULL CHECK (quantity > 0),
  unit_cost numeric(14,4) NOT NULL CHECK (unit_cost >= 0),
  total_cost numeric(16,4) NOT NULL CHECK (total_cost >= 0),
  reference text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_cost_movements_product_wh
  ON inventory_cost_movements(product_id, warehouse_id, created_at);

CREATE TABLE IF NOT EXISTS inventory_stocktakes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stocktake_no text UNIQUE NOT NULL,
  warehouse_id uuid NOT NULL REFERENCES warehouses(id),
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','counting','posted','cancelled')),
  count_date date NOT NULL DEFAULT current_date,
  notes text,
  created_by uuid REFERENCES users(id),
  posted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS inventory_stocktake_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  stocktake_id uuid NOT NULL REFERENCES inventory_stocktakes(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id),
  system_quantity numeric(14,3) NOT NULL DEFAULT 0,
  counted_quantity numeric(14,3) NOT NULL DEFAULT 0,
  variance_quantity numeric(14,3) NOT NULL DEFAULT 0,
  unit_cost numeric(14,4) NOT NULL DEFAULT 0,
  variance_value numeric(16,4) NOT NULL DEFAULT 0,
  notes text,
  UNIQUE(stocktake_id, product_id)
);
CREATE INDEX IF NOT EXISTS idx_stocktake_items_stocktake ON inventory_stocktake_items(stocktake_id);

CREATE OR REPLACE VIEW v_inventory_valuation AS
SELECT
  sb.product_id,
  sb.warehouse_id,
  sb.quantity,
  p.code,
  p.name,
  p.costing_method,
  COALESCE(SUM(cl.remaining_quantity * cl.unit_cost), 0)::numeric(16,4) AS layer_value,
  CASE WHEN sb.quantity > 0
       THEN COALESCE(SUM(cl.remaining_quantity * cl.unit_cost),0) / sb.quantity
       ELSE 0 END::numeric(14,4) AS calculated_unit_cost
FROM stock_balances sb
JOIN products p ON p.id = sb.product_id
LEFT JOIN inventory_cost_layers cl
  ON cl.product_id = sb.product_id
 AND cl.warehouse_id = sb.warehouse_id
 AND cl.remaining_quantity > 0
GROUP BY sb.product_id, sb.warehouse_id, sb.quantity, p.code, p.name, p.costing_method;
