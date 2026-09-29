-- myERP migration 010: database-level integrity hardening

CREATE UNIQUE INDEX IF NOT EXISTS ux_serial_numbers_serial_no
  ON serial_numbers(serial_no);

CREATE INDEX IF NOT EXISTS idx_serial_numbers_product_status
  ON serial_numbers(product_id,status);
CREATE INDEX IF NOT EXISTS idx_serial_numbers_warehouse
  ON serial_numbers(warehouse_id);

ALTER TABLE stock_balances
  ADD CONSTRAINT stock_balances_nonnegative CHECK (quantity >= 0);

ALTER TABLE inventory_cost_layers
  ADD CONSTRAINT inventory_cost_layers_remaining_lte_quantity CHECK (remaining_quantity <= quantity);
