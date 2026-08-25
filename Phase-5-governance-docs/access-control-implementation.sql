/* =====================================================================
   Aurora Mutual Insurance — Role-Based Access Control & Dynamic Data Masking
   Implements the Access Policy defined in data-governance-policy.md,
   scoped by the classification levels in gdpr-classification-policy.md.
   Run against: AuroraMutualDB (Azure SQL Database)
===================================================================== */


/* =====================================================================
   STAGE 1 — Create database roles matching the Phase 0 org chart
===================================================================== */

CREATE ROLE db_underwriting;
CREATE ROLE db_claims;
CREATE ROLE db_actuarial;
CREATE ROLE db_finance;
CREATE ROLE db_compliance_dpo;
GO


/* =====================================================================
   STAGE 2a — Create the 3 logins.
   IMPORTANT: run this part while connected to the 'master' database
   specifically, not AuroraMutualDB — Azure SQL Database only allows
   CREATE LOGIN at the server level, which means the master database.
===================================================================== */

CREATE LOGIN login_underwriting WITH PASSWORD = 'Kp7$mVq2Wz9x!';
GO

CREATE LOGIN login_claims WITH PASSWORD = 'Rf4$tLb8Nq3y!';
GO

CREATE LOGIN login_compliance_dpo WITH PASSWORD = 'Hx2$jDw6Sm5p!';
GO


/* =====================================================================
   STAGE 2b — Create users for those logins, and add them to roles.
   IMPORTANT: switch your connection back to AuroraMutualDB before
   running this part — it will fail if still connected to master.
===================================================================== */

CREATE USER test_underwriting FOR LOGIN login_underwriting;
CREATE USER test_claims FOR LOGIN login_claims;
CREATE USER test_compliance_dpo FOR LOGIN login_compliance_dpo;
GO

ALTER ROLE db_underwriting ADD MEMBER test_underwriting;
ALTER ROLE db_claims ADD MEMBER test_claims;
ALTER ROLE db_compliance_dpo ADD MEMBER test_compliance_dpo;
GO


/* =====================================================================
   STAGE 3 — Table-level SELECT grants (least privilege)

   Note: db_claims deliberately does NOT get SELECT on dim_customer at
   all. Claims only needs customer_id (already present on fact_claims)
   to link a claim to a policy — it never needs the customer's PII
   directly. This is table-level RBAC, a stronger control than masking
   alone: even if masking were misconfigured, Claims still couldn't
   read the table.
===================================================================== */

GRANT SELECT ON dim_customer TO db_underwriting, db_compliance_dpo;
GRANT SELECT ON dim_policy   TO db_underwriting, db_claims, db_actuarial, db_finance, db_compliance_dpo;
GRANT SELECT ON dim_product  TO db_underwriting, db_actuarial, db_finance, db_compliance_dpo;
GRANT SELECT ON dim_branch   TO db_underwriting, db_compliance_dpo;
GRANT SELECT ON dim_date     TO db_underwriting, db_claims, db_actuarial, db_finance, db_compliance_dpo;
GRANT SELECT ON fact_claims  TO db_claims, db_actuarial, db_compliance_dpo;
GO


/* =====================================================================
   STAGE 4 — Dynamic Data Masking on dim_customer PII columns

   High sensitivity (per classification policy) -> full mask
   Medium sensitivity -> partial mask (some structure visible)
===================================================================== */

ALTER TABLE dim_customer ALTER COLUMN date_of_birth ADD MASKED WITH (FUNCTION = 'default()');
ALTER TABLE dim_customer ALTER COLUMN address_line1 ADD MASKED WITH (FUNCTION = 'default()');
ALTER TABLE dim_customer ALTER COLUMN postcode       ADD MASKED WITH (FUNCTION = 'default()');

ALTER TABLE dim_customer ALTER COLUMN email        ADD MASKED WITH (FUNCTION = 'email()');
ALTER TABLE dim_customer ALTER COLUMN phone_number ADD MASKED WITH (FUNCTION = 'partial(0,"XXX-XXX-",4)');
ALTER TABLE dim_customer ALTER COLUMN first_name   ADD MASKED WITH (FUNCTION = 'partial(1,"XXXXX",0)');
ALTER TABLE dim_customer ALTER COLUMN last_name    ADD MASKED WITH (FUNCTION = 'partial(1,"XXXXX",0)');
GO


/* =====================================================================
   STAGE 5 — Grant UNMASK per the access policy table

   Compliance & DPO: unmask everything (High + Medium).
   Underwriting: unmask Medium only — High-sensitivity fields
   (date_of_birth, address_line1, postcode) stay masked even for them,
   since only the DPO role has a legitimate need to see raw identity
   data at that level.
===================================================================== */

GRANT UNMASK ON dim_customer TO db_compliance_dpo;

GRANT UNMASK ON dim_customer(email)        TO db_underwriting;
GRANT UNMASK ON dim_customer(phone_number) TO db_underwriting;
GRANT UNMASK ON dim_customer(first_name)   TO db_underwriting;
GRANT UNMASK ON dim_customer(last_name)    TO db_underwriting;
-- Deliberately no UNMASK grant to db_underwriting on date_of_birth,
-- address_line1, or postcode — those stay masked even for Underwriting.
GO


/* =====================================================================
   STAGE 6 — Demonstration: what does each role actually see?

   Rather than EXECUTE AS (which hit an Azure SQL platform limitation
   during testing), validate by genuinely reconnecting to the database
   using each login's real credentials — three separate connections in
   VS Code, one per role, each running the same simple query below.
===================================================================== */

-- Run this exact query from THREE separate VS Code connections:
--   1. login_compliance_dpo / Hx2$jDw6Sm5p!  -> expect fully unmasked
--   2. login_underwriting / Kp7$mVq2Wz9x!    -> expect name/email/phone
--      visible, DOB/address/postcode masked
--   3. login_claims / Rf4$tLb8Nq3y!          -> expect a permission
--      error (no SELECT on dim_customer at all)

SELECT TOP 3 customer_id, first_name, last_name, date_of_birth, email, phone_number, postcode
FROM dim_customer;
