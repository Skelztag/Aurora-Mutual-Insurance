/* =====================================================================
   Aurora Mutual Insurance — Data Quality Rule Execution
   Run against: Fabric SQL analytics endpoint (AuroraMutualLakehouse)

   Each query computes pass/fail counts and a pass rate for one rule
   from data-quality-rules.md. Run each block separately and record
   the output into data-quality-scorecard.md.
===================================================================== */


-- Rule 1: Completeness — email should not be null (bronze layer)
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN email IS NOT NULL THEN 1 ELSE 0 END) AS pass_count,
  SUM(CASE WHEN email IS NULL THEN 1 ELSE 0 END) AS fail_count,
  CAST(SUM(CASE WHEN email IS NOT NULL THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS pass_rate_pct
FROM bronze_dim_customer;


-- Rule 2: Completeness — phone_number should not be null (bronze layer)
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN phone_number IS NOT NULL THEN 1 ELSE 0 END) AS pass_count,
  SUM(CASE WHEN phone_number IS NULL THEN 1 ELSE 0 END) AS fail_count,
  CAST(SUM(CASE WHEN phone_number IS NOT NULL THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS pass_rate_pct
FROM bronze_dim_customer;


-- Rule 3: Validity — postcode should match UK postcode format (bronze layer)
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN postcode LIKE '[A-Z][0-9][0-9] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][0-9] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][A-Z][0-9][0-9] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][A-Z][0-9] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][0-9][A-Z] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][A-Z][0-9][A-Z] [0-9][A-Z][A-Z]'
        THEN 1 ELSE 0 END) AS pass_count,
  SUM(CASE WHEN NOT (postcode LIKE '[A-Z][0-9][0-9] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][0-9] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][A-Z][0-9][0-9] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][A-Z][0-9] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][0-9][A-Z] [0-9][A-Z][A-Z]'
             OR postcode LIKE '[A-Z][A-Z][0-9][A-Z] [0-9][A-Z][A-Z]')
        THEN 1 ELSE 0 END) AS fail_count
FROM bronze_dim_customer;


-- Rule 4a: Uniqueness — duplicate customers, BRONZE layer (expect failures)
SELECT
  COUNT(*) AS total_customer_rows,
  COUNT(*) - COUNT(DISTINCT CONCAT(date_of_birth, '|', postcode)) AS duplicate_row_count
FROM bronze_dim_customer;

-- Rule 4b: Uniqueness — duplicate customers, GOLD layer (expect zero, resolved in silver)
SELECT
  COUNT(*) AS total_customer_rows,
  COUNT(*) - COUNT(DISTINCT CONCAT(date_of_birth, '|', postcode)) AS duplicate_row_count
FROM dim_customer;


-- Rule 5: Referential integrity — every claim must reference a valid policy (bronze layer)
SELECT
  COUNT(*) AS total_claims,
  SUM(CASE WHEN dp.policy_id IS NULL THEN 1 ELSE 0 END) AS orphaned_claims,
  CAST(SUM(CASE WHEN dp.policy_id IS NOT NULL THEN 1 ELSE 0 END) AS FLOAT) / COUNT(*) * 100 AS pass_rate_pct
FROM bronze_fact_claims fc
LEFT JOIN bronze_dim_policy dp ON fc.policy_id = dp.policy_id;


-- Rule 6: Validity — settled_date must not precede incurred_date (bronze layer)
SELECT
  COUNT(*) AS total_settled_claims,
  SUM(CASE WHEN settled_date < incurred_date THEN 1 ELSE 0 END) AS illogical_date_count
FROM bronze_fact_claims
WHERE settled_date IS NOT NULL;


-- Rule 7a: Consistency — customer_segment standardization, BRONZE layer (expect failures)
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN customer_segment IN ('Standard', 'Mutual Rewards') THEN 1 ELSE 0 END) AS pass_count,
  SUM(CASE WHEN customer_segment NOT IN ('Standard', 'Mutual Rewards') THEN 1 ELSE 0 END) AS fail_count
FROM bronze_dim_customer;

-- Rule 7b: Consistency — customer_segment standardization, GOLD layer (expect 100% pass)
SELECT
  COUNT(*) AS total_rows,
  SUM(CASE WHEN customer_segment IN ('Standard', 'Mutual Rewards') THEN 1 ELSE 0 END) AS pass_count,
  SUM(CASE WHEN customer_segment NOT IN ('Standard', 'Mutual Rewards') THEN 1 ELSE 0 END) AS fail_count
FROM dim_customer;


-- Rule 8: Validity — claim_amount must be positive (bronze layer, baseline sanity check)
SELECT
  COUNT(*) AS total_claims,
  SUM(CASE WHEN claim_amount > 0 THEN 1 ELSE 0 END) AS pass_count,
  SUM(CASE WHEN claim_amount <= 0 THEN 1 ELSE 0 END) AS fail_count
FROM bronze_fact_claims;