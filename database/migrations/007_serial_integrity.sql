-- myERP migration 007: serial integrity and lookup indexes
CREATE UNIQUE INDEX IF NOT EXISTS uq_serial_numbers_serial_no ON serial_numbers(serial_no);
CREATE INDEX IF NOT EXISTS idx_serial_numbers_product_status ON serial_numbers(product_id,status);
CREATE INDEX IF NOT EXISTS idx_serial_numbers_warehouse_status ON serial_numbers(warehouse_id,status);
CREATE INDEX IF NOT EXISTS idx_invoice_item_serials_serial ON invoice_item_serials(serial_id);
