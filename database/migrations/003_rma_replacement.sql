-- myERP migration 003: RMA replacement traceability
ALTER TABLE rma_cases ADD COLUMN IF NOT EXISTS replacement_serial_id uuid REFERENCES serial_numbers(id);
CREATE TABLE IF NOT EXISTS rma_replacements(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),rma_id uuid NOT NULL REFERENCES rma_cases(id) ON DELETE CASCADE,old_serial_id uuid NOT NULL REFERENCES serial_numbers(id),new_serial_id uuid NOT NULL REFERENCES serial_numbers(id),warehouse_id uuid NOT NULL REFERENCES warehouses(id),created_by uuid REFERENCES users(id),created_at timestamptz NOT NULL DEFAULT now(),UNIQUE(rma_id),UNIQUE(new_serial_id),CHECK(old_serial_id <> new_serial_id));
CREATE INDEX IF NOT EXISTS idx_rma_replacements_old_serial ON rma_replacements(old_serial_id);
