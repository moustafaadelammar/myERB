-- myERP migration 020: CRM / projects / service workflow hardening
-- Idempotent by design. Safe to apply after the existing business-operation bootstrap.

CREATE INDEX IF NOT EXISTS idx_crm_leads_status_created
  ON crm_leads(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_crm_leads_customer
  ON crm_leads(customer_id);

CREATE INDEX IF NOT EXISTS idx_opportunities_stage_close
  ON opportunities(stage, expected_date);

CREATE INDEX IF NOT EXISTS idx_followups_due_status
  ON followups(status, due_at);

CREATE INDEX IF NOT EXISTS idx_followups_customer
  ON followups(customer_id);

CREATE INDEX IF NOT EXISTS idx_projects_status_created
  ON projects(status, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_project_tasks_project_status_due
  ON project_tasks(project_id, status, due_date);

CREATE INDEX IF NOT EXISTS idx_project_tasks_assignee_status
  ON project_tasks(assigned_to, status);

CREATE INDEX IF NOT EXISTS idx_service_tickets_status_priority
  ON service_tickets(status, priority, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_service_tickets_customer
  ON service_tickets(customer_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_read_created
  ON notifications(user_id, read_at, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_audit_logs_entity_created
  ON audit_logs(entity, entity_id, created_at DESC);

-- Prevent accidental duplicate open follow-ups for the same opportunity/time slot
-- without blocking historical/completed records.
CREATE UNIQUE INDEX IF NOT EXISTS uq_followups_open_opportunity_due
  ON followups(opportunity_id, due_at)
  WHERE opportunity_id IS NOT NULL AND status = 'open';

-- Fast operational queues.
CREATE INDEX IF NOT EXISTS idx_service_visits_technician_schedule
  ON service_visits(technician_id, scheduled_at, status);

CREATE INDEX IF NOT EXISTS idx_project_costs_project_date
  ON project_costs(project_id, cost_date DESC);
