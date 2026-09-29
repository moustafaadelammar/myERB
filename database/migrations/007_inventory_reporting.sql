-- myERP migration 007: inventory reporting views

CREATE OR REPLACE VIEW v_inventory_balance AS
SELECT
  p.id AS product_id,
  p.code,
  p.name,
  p.unit,
  p.track_serial,
  w.id AS warehouse_id,
  w.name AS warehouse_name,
  COALESCE(sb.quantity,0) AS quantity,
  p.min_stock,
  CASE WHEN COALESCE(sb.quantity,0) <= p.min_stock THEN true ELSE false END AS low_stock
FROM products p
CROSS JOIN warehouses w
LEFT JOIN stock_balances sb ON sb.product_id=p.id AND sb.warehouse_id=w.id
WHERE p.is_active=true AND w.is_active=true;

CREATE OR REPLACE VIEW v_serial_traceability AS
SELECT
  sn.id,
  sn.serial_no,
  sn.product_id,
  p.code AS product_code,
  p.name AS product_name,
  sn.status,
  sn.warehouse_id,
  w.name AS warehouse_name,
  sn.customer_id,
  c.name AS customer_name,
  sn.supplier_id,
  s.name AS supplier_name,
  sn.invoice_id,
  i.invoice_no,
  i.invoice_type,
  sn.created_at
FROM serial_numbers sn
JOIN products p ON p.id=sn.product_id
LEFT JOIN warehouses w ON w.id=sn.warehouse_id
LEFT JOIN customers c ON c.id=sn.customer_id
LEFT JOIN suppliers s ON s.id=sn.supplier_id
LEFT JOIN invoices i ON i.id=sn.invoice_id;

CREATE OR REPLACE VIEW v_low_stock AS
SELECT * FROM v_inventory_balance WHERE low_stock=true;
