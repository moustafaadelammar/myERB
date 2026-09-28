create extension if not exists pgcrypto;
create table if not exists users(id uuid primary key default gen_random_uuid(),email text unique not null,password_hash text not null,full_name text not null,role text not null default 'admin',is_active boolean not null default true,created_at timestamptz not null default now());
create table if not exists customers(id uuid primary key default gen_random_uuid(),name text not null,phone text,opening_balance numeric(14,2) not null default 0,customer_type text not null default 'company',is_active boolean not null default true,created_at timestamptz not null default now());
create table if not exists suppliers(id uuid primary key default gen_random_uuid(),name text not null,phone text,opening_balance numeric(14,2) not null default 0,is_active boolean not null default true,created_at timestamptz not null default now());
create table if not exists product_categories(id uuid primary key default gen_random_uuid(),name text unique not null);
create table if not exists products(id uuid primary key default gen_random_uuid(),code text unique not null,name text not null,category_id uuid references product_categories(id),unit text not null default 'قطعة',cost numeric(14,2) not null default 0,price numeric(14,2) not null default 0,min_stock numeric(14,3) not null default 0,track_serial boolean not null default false,is_active boolean not null default true,created_at timestamptz not null default now());
create table if not exists warehouses(id uuid primary key default gen_random_uuid(),name text unique not null,location text,is_active boolean not null default true);
create table if not exists stock_balances(product_id uuid references products(id) on delete cascade,warehouse_id uuid references warehouses(id) on delete cascade,quantity numeric(14,3) not null default 0,primary key(product_id,warehouse_id));
create table if not exists invoices(id uuid primary key default gen_random_uuid(),invoice_no text unique not null,invoice_type text not null check(invoice_type in('sale','purchase')),customer_id uuid references customers(id),supplier_id uuid references suppliers(id),status text not null default 'draft',invoice_date date not null default current_date,total numeric(14,2) not null default 0,tax_amount numeric(14,2) not null default 0,created_at timestamptz not null default now());
create index if not exists idx_products_code on products(code);create index if not exists idx_invoices_date on invoices(invoice_date);create index if not exists idx_customers_name on customers(name);
insert into users(email,password_hash,full_name,role) values('admin@myerb.local',crypt('Admin@123',gen_salt('bf')), 'مدير النظام','admin') on conflict(email) do nothing;
insert into product_categories(name) values('كاميرات'),('شبكات'),('Storage'),('مسجلات') on conflict(name) do nothing;
insert into warehouses(name,location) values('المخزن الرئيسي','بني سويف') on conflict(name) do nothing;
CREATE TABLE IF NOT EXISTS roles(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text UNIQUE NOT NULL,description text);
CREATE TABLE IF NOT EXISTS permissions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),code text UNIQUE NOT NULL,name text NOT NULL);
CREATE TABLE IF NOT EXISTS role_permissions(role_id uuid REFERENCES roles(id) ON DELETE CASCADE,permission_id uuid REFERENCES permissions(id) ON DELETE CASCADE,PRIMARY KEY(role_id,permission_id));
CREATE TABLE IF NOT EXISTS audit_logs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid REFERENCES users(id),action text NOT NULL,entity text,entity_id uuid,details jsonb,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS cashboxes(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text UNIQUE NOT NULL,currency text NOT NULL DEFAULT 'EGP',opening_balance numeric(14,2) NOT NULL DEFAULT 0,is_active boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS cashbox_transactions(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),cashbox_id uuid REFERENCES cashboxes(id),transaction_type text NOT NULL CHECK(transaction_type IN('receipt','payment','transfer')),amount numeric(14,2) NOT NULL CHECK(amount>=0),reference text,description text,transaction_date date NOT NULL DEFAULT current_date,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS product_stock_movements(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),product_id uuid REFERENCES products(id),warehouse_id uuid REFERENCES warehouses(id),movement_type text NOT NULL CHECK(movement_type IN('in','out','adjustment','transfer')),quantity numeric(14,3) NOT NULL CHECK(quantity<>0),reference text,notes text,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_audit_logs_created ON audit_logs(created_at);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON product_stock_movements(product_id,created_at);
INSERT INTO roles(name,description) VALUES('admin','صلاحيات كاملة'),('manager','إدارة وتشغيل'),('sales','المبيعات'),('purchasing','المشتريات'),('warehouse','المخازن'),('finance','المالية') ON CONFLICT(name) DO NOTHING;
INSERT INTO permissions(code,name) VALUES
('dashboard.view','عرض لوحة التحكم'),('customers.manage','إدارة العملاء'),('suppliers.manage','إدارة الموردين'),('products.manage','إدارة الأصناف'),('inventory.manage','إدارة المخزون'),('sales.manage','إدارة المبيعات'),('purchases.manage','إدارة المشتريات'),('finance.manage','إدارة المالية'),('reports.view','عرض التقارير'),('users.manage','إدارة المستخدمين'),('audit.view','عرض سجل العمليات') ON CONFLICT(code) DO NOTHING;
INSERT INTO cashboxes(name,opening_balance) VALUES('الخزينة الرئيسية',0) ON CONFLICT(name) DO NOTHING;
-- Default RBAC mapping. Permissions are data-driven and can be extended without code changes.
INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r CROSS JOIN permissions p
WHERE r.name='admin'
ON CONFLICT DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r JOIN permissions p ON p.code IN('dashboard.view','customers.manage','suppliers.manage','products.manage','inventory.manage','sales.manage','purchases.manage','finance.manage','reports.view','audit.view')
WHERE r.name='manager'
ON CONFLICT DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r JOIN permissions p ON p.code IN('dashboard.view','customers.manage','sales.manage','reports.view')
WHERE r.name='sales'
ON CONFLICT DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r JOIN permissions p ON p.code IN('dashboard.view','suppliers.manage','products.manage','purchases.manage','reports.view')
WHERE r.name='purchasing'
ON CONFLICT DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r JOIN permissions p ON p.code IN('dashboard.view','products.manage','inventory.manage','reports.view')
WHERE r.name='warehouse'
ON CONFLICT DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id)
SELECT r.id,p.id FROM roles r JOIN permissions p ON p.code IN('dashboard.view','finance.manage','reports.view')
WHERE r.name='finance'
ON CONFLICT DO NOTHING;

CREATE TABLE IF NOT EXISTS sales_orders(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_no text UNIQUE NOT NULL,customer_id uuid NOT NULL REFERENCES customers(id),status text NOT NULL DEFAULT 'draft',order_date date NOT NULL DEFAULT current_date,subtotal numeric(14,2) NOT NULL DEFAULT 0,tax numeric(14,2) NOT NULL DEFAULT 0,total numeric(14,2) NOT NULL DEFAULT 0,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS sales_order_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES sales_orders(id) ON DELETE CASCADE,product_id uuid NOT NULL REFERENCES products(id),quantity numeric(14,3) NOT NULL CHECK(quantity>0),unit_price numeric(14,2) NOT NULL CHECK(unit_price>=0),discount numeric(14,2) NOT NULL DEFAULT 0,line_total numeric(14,2) NOT NULL);
CREATE TABLE IF NOT EXISTS purchase_orders(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_no text UNIQUE NOT NULL,supplier_id uuid NOT NULL REFERENCES suppliers(id),status text NOT NULL DEFAULT 'draft',order_date date NOT NULL DEFAULT current_date,subtotal numeric(14,2) NOT NULL DEFAULT 0,tax numeric(14,2) NOT NULL DEFAULT 0,total numeric(14,2) NOT NULL DEFAULT 0,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS purchase_order_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),order_id uuid NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,product_id uuid NOT NULL REFERENCES products(id),quantity numeric(14,3) NOT NULL CHECK(quantity>0),unit_cost numeric(14,2) NOT NULL CHECK(unit_cost>=0),discount numeric(14,2) NOT NULL DEFAULT 0,line_total numeric(14,2) NOT NULL);
CREATE TABLE IF NOT EXISTS payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),payment_no text UNIQUE NOT NULL,payment_type text NOT NULL CHECK(payment_type IN('receipt','payment')),customer_id uuid REFERENCES customers(id),supplier_id uuid REFERENCES suppliers(id),cashbox_id uuid NOT NULL REFERENCES cashboxes(id),amount numeric(14,2) NOT NULL CHECK(amount>0),reference text,notes text,payment_date date NOT NULL DEFAULT current_date,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_sales_orders_customer ON sales_orders(customer_id,order_date);
CREATE INDEX IF NOT EXISTS idx_purchase_orders_supplier ON purchase_orders(supplier_id,order_date);
CREATE INDEX IF NOT EXISTS idx_payments_date ON payments(payment_date);

CREATE TABLE IF NOT EXISTS invoice_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,product_id uuid NOT NULL REFERENCES products(id),warehouse_id uuid NOT NULL REFERENCES warehouses(id),quantity numeric(14,3) NOT NULL CHECK(quantity>0),unit_price numeric(14,2) NOT NULL CHECK(unit_price>=0),unit_cost numeric(14,2) NOT NULL DEFAULT 0,discount numeric(14,2) NOT NULL DEFAULT 0,line_total numeric(14,2) NOT NULL);
CREATE TABLE IF NOT EXISTS invoice_payments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),invoice_id uuid NOT NULL REFERENCES invoices(id) ON DELETE CASCADE,payment_id uuid NOT NULL REFERENCES payments(id) ON DELETE CASCADE,amount numeric(14,2) NOT NULL CHECK(amount>0),created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_invoice_items_invoice ON invoice_items(invoice_id);
CREATE INDEX IF NOT EXISTS idx_invoice_items_product ON invoice_items(product_id);

CREATE TABLE IF NOT EXISTS leads(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text NOT NULL,phone text,email text,source text,status text NOT NULL DEFAULT 'new',notes text,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS opportunities(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),lead_id uuid REFERENCES leads(id) ON DELETE SET NULL,customer_id uuid REFERENCES customers(id) ON DELETE SET NULL,title text NOT NULL,value numeric(14,2) NOT NULL DEFAULT 0,stage text NOT NULL DEFAULT 'new',expected_date date,notes text,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS followups(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),customer_id uuid REFERENCES customers(id) ON DELETE SET NULL,lead_id uuid REFERENCES leads(id) ON DELETE SET NULL,opportunity_id uuid REFERENCES opportunities(id) ON DELETE SET NULL,followup_type text NOT NULL DEFAULT 'call',due_at timestamptz NOT NULL,notes text,status text NOT NULL DEFAULT 'open',created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS projects(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),project_no text UNIQUE NOT NULL,name text NOT NULL,customer_id uuid REFERENCES customers(id),project_type text,contract_value numeric(14,2) NOT NULL DEFAULT 0,status text NOT NULL DEFAULT 'planning',start_date date,end_date date,notes text,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS project_tasks(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,title text NOT NULL,assigned_to uuid REFERENCES users(id),status text NOT NULL DEFAULT 'todo',due_date date,estimated_cost numeric(14,2) NOT NULL DEFAULT 0,actual_cost numeric(14,2) NOT NULL DEFAULT 0,notes text);
CREATE TABLE IF NOT EXISTS customer_assets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),customer_id uuid NOT NULL REFERENCES customers(id) ON DELETE CASCADE,asset_type text NOT NULL,name text NOT NULL,brand text,model text,serial_no text,installation_date date,warranty_end date,location text,status text NOT NULL DEFAULT 'active',notes text);
CREATE TABLE IF NOT EXISTS maintenance_contracts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),contract_no text UNIQUE NOT NULL,customer_id uuid NOT NULL REFERENCES customers(id),start_date date NOT NULL,end_date date NOT NULL,value numeric(14,2) NOT NULL DEFAULT 0,visits_per_year integer NOT NULL DEFAULT 0,status text NOT NULL DEFAULT 'active',notes text,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS service_tickets(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),ticket_no text UNIQUE NOT NULL,customer_id uuid REFERENCES customers(id),asset_id uuid REFERENCES customer_assets(id) ON DELETE SET NULL,title text NOT NULL,description text,priority text NOT NULL DEFAULT 'medium',status text NOT NULL DEFAULT 'open',assigned_to uuid REFERENCES users(id),opened_at timestamptz NOT NULL DEFAULT now(),closed_at timestamptz);
CREATE INDEX IF NOT EXISTS idx_leads_status ON leads(status);
CREATE INDEX IF NOT EXISTS idx_opportunities_stage ON opportunities(stage);
CREATE INDEX IF NOT EXISTS idx_projects_customer ON projects(customer_id);
CREATE INDEX IF NOT EXISTS idx_tickets_status ON service_tickets(status);

-- Permission defaults and compatibility for existing local databases.
insert into role_permissions(role_id,permission_id)
select r.id,p.id from roles r cross join permissions p
where r.name='admin'
on conflict do nothing;
insert into role_permissions(role_id,permission_id)
select r.id,p.id from roles r cross join permissions p
where r.name='manager' and p.code in ('dashboard.view','customers.manage','suppliers.manage','products.manage','inventory.manage','sales.manage','purchases.manage','finance.manage','reports.view')
on conflict do nothing;
insert into role_permissions(role_id,permission_id)
select r.id,p.id from roles r cross join permissions p
where r.name='sales' and p.code in ('dashboard.view','customers.manage','sales.manage','reports.view')
on conflict do nothing;
insert into role_permissions(role_id,permission_id)
select r.id,p.id from roles r cross join permissions p
where r.name='purchasing' and p.code in ('dashboard.view','suppliers.manage','products.manage','purchases.manage','reports.view')
on conflict do nothing;
insert into role_permissions(role_id,permission_id)
select r.id,p.id from roles r cross join permissions p
where r.name='warehouse' and p.code in ('dashboard.view','products.manage','inventory.manage','reports.view')
on conflict do nothing;
insert into role_permissions(role_id,permission_id)
select r.id,p.id from roles r cross join permissions p
where r.name='finance' and p.code in ('dashboard.view','finance.manage','reports.view')
on conflict do nothing;

CREATE TABLE IF NOT EXISTS branches(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text UNIQUE NOT NULL,address text,phone text,is_active boolean NOT NULL DEFAULT true,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS departments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text UNIQUE NOT NULL,branch_id uuid REFERENCES branches(id),is_active boolean NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS employees(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),employee_no text UNIQUE NOT NULL,full_name text NOT NULL,phone text,email text,department_id uuid REFERENCES departments(id),job_title text,hire_date date,status text NOT NULL DEFAULT 'active',created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS expenses(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),expense_no text UNIQUE NOT NULL,expense_date date NOT NULL DEFAULT current_date,category text NOT NULL,description text,amount numeric(14,2) NOT NULL CHECK(amount>0),cashbox_id uuid REFERENCES cashboxes(id),created_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS incomes(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),income_no text UNIQUE NOT NULL,income_date date NOT NULL DEFAULT current_date,category text NOT NULL,description text,amount numeric(14,2) NOT NULL CHECK(amount>0),cashbox_id uuid REFERENCES cashboxes(id),created_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS returns(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),return_no text UNIQUE NOT NULL,return_type text NOT NULL CHECK(return_type IN('sale','purchase')),invoice_id uuid REFERENCES invoices(id),customer_id uuid REFERENCES customers(id),supplier_id uuid REFERENCES suppliers(id),warehouse_id uuid REFERENCES warehouses(id),return_date date NOT NULL DEFAULT current_date,total numeric(14,2) NOT NULL DEFAULT 0,reason text,status text NOT NULL DEFAULT 'posted',created_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS rma_cases(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),rma_no text UNIQUE NOT NULL,return_id uuid REFERENCES returns(id) ON DELETE SET NULL,serial_id uuid,customer_id uuid REFERENCES customers(id),status text NOT NULL DEFAULT 'received' CHECK(status IN('received','inspected','approved','rejected','repaired','replaced','refunded','closed')),resolution text CHECK(resolution IN('repair','replacement','refund','none')),inspection_notes text,created_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now(),updated_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_rma_cases_serial ON rma_cases(serial_id);
CREATE INDEX IF NOT EXISTS idx_rma_cases_customer ON rma_cases(customer_id);

CREATE TABLE IF NOT EXISTS return_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),return_id uuid NOT NULL REFERENCES returns(id) ON DELETE CASCADE,product_id uuid NOT NULL REFERENCES products(id),quantity numeric(14,3) NOT NULL CHECK(quantity>0),unit_price numeric(14,2) NOT NULL DEFAULT 0,line_total numeric(14,2) NOT NULL DEFAULT 0);
CREATE INDEX IF NOT EXISTS idx_employees_department ON employees(department_id);
CREATE INDEX IF NOT EXISTS idx_expenses_date ON expenses(expense_date);
CREATE INDEX IF NOT EXISTS idx_incomes_date ON incomes(income_date);
CREATE INDEX IF NOT EXISTS idx_returns_date ON returns(return_date);

CREATE TABLE IF NOT EXISTS serial_numbers(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),product_id uuid NOT NULL REFERENCES products(id) ON DELETE CASCADE,serial_no text UNIQUE NOT NULL,status text NOT NULL DEFAULT 'in_stock',warehouse_id uuid REFERENCES warehouses(id),customer_id uuid REFERENCES customers(id),invoice_id uuid REFERENCES invoices(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS invoice_item_serials(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),invoice_item_id uuid NOT NULL REFERENCES invoice_items(id) ON DELETE CASCADE,serial_id uuid NOT NULL REFERENCES serial_numbers(id),UNIQUE(invoice_item_id,serial_id),UNIQUE(serial_id));
CREATE TABLE IF NOT EXISTS inventory_adjustments(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),adjustment_no text UNIQUE NOT NULL,warehouse_id uuid NOT NULL REFERENCES warehouses(id),reason text,created_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS inventory_adjustment_items(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),adjustment_id uuid NOT NULL REFERENCES inventory_adjustments(id) ON DELETE CASCADE,product_id uuid NOT NULL REFERENCES products(id),quantity_delta numeric(14,3) NOT NULL);
CREATE TABLE IF NOT EXISTS technicians(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),employee_id uuid REFERENCES employees(id),specialty text,status text NOT NULL DEFAULT 'active');
CREATE TABLE IF NOT EXISTS site_visits(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),visit_no text UNIQUE NOT NULL,customer_id uuid REFERENCES customers(id),project_id uuid REFERENCES projects(id),technician_id uuid REFERENCES technicians(id),scheduled_at timestamptz,completed_at timestamptz,status text NOT NULL DEFAULT 'scheduled',notes text);
CREATE TABLE IF NOT EXISTS project_costs(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),project_id uuid NOT NULL REFERENCES projects(id) ON DELETE CASCADE,cost_type text NOT NULL,description text,amount numeric(14,2) NOT NULL CHECK(amount>=0),cost_date date NOT NULL DEFAULT current_date,created_by uuid REFERENCES users(id));
CREATE TABLE IF NOT EXISTS notifications(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),user_id uuid REFERENCES users(id) ON DELETE CASCADE,title text NOT NULL,message text,read_at timestamptz,created_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS idx_serial_product ON serial_numbers(product_id);
CREATE INDEX IF NOT EXISTS idx_site_visits_customer ON site_visits(customer_id);
CREATE INDEX IF NOT EXISTS idx_project_costs_project ON project_costs(project_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id,read_at);

-- myERB migration 002: accounting
CREATE TABLE IF NOT EXISTS accounts(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),code text UNIQUE NOT NULL,name text NOT NULL,account_type text NOT NULL CHECK(account_type IN('asset','liability','equity','revenue','expense')),parent_id uuid REFERENCES accounts(id),is_active boolean NOT NULL DEFAULT true,created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS fiscal_periods(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),name text NOT NULL,start_date date NOT NULL,end_date date NOT NULL,is_closed boolean NOT NULL DEFAULT false,UNIQUE(start_date,end_date));
CREATE TABLE IF NOT EXISTS journal_entries(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),entry_no text UNIQUE NOT NULL,entry_date date NOT NULL DEFAULT current_date,description text,reference_type text,reference_id uuid,posted_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS journal_lines(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),entry_id uuid NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,account_id uuid NOT NULL REFERENCES accounts(id),description text,debit numeric(14,2) NOT NULL DEFAULT 0 CHECK(debit>=0),credit numeric(14,2) NOT NULL DEFAULT 0 CHECK(credit>=0),cost_center text,CONSTRAINT journal_line_side CHECK((debit=0 AND credit>0) OR (credit=0 AND debit>0)));
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(entry_date);
CREATE INDEX IF NOT EXISTS idx_journal_lines_account ON journal_lines(account_id);
INSERT INTO accounts(code,name,account_type) VALUES ('1100','النقدية والخزائن','asset'),('1200','العملاء','asset'),('1300','المخزون','asset'),('1400','ضريبة القيمة المضافة - مدخلات','asset'),('2100','الموردون','liability'),('2200','ضريبة القيمة المضافة - مخرجات','liability'),('3100','رأس المال','equity'),('4100','المبيعات','revenue'),('4200','إيرادات أخرى','revenue'),('5100','تكلفة المبيعات','expense'),('5200','المصروفات التشغيلية','expense') ON CONFLICT(code) DO NOTHING;
-- RMA replacement traceability (included in local bootstrap so a fresh database is complete)
ALTER TABLE rma_cases ADD COLUMN IF NOT EXISTS replacement_serial_id uuid REFERENCES serial_numbers(id);
DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='rma_cases_serial_id_fkey') THEN ALTER TABLE rma_cases ADD CONSTRAINT rma_cases_serial_id_fkey FOREIGN KEY(serial_id) REFERENCES serial_numbers(id); END IF; END $$;
CREATE TABLE IF NOT EXISTS rma_replacements(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),rma_id uuid NOT NULL REFERENCES rma_cases(id) ON DELETE CASCADE,old_serial_id uuid NOT NULL REFERENCES serial_numbers(id),new_serial_id uuid NOT NULL REFERENCES serial_numbers(id),warehouse_id uuid NOT NULL REFERENCES warehouses(id),created_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(rma_id),UNIQUE(new_serial_id),CHECK(old_serial_id <> new_serial_id));
CREATE INDEX IF NOT EXISTS idx_rma_replacements_old_serial ON rma_replacements(old_serial_id);
INSERT INTO permissions(code,name) VALUES('rma.manage','إدارة RMA وخدمة ما بعد البيع') ON CONFLICT(code) DO NOTHING;
INSERT INTO role_permissions(role_id,permission_id) SELECT r.id,p.id FROM roles r CROSS JOIN permissions p WHERE r.name IN('admin','manager','sales') AND p.code='rma.manage' ON CONFLICT DO NOTHING;

-- invoice tax compatibility
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS tax_amount numeric(14,2) NOT NULL DEFAULT 0;