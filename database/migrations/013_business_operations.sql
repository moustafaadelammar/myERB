-- myERP migration 013: commercial operations and service management
CREATE TABLE IF NOT EXISTS quotations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_no text UNIQUE NOT NULL,
  customer_id uuid REFERENCES customers(id),
  quotation_date date NOT NULL DEFAULT current_date,
  valid_until date,
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','sent','accepted','rejected','expired')),
  subtotal numeric(14,2) NOT NULL DEFAULT 0,
  tax numeric(14,2) NOT NULL DEFAULT 0,
  total numeric(14,2) NOT NULL DEFAULT 0,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS quotation_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  quotation_id uuid NOT NULL REFERENCES quotations(id) ON DELETE CASCADE,
  product_id uuid REFERENCES products(id),
  description text NOT NULL,
  quantity numeric(14,3) NOT NULL CHECK(quantity>0),
  unit_price numeric(14,2) NOT NULL CHECK(unit_price>=0),
  discount numeric(14,2) NOT NULL DEFAULT 0,
  line_total numeric(14,2) NOT NULL
);
CREATE TABLE IF NOT EXISTS delivery_notes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_no text UNIQUE NOT NULL,
  customer_id uuid REFERENCES customers(id),
  warehouse_id uuid REFERENCES warehouses(id),
  invoice_id uuid REFERENCES invoices(id),
  delivery_date date NOT NULL DEFAULT current_date,
  status text NOT NULL DEFAULT 'draft' CHECK(status IN ('draft','posted','cancelled')),
  notes text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS delivery_note_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_note_id uuid NOT NULL REFERENCES delivery_notes(id) ON DELETE CASCADE,
  product_id uuid NOT NULL REFERENCES products(id),
  quantity numeric(14,3) NOT NULL CHECK(quantity>0)
);
CREATE TABLE IF NOT EXISTS service_visits (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  ticket_id uuid REFERENCES service_tickets(id) ON DELETE SET NULL,
  customer_id uuid REFERENCES customers(id),
  technician_id uuid REFERENCES users(id),
  scheduled_at timestamptz NOT NULL,
  started_at timestamptz,
  ended_at timestamptz,
  status text NOT NULL DEFAULT 'scheduled' CHECK(status IN ('scheduled','in_progress','completed','cancelled')),
  work_summary text,
  parts_cost numeric(14,2) NOT NULL DEFAULT 0,
  labor_cost numeric(14,2) NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_quotations_customer_date ON quotations(customer_id,quotation_date);
CREATE INDEX IF NOT EXISTS idx_delivery_notes_customer_date ON delivery_notes(customer_id,delivery_date);
CREATE INDEX IF NOT EXISTS idx_service_visits_schedule ON service_visits(scheduled_at,status);
