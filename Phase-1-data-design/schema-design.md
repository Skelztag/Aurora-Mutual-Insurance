# Aurora Mutual Insurance — Schema Design

## Modelling approach

This schema uses a **Kimball-style star schema**: one central fact table (`fact_claims`)
surrounded by conformed dimension tables. This pattern is deliberately chosen because it
mirrors how Power BI's VertiPaq engine and Microsoft Fabric semantic models expect data to
be structured — the same modelling discipline applies directly to the DP-600 syllabus.

**Rule used to classify each table:** if it answers *"what happened, and how much?"* it's a
fact table. If it answers *"who, what type, when, where?"* it's a dimension table.

**Target volumes:** ~3,000 customers · ~4,500 policies · ~800 claims.

---

## Entities

### `dim_customer` — one row per customer
| Field | Type | Notes |
|---|---|---|
| customer_id | INT, PK | |
| first_name | VARCHAR | |
| last_name | VARCHAR | |
| date_of_birth | DATE | PII |
| address_line1 | VARCHAR | PII |
| address_line2 | VARCHAR | PII, nullable |
| city | VARCHAR | |
| postcode | VARCHAR | PII |
| email | VARCHAR | PII, nullable (~5% missing by design) |
| phone_number | VARCHAR | PII, nullable (~5% missing by design) |
| customer_segment | VARCHAR | Standard / Mutual Rewards — casing inconsistent by design |
| join_date | DATE | |
| marketing_consent_flag | BOOLEAN | GDPR-relevant in its own right |

### `dim_policy` — one row per policy
| Field | Type | Notes |
|---|---|---|
| policy_id | INT, PK | |
| customer_id | INT, FK → dim_customer | |
| product_id | INT, FK → dim_product | |
| branch_id | INT, FK → dim_branch | |
| policy_start_date | DATE | |
| policy_end_date | DATE | |
| status | VARCHAR | Active / Lapsed / Cancelled |
| annual_premium | DECIMAL | |
| sum_insured | DECIMAL | |

### `dim_product` — one row per product
| Field | Type | Notes |
|---|---|---|
| product_id | INT, PK | |
| product_name | VARCHAR | Motor / Home / Travel |
| product_category | VARCHAR | |

### `dim_branch` — one row per branch (also serves as the agent/channel dimension)
| Field | Type | Notes |
|---|---|---|
| branch_id | INT, PK | |
| branch_name | VARCHAR | |
| region | VARCHAR | |
| channel | VARCHAR | Direct / Broker |

### `dim_date` — standard Kimball date dimension, one row per calendar day
| Field | Type | Notes |
|---|---|---|
| date_key | INT, PK | Format YYYYMMDD |
| full_date | DATE | |
| day | INT | |
| month | INT | |
| month_name | VARCHAR | |
| quarter | INT | |
| year | INT | |
| is_weekend | BOOLEAN | |

### `fact_claims` — one row per claim (grain: one claim = one row)
| Field | Type | Notes |
|---|---|---|
| claim_id | INT, PK | |
| policy_id | INT, FK → dim_policy | ~1% orphaned by design |
| customer_id | INT, FK → dim_customer | |
| claim_date_key | INT, FK → dim_date | |
| claim_type | VARCHAR | Collision, Theft, Fire, Water Damage, etc. |
| claim_status | VARCHAR | Open / Approved / Rejected / Paid |
| claim_amount | DECIMAL | |
| incurred_date | DATE | |
| settled_date | DATE | nullable; a few rows precede incurred_date by design |

---

## Relationships

- `dim_customer` 1 — * `dim_policy` (a customer can hold multiple policies — this is what
  enables the Mutual Rewards multi-product segment)
- `dim_product` 1 — * `dim_policy`
- `dim_branch` 1 — * `dim_policy`
- `dim_policy` 1 — * `fact_claims`
- `dim_customer` 1 — * `fact_claims` (denormalised onto the fact table for query
  convenience — a deliberate, documented modelling choice, not an oversight)
- `dim_date` 1 — * `fact_claims`

---

## Deliberate data quality issues (planted for Phase 3)

Each issue below is planted at a controlled rate so it can later be caught, measured, and
scored by a specific Purview DQ rule. Nothing here is incidental — each row maps forward to
a rule we'll define in `data-quality-rules.md`.

| Issue | Where | Rate | DQ rule it will exercise later |
|---|---|---|---|
| Missing email/phone | `dim_customer` | ~5% each | Completeness check |
| Duplicate customer (name/address variant) | `dim_customer` | ~2% | Uniqueness / duplicate detection |
| Malformed postcode | `dim_customer.postcode` | small sample | Format validation |
| Orphaned claim (no matching policy) | `fact_claims.policy_id` | ~1% | Referential integrity |
| settled_date before incurred_date | `fact_claims` | small sample | Logical/temporal validity |
| Inconsistent segment casing | `dim_customer.customer_segment` | subset | Standardisation / conformity |

---

## Ownership (traced back to the Phase 0 org chart)

| Table | Owning function |
|---|---|
| `dim_customer` | Compliance & DPO (PII), day-to-day steward: Underwriting |
| `dim_policy`, `dim_product`, `dim_branch` | Underwriting |
| `fact_claims` | Claims |
| `dim_date` | Shared/no single owner (reference data) |
