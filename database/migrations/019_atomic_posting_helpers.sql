-- myERP migration 019: atomic posting helpers
CREATE OR REPLACE FUNCTION assert_transaction_postable(p_type text,p_id uuid)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM transaction_postings WHERE transaction_type=p_type AND transaction_id=p_id AND status='posted') THEN
    RAISE EXCEPTION 'Transaction already posted: %/%',p_type,p_id USING ERRCODE='23505';
  END IF;
END $$;

CREATE OR REPLACE FUNCTION register_transaction_posting(p_type text,p_id uuid,p_user uuid)
RETURNS uuid LANGUAGE plpgsql AS $$
DECLARE v_id uuid;
BEGIN
  INSERT INTO transaction_postings(transaction_type,transaction_id,posted_by)
  VALUES(p_type,p_id,p_user) RETURNING id INTO v_id;
  INSERT INTO journal_entry_sources(journal_entry_id,source_type,source_id)
  SELECT je.id,p_type,p_id FROM journal_entries je
  WHERE je.source_type=p_type AND je.source_id=p_id
  ON CONFLICT(source_type,source_id) DO NOTHING;
  RETURN v_id;
END $$;

CREATE OR REPLACE VIEW v_posting_control AS
SELECT tp.transaction_type,tp.transaction_id,tp.status,tp.posted_at,tp.posted_by,
       COALESCE(SUM(jl.debit),0)::numeric(16,4) total_debit,
       COALESCE(SUM(jl.credit),0)::numeric(16,4) total_credit,
       (COALESCE(SUM(jl.debit),0)-COALESCE(SUM(jl.credit),0))::numeric(16,4) variance
FROM transaction_postings tp
LEFT JOIN journal_entry_sources js ON js.source_type=tp.transaction_type AND js.source_id=tp.transaction_id
LEFT JOIN journal_entry_lines jl ON jl.journal_entry_id=js.journal_entry_id
GROUP BY tp.transaction_type,tp.transaction_id,tp.status,tp.posted_at,tp.posted_by;
