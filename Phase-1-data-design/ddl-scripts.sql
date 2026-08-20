/* =====================================================================
   Aurora Mutual Insurance — DDL Scripts
   Target: Azure SQL Database

   RUN ORDER MATTERS. This script is split into stages:
     STAGE 1 — Create tables                          (run now)
     STAGE 2 — Add table/column descriptions           (run now)
     STAGE 3 — Add FK constraints (all except one)     (run now)
     STAGE 4 — Add indexes                             (run now)
     -------------------------------------------------------------
     >>> STOP. Run data-generator.py to load synthetic data <<<
     -------------------------------------------------------------
     STAGE 5 — Add the deferred FK constraint WITH NOCHECK (run AFTER data load)

   Why fact_claims.policy_id is deferred: the synthetic dataset
   deliberately includes ~1% orphaned claims (policy_id values with
   no matching dim_policy row) for the Phase 3 data quality exercise.
   A normal FK constraint would reject those rows at insert time, so
   the constraint is added afterwards, WITH NOCHECK — enforced for
   all future inserts, but not retroactively validated against rows
   that already exist. This is a standard real-world pattern for
   flagging "known, tolerated" integrity issues rather than blocking
   the load. DBCC CHECKCONSTRAINTS can later report exactly which
   rows violate it (see the note at the bottom of Stage 5).
===================================================================== */


/* =====================================================================
   STAGE 1 — Table creation
===================================================================== */

CREATE TABLE [dim_customer] (
  [customer_id]             INT           NOT NULL PRIMARY KEY,
  [first_name]               NVARCHAR(100) NOT NULL,
  [last_name]                 NVARCHAR(100) NOT NULL,
  [date_of_birth]              DATE          NOT NULL,
  [address_line1]               NVARCHAR(200) NOT NULL,
  [address_line2]                NVARCHAR(200) NULL,
  [city]                           NVARCHAR(100) NOT NULL,
  [postcode]                        NVARCHAR(10)  NOT NULL,
  [email]                             NVARCHAR(255) NULL,     -- ~5% missing by design
  [phone_number]                       NVARCHAR(20)  NULL,     -- ~5% missing by design
  [customer_segment]                    NVARCHAR(50)  NOT NULL, -- casing inconsistent by design
  [join_date]                             DATE          NOT NULL,
  [marketing_consent_flag]                  BIT           NOT NULL DEFAULT 0
)
GO

CREATE TABLE [dim_product] (
  [product_id]       INT          NOT NULL PRIMARY KEY,
  [product_name]      NVARCHAR(50) NOT NULL,  -- Motor / Home / Travel
  [product_category]   NVARCHAR(50) NOT NULL
)
GO

CREATE TABLE [dim_branch] (
  [branch_id]     INT           NOT NULL PRIMARY KEY,
  [branch_name]    NVARCHAR(100) NOT NULL,
  [region]          NVARCHAR(50)  NOT NULL,
  [channel]          NVARCHAR(20)  NOT NULL  -- Direct / Broker
)
GO

CREATE TABLE [dim_date] (
  [date_key]     INT          NOT NULL PRIMARY KEY,  -- format YYYYMMDD
  [full_date]     DATE         NOT NULL,
  [day]            TINYINT      NOT NULL,
  [month]           TINYINT      NOT NULL,
  [month_name]       NVARCHAR(20) NOT NULL,
  [quarter]           TINYINT      NOT NULL,
  [year]               SMALLINT     NOT NULL,
  [is_weekend]          BIT          NOT NULL
)
GO

CREATE TABLE [dim_policy] (
  [policy_id]           INT           NOT NULL PRIMARY KEY,
  [customer_id]          INT           NOT NULL,
  [product_id]            INT           NOT NULL,
  [branch_id]              INT           NOT NULL,
  [policy_start_date]       DATE          NOT NULL,
  [policy_end_date]          DATE          NOT NULL,
  [status]                    NVARCHAR(20)  NOT NULL,  -- Active / Lapsed / Cancelled
  [annual_premium]              DECIMAL(10,2) NOT NULL,
  [sum_insured]                  DECIMAL(12,2) NOT NULL
)
GO

CREATE TABLE [fact_claims] (
  [claim_id]         INT           NOT NULL PRIMARY KEY,
  [policy_id]          INT           NOT NULL,  -- ~1% orphaned by design; FK deferred to Stage 5
  [customer_id]          INT           NOT NULL,  -- denormalised from dim_policy for query convenience
  [claim_date_key]         INT           NOT NULL,
  [claim_type]               NVARCHAR(50)  NOT NULL,
  [claim_status]               NVARCHAR(20)  NOT NULL,  -- Open / Approved / Rejected / Paid
  [claim_amount]                 DECIMAL(10,2) NOT NULL,
  [incurred_date]                  DATE          NOT NULL,
  [settled_date]                     DATE          NULL     -- nullable (open claims); a few precede incurred_date by design
)
GO


/* =====================================================================
   STAGE 2 — Table & column descriptions

   IMPORTANT: uses 'MS_Description', the property name SQL Server
   tooling (SSMS tooltips) and Microsoft Purview scans recognise as
   the canonical description. A hand-rolled property name here would
   sit in the database inertly and never surface as a description
   later in the Purview catalogue.
===================================================================== */

EXEC sp_addextendedproperty @name = N'MS_Description',
  @value = N'Owner: Compliance & DPO (PII policy) / Steward: Underwriting (day-to-day)',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_customer';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'PII',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_customer', @level2type = N'Column', @level2name = 'date_of_birth';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'PII',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_customer', @level2type = N'Column', @level2name = 'address_line1';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'PII, nullable',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_customer', @level2type = N'Column', @level2name = 'address_line2';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'PII',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_customer', @level2type = N'Column', @level2name = 'postcode';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'PII, nullable ~5% missing by design',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_customer', @level2type = N'Column', @level2name = 'email';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'PII, nullable ~5% missing by design',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_customer', @level2type = N'Column', @level2name = 'phone_number';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Standard / Mutual Rewards — casing inconsistent by design',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_customer', @level2type = N'Column', @level2name = 'customer_segment';
GO

EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Owner: Underwriting',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_product';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Motor / Home / Travel',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_product', @level2type = N'Column', @level2name = 'product_name';
GO

EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Owner: Underwriting',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_branch';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Direct / Broker',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_branch', @level2type = N'Column', @level2name = 'channel';
GO

EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Owner: Shared / reference data — no single business owner',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_date';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Format YYYYMMDD',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_date', @level2type = N'Column', @level2name = 'date_key';
GO

EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Owner: Underwriting',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_policy';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Active / Lapsed / Cancelled',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'dim_policy', @level2type = N'Column', @level2name = 'status';
GO

EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Owner: Claims. Grain: one row per claim.',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'fact_claims';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'~1% orphaned by design (see Stage 5 for FK handling)',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'fact_claims', @level2type = N'Column', @level2name = 'policy_id';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Denormalised from dim_policy for query convenience',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'fact_claims', @level2type = N'Column', @level2name = 'customer_id';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Collision, Theft, Fire, Water Damage, etc.',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'fact_claims', @level2type = N'Column', @level2name = 'claim_type';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Open / Approved / Rejected / Paid',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'fact_claims', @level2type = N'Column', @level2name = 'claim_status';
GO
EXEC sp_addextendedproperty @name = N'MS_Description', @value = N'Nullable; a few rows precede incurred_date by design',
  @level0type = N'Schema', @level0name = 'dbo', @level1type = N'Table', @level1name = 'fact_claims', @level2type = N'Column', @level2name = 'settled_date';
GO


/* =====================================================================
   STAGE 3 — Foreign key constraints (all except fact_claims.policy_id)
===================================================================== */

ALTER TABLE [dim_policy]
  ADD CONSTRAINT FK_policy_customer FOREIGN KEY ([customer_id]) REFERENCES [dim_customer] ([customer_id]);
GO
ALTER TABLE [dim_policy]
  ADD CONSTRAINT FK_policy_product FOREIGN KEY ([product_id]) REFERENCES [dim_product] ([product_id]);
GO
ALTER TABLE [dim_policy]
  ADD CONSTRAINT FK_policy_branch FOREIGN KEY ([branch_id]) REFERENCES [dim_branch] ([branch_id]);
GO
ALTER TABLE [fact_claims]
  ADD CONSTRAINT FK_claims_customer FOREIGN KEY ([customer_id]) REFERENCES [dim_customer] ([customer_id]);
GO
ALTER TABLE [fact_claims]
  ADD CONSTRAINT FK_claims_date FOREIGN KEY ([claim_date_key]) REFERENCES [dim_date] ([date_key]);
GO


/* =====================================================================
   STAGE 4 — Indexes on fact_claims foreign key columns

   fact_claims will be filtered/joined on these columns constantly
   once dashboards exist; SQL Server does not auto-index FK columns.
===================================================================== */

CREATE NONCLUSTERED INDEX IX_claims_policy_id   ON [fact_claims] ([policy_id]);
GO
CREATE NONCLUSTERED INDEX IX_claims_customer_id ON [fact_claims] ([customer_id]);
GO
CREATE NONCLUSTERED INDEX IX_claims_date_key    ON [fact_claims] ([claim_date_key]);
GO


/* =====================================================================
   >>> STOP HERE. Run data-generator.py now to load synthetic data. <<<
   Everything below runs AFTER the data is loaded.
===================================================================== */


/* =====================================================================
   STAGE 5 — Deferred FK constraint: fact_claims.policy_id

   WITH NOCHECK adds the constraint without validating existing rows,
   so the ~1% deliberately orphaned claims already loaded are kept.
   The constraint is enforced for all NEW inserts from this point on.
   SQL Server marks it "untrusted" until validated — you can list the
   exact violating rows at any time with DBCC CHECKCONSTRAINTS, which
   is a genuine SQL-layer data quality check worth screenshotting for
   the Phase 3 case study.
===================================================================== */

ALTER TABLE [fact_claims] WITH NOCHECK
  ADD CONSTRAINT FK_claims_policy FOREIGN KEY ([policy_id]) REFERENCES [dim_policy] ([policy_id]);
GO

-- Optional: list every row that violates the constraint (the orphaned claims)
-- DBCC CHECKCONSTRAINTS ('FK_claims_policy');
