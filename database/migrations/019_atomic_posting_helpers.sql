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
  VALUES(p_type,p_id,p_user)
  ON CONFLICT(transaction_type,transaction_id) DO UPDATE SET status='posted',posted_at=now(),posted_by=excluded.posted_by
  RETURNING id INTO v_id;
  RETURN v_id;
END $$;

CREATE OR REPLACE VIEW v_posting_control AS
SELECT tp.transaction_type,tp.transaction_id,tp.status,tp.posted_at,tp.posted_by,
       COALESCE(SUM(jl.debit),0)::numeric(16,4) total_debit,
       COALESCE(SUM(jl.credit),0)::numeric(16,4) total_credit,
       (COALESCE(SUM(jl.debit),0)-COALESCE(SUM(jl.credit),0))::numeric(16,4) variance
FROM transaction_postings tp
LEFT JOIN journal_entries je ON je.reference_type=tp.transaction_type AND je.reference_id=tp.transaction_id
LEFT JOIN journal_lines jl ON jl.entry_id=je.id
GROUP BY tp.transaction_type,tp.transaction_id,tp.status,tp.posted_at,tp.posted_by;
