# Aurora Mutual Insurance — Fabric Pipeline Documentation

## Overview

This document explains the Microsoft Fabric architecture built in Phase 2: how data
moves from the Azure SQL Database (Phase 1) through a medallion architecture
(bronze → silver → gold) inside a Fabric Lakehouse, ready for semantic modelling and
Power BI dashboards in Phase 4.

---

## Environment setup

**Fabric trial access:** activated via a work Microsoft 365 account (HeyHuman), after
first considering — and building most of the way through — a personal-email path using
a dedicated Microsoft Entra ID user, specifically to keep this portfolio project
independent of any single employer's tenant. The personal-Entra-ID route remains the
more portable choice for anyone repeating this project outside of a work environment;
it involves creating a user in Microsoft Entra ID (Azure's identity service) and signing
into the Fabric portal with that identity rather than a personal Outlook/Gmail account,
since Fabric's default trial flow expects a work-style account.

**Workspace:** `Aurora Mutual Insurance` — a dedicated Fabric workspace holding every
item built across Phases 2–4 (Lakehouse, pipeline, notebooks, and later the semantic
model and reports), kept separate from any other content in the tenant.

**Lakehouse:** `AuroraMutualLakehouse` — the single storage item underpinning the whole
medallion architecture. Fabric provisions this with schema support enabled by default
(tables sit under a `dbo` schema), and automatically creates a paired SQL analytics
endpoint and default semantic model alongside it (not used until Phase 4).

---

## Medallion architecture: design decision

Rather than provisioning three separate physical Lakehouses for bronze/silver/gold,
this project uses **one Lakehouse with a table-naming convention** to represent each
layer:

- **Bronze:** `bronze_<table_name>` — raw, untouched copies of the Azure SQL source
- **Silver:** `silver_<table_name>` — cleaned/standardized versions
- **Gold:** `<table_name>` (no prefix) — business-ready tables, intended for direct use
  by report builders and the Phase 4 semantic model

This is a common, lightweight pattern for medallion architecture at this scale, and
keeps lineage easy to trace by table name alone.

---

## Bronze layer: ingestion pipeline

**Item:** `pl_bronze_ingest` (Fabric Data pipeline)

**What it does:** six `Copy data` activities, one per source table, each connecting to
the Azure SQL Database (`AuroraMutualDB`) as source and writing a full, untransformed
copy into the Lakehouse as a `bronze_`-prefixed table.

**Key configuration decisions:**
- **Full copy, not Incremental copy.** Incremental copy is designed for repeatedly-run
  pipelines that only pull new/changed rows via a watermark column. Since this is a
  static, one-time historical load of synthetic data, Full copy was the correct,
  simpler choice — Incremental copy would have added unnecessary complexity (and
  required a watermark column none of these tables meaningfully have).
- **Table action: Overwrite, not Append.** Ensures re-running the pipeline (e.g. during
  troubleshooting) replaces each bronze table cleanly rather than duplicating rows on
  top of a previous run.
- **Activities run independently/in parallel**, not chained in sequence — the six
  table copies have no dependency on one another, so leaving them unconnected on the
  pipeline canvas allows Fabric to run all six simultaneously rather than one after
  another, at no extra design cost.
- **Naming convention:** `cp_bronze_<table_name>` for each activity, matching its
  destination table, so the pipeline canvas is self-documenting at a glance.

**Bronze tables produced:** `bronze_dim_branch`, `bronze_dim_customer`, `bronze_dim_date`,
`bronze_dim_policy`, `bronze_dim_product`, `bronze_fact_claims` — all six verified to
match source row counts exactly (3,000 / 4,500 / 800 / etc.) after the run.

---

## Silver layer: cleaning and standardization

**Item:** `nb_bronze_to_silver` (PySpark notebook)

**Design decision — deliberately partial cleaning:** silver does not fix every data
quality issue planted in Phase 1. Two categories were intentionally left untouched, on
the reasoning that Purview's data quality rules and scorecard (Phase 3) need real,
still-present issues to detect and report on, rather than a dataset that's already
artificially perfect by the time it reaches governance tooling:

| Fixed at silver | Left for Purview to catch (Phase 3) |
|---|---|
| Inconsistent `customer_segment` casing | Malformed postcodes |
| Whitespace in name fields | Missing email/phone (completeness) |
| Duplicate customer records | Orphaned claims (referential integrity) |
| | Illogical settled/incurred dates |

**Transformations applied to `dim_customer`:**
1. `trim()` applied to `first_name` / `last_name` — removes stray whitespace planted
   in the duplicate-customer generation.
2. `initcap()` applied to `customer_segment` — normalises all six casing variants
   (`standard`, `STANDARD`, `Standard`, etc.) down to two clean values: `Standard` and
   `Mutual Rewards`.
3. **Deduplication**, using `date_of_birth` + `postcode` as the match key. This key was
   chosen because it's known to be invariant across the synthetic duplicate-generation
   logic in Phase 1 (only name/address fields were varied when duplicates were
   created) — it is **not** a general-purpose fuzzy-matching solution, and this
   limitation is noted explicitly here rather than implied to be more robust than it
   is. A `ROW_NUMBER()` window function keeps the lowest `customer_id` per match-key
   group and drops the rest.

**Result:** 3,000 → 2,940 customers (60 duplicates removed, matching the ~2% planted
rate exactly); segment values reduced from 6 casing variants to 2 clean categories
(786 Mutual Rewards / 2,154 Standard).

All other tables (`dim_product`, `dim_branch`, `dim_date`, `dim_policy`, `fact_claims`)
pass through from bronze to silver unchanged, since no cleaning was required for them
at this stage.

---

## Gold layer: business-ready tables

**Item:** `nb_silver_to_gold` (PySpark notebook)

**Design principle:** gold is where calculated, report-oriented fields are added —
fields that don't exist in the source system and shouldn't live in bronze/silver, since
those layers are meant to stay a faithful, unopinionated reflection of the source.

**Calculated fields added:**
- `dim_customer.age_years` and `dim_customer.tenure_years` — derived from
  `date_of_birth` and `join_date` respectively.
- `dim_policy.policy_duration_days` — derived from `policy_start_date` /
  `policy_end_date`.
- `fact_claims.settlement_duration_days` — derived from `incurred_date` /
  `settled_date`. This column is `NULL` for still-open claims (no settlement date yet)
  and **negative** for the deliberately-planted illogical-date rows — which is treated
  as a feature, not a bug: it makes that specific data quality issue directly visible
  and filterable at the gold layer, ready for a Purview rule or Power BI filter in
  later phases.

**Naming:** gold tables drop the layer prefix entirely (`dim_customer`, not
`gold_dim_customer`), since gold is the layer intended for direct use by report
builders — clean names reduce friction for anyone building on top of it later.

**Verification (spot-checked in-notebook):**
- Row counts carried through correctly at every stage (2,940 / 4,500 / 800)
- `age_years` range: 18–85, exactly matching the bounds set in the original Python
  data generator — confirms the age calculation is correct, not just plausible
- Exactly 5 negative `settlement_duration_days` values — matches the 5 illogical dates
  planted in Phase 1 precisely

---

## Notable issues encountered and resolved

Documented here because each reflects a genuine design or environment decision, not
just a fixed typo:

1. **Copy job wizard vs. Copy data activity.** The multi-table "Copy job" wizard
   initially seemed like the efficient choice for copying six tables at once, but it
   creates a separate linked Fabric item requiring its own service connection, which
   had no available options in this environment. Switched to individual `Copy data`
   activities per table instead — more manual, but every configuration step is
   transparent and self-contained within the pipeline itself.
2. **Table/schema field confusion.** The Copy data activity's "Table" field is two
   separate inputs (schema, table name), not one free-text path — entering
   `dbo.bronze_dim_branch` as a single "schema" value caused SQL Server to look for a
   literally-named schema that didn't exist. Corrected by keeping schema as `dbo` and
   applying the `bronze_` prefix only on the destination side.
3. **Spark capacity limit.** Fabric trial capacities allow only one active Spark
   session at a time; starting the `nb_silver_to_gold` notebook while
   `nb_bronze_to_silver`'s session was still active produced a
   `TooManyRequestsForCapacity` error. Resolved by explicitly stopping the prior
   notebook's session via the Monitoring hub before starting a new one — now standard
   practice for the rest of this project.
