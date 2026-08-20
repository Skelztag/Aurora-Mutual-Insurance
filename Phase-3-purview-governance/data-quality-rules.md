# Aurora Mutual Insurance — Data Quality Rules

## Purpose

This document defines the data quality rules applied to the Aurora Mutual dataset,
organized by standard DQ dimension. Each rule traces back to a data quality issue
deliberately planted in the Phase 1 synthetic data generator, so that this project
demonstrates the full loop: design a realistic flaw → detect it → measure it →
report it — rather than measuring a dataset that was artificially perfect from the
start.

---

## Rules

| # | Dimension | Rule | Table.Column | Rule logic | Expected result |
|---|---|---|---|---|---|
| 1 | Completeness | Email should not be null | `dim_customer.email` | `email IS NOT NULL` | ~95% pass (~5% planted missing) |
| 2 | Completeness | Phone number should not be null | `dim_customer.phone_number` | `phone_number IS NOT NULL` | ~95% pass (~5% planted missing) |
| 3 | Validity | Postcode should match UK postcode format | `dim_customer.postcode` | Regex: `^[A-Z]{1,2}\d[A-Z\d]? ?\d[A-Z]{2}$` | ~98.5% pass (~1.5% planted malformed) |
| 4 | Uniqueness | No duplicate customers (same DOB + postcode) | `dim_customer` | `COUNT(*) GROUP BY date_of_birth, postcode HAVING COUNT(*) > 1` | ~2% of rows are duplicates (bronze/silver only \u2014 gold has this resolved) |
| 5 | Referential integrity | Every claim must reference a valid policy | `fact_claims.policy_id` \u2192 `dim_policy.policy_id` | `LEFT JOIN ... WHERE dim_policy.policy_id IS NULL` | ~99% pass (~1% planted orphaned claims) |
| 6 | Validity | Settlement date must not precede incurred date | `fact_claims.settled_date` vs `incurred_date` | `settled_date < incurred_date` (where settled_date is not null) | ~99% pass (5 planted illogical rows out of 234 settled claims) |
| 7 | Consistency | Customer segment should use standardized values | `dim_customer.customer_segment` | Value must be exactly `Standard` or `Mutual Rewards` | Bronze/silver-untouched: fails on ~5% casing variants. Gold: 100% pass (cleaned in Phase 2) |
| 8 | Validity | Claim amount must be positive | `fact_claims.claim_amount` | `claim_amount > 0` | 100% pass (not a planted issue \u2014 included as a baseline sanity check) |

---

## Rule ownership

Per the Phase 0 stewardship model:
- **Rules 1\u20134, 7** (customer data) \u2014 owned by Underwriting, DPO sign-off on completeness thresholds
- **Rules 5, 6, 8** (claims data) \u2014 owned by Claims

## Layer applicability

Rules 4 and 7 are **expected to fail at bronze and silver-untouched layers but pass
at gold**, since deduplication and segment standardization were deliberately
performed in the Phase 2 silver transformation. This is intentional: the scorecard
should show these rules improving across layers, demonstrating the medallion
architecture's value rather than a single static pass/fail state.

Rules 1, 2, 3, 5, 6, 8 are **expected to fail at the same rate across all three
layers**, since these specific issues were deliberately left uncleaned all the way
through to gold (see Phase 2's documented decision to preserve them for this
exact exercise).
