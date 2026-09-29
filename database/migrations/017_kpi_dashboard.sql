-- myERP migration 017: executive KPI reporting
CREATE OR REPLACE VIEW v_dashboard_kpis AS
SELECT
  (SELECT COALESCE(SUM(total),0) FROM invoices WHERE invoice_type='sale')::numeric(16,2) AS total_sales,
  (SELECT COALESCE(SUM(total),0) FROM invoices WHERE invoice_type='purchase')::numeric(16,2) AS total_purchases,
  (SELECT COALESCE(SUM(amount),0) FROM payments WHERE payment_type='receipt')::numeric(16,2) AS customer_receipts,
  (SELECT COALESCE(SUM(amount),0) FROM payments WHERE payment_type='payment')::numeric(16,2) AS supplier_payments,
  (SELECT COUNT(*) FROM customers WHERE is_active=true)::int AS active_customers,
  (SELECT COUNT(*) FROM suppliers WHERE is_active=true)::int AS active_suppliers,
  (SELECT COUNT(*) FROM products WHERE is_active=true)::int AS active_products,
  (SELECT COUNT(*) FROM products p JOIN stock_balances sb ON sb.product_id=p.id WHERE p.is_active=true AND sb.quantity<=p.min_stock)::int AS low_stock_items;

CREATE OR REPLACE VIEW v_monthly_sales AS
SELECT date_trunc('month',invoice_date)::date month,
       COUNT(*)::int invoice_count,
       COALESCE(SUM(total),0)::numeric(16,2) total_sales
FROM invoices
WHERE invoice_type='sale'
GROUP BY 1 ORDER BY 1;
