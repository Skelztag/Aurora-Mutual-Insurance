# Aurora Mutual Insurance — Data Issue & Remediation Register

## Purpose

This register turns data quality findings from `data-quality-scorecard.md` into
formal governance cases, tracked through a detect → triage → assign → root
cause → remediate → validate → close lifecycle. It demonstrates the
operational workflow a Data Office uses to manage data problems, rather than
treating a failed test as an end state in itself.

**Escalation rule:** any High-severity issue open for more than 10 business
days without an assigned remediation date is escalated to the relevant Data
Owner for a decision.

---

## Summary

| Issue ID | CDE | Description | Severity | Status | Closure Date |
|---|---|---|---|---|---|
| ISSUE-01 | CDE-01 (Postcode) | 39 malformed customer postcodes | Medium | Open — Accepted Risk | — |
| ISSUE-02 | CDE-09 (Claim → Policy reference) | 8 orphaned claims (no matching policy) | High | Open — Accepted Risk (controlled) | — |
| ISSUE-03 | Customer record (no single CDE) | 60 duplicate customer records | Medium | **Closed** | Phase 2 pipeline run |
| ISSUE-04 | Customer.customer_segment | 158 inconsistent segment casing values | Low | **Closed** | Phase 2 pipeline run |

---

## ISSUE-01 — Malformed customer postcodes

- **Date detected:** Phase 3 data quality rule execution
- **Domain / CDE:** Customer / CDE-01
- **Description:** 39 of 3,060 customer records (1.3%) have a postcode that
  does not match standard UK postcode format
- **DQ Dimension:** Validity
- **Severity:** Medium
- **Business impact:** Correspondence failure risk; degraded location-based
  risk pricing accuracy
- **Root cause:** No input-format validation was applied at the point of data
  capture in the source system (simulated deliberately in the synthetic data
  generator to represent this exact real-world scenario)
- **Data Owner:** Compliance & DPO · **Assigned Steward:** Underwriting
- **Due date:** 10 business days from detection (per this register's escalation
  rule) — 28 August 2026
- **Remediation action:** Cleanse the 39 existing records against Royal Mail
  PAF (Postcode Address File) reference data; introduce input-format
  validation at the point of capture to prevent recurrence
- **Status:** **Open — Accepted Risk.** This issue is deliberately left
  unremediated in the current pipeline (see `pipeline-documentation.md`'s
  documented Phase 2 decision) specifically so it remains detectable by
  governance tooling. In a production setting, remediation would proceed per
  the action above; here it is retained as a live, ongoing example of a
  tracked, known, owned issue rather than a silently-fixed one.
- **Preventive control:** The Phase 3 data quality rule (Rule 3 in
  `data-quality-rules.md`) re-detects this issue on every run, preventing it
  from silently growing unnoticed.

## ISSUE-02 — Orphaned claims (invalid policy reference)

- **Date detected:** Phase 1 data design (deliberately planted); confirmed via
  Phase 3 data quality rule execution
- **Domain / CDE:** Claims / CDE-09
- **Description:** 8 of 800 claims (1.0%) reference a `policy_id` that does
  not exist in `dim_policy`
- **DQ Dimension:** Referential Integrity
- **Severity:** High — a claim that cannot be validated against a real policy
  cannot be confirmed as legitimate
- **Business impact:** Claims eligibility cannot be verified; potential fraud
  or processing-error exposure
- **Root cause:** Simulated ETL load failure (in production, this pattern
  typically arises from a claims feed arriving before its corresponding policy
  feed, or a policy being deleted after a claim was already linked to it)
- **Data Owner:** Claims · **Assigned Steward:** Claims
- **Due date:** High severity — escalated immediately per the escalation rule;
  target resolution 3 business days from detection — 21 August 2026 (overdue,
  reflecting the genuine complexity of tracing 8 individual claims back to
  their source policy administration records)
- **Remediation action:** Investigate each orphaned claim against the source
  policy administration system; either correct the reference or flag the
  claim for manual review
- **Status:** **Open — Accepted Risk, but technically controlled.** Unlike
  ISSUE-01, this issue has an active technical control already in place: the
  `FK_claims_policy` constraint (see `ddl-scripts.sql`, Stage 5) is applied
  `WITH NOCHECK`, meaning these 8 known rows are tolerated, but the constraint
  actively **prevents any new orphaned claim from being created** going
  forward. `DBCC CHECKCONSTRAINTS` can list the exact violating rows at any
  time. This is a real example of a business deciding to tolerate a known,
  bounded issue while still controlling for recurrence.
- **Preventive control:** `FK_claims_policy` constraint (untrusted, active)
  + Phase 3 data quality rule (Rule 5)

## ISSUE-03 — Duplicate customer records (CLOSED)

- **Date detected:** Phase 1 data design (deliberately planted); confirmed via
  Phase 3 data quality rule execution
- **Domain / CDE:** Customer
- **Description:** 60 of 3,060 customer records (~2%) were duplicates of an
  existing customer, sharing identical date of birth and postcode but with
  minor variations in name casing, whitespace, or address abbreviation
- **DQ Dimension:** Uniqueness
- **Severity:** Medium
- **Business impact:** Inflated customer counts; risk of duplicate
  correspondence or conflicting service history
- **Root cause:** Simulated system-migration merge that was never completed
  (a common real-world cause of exactly this pattern)
- **Data Owner:** Compliance & DPO · **Assigned Steward:** Underwriting
- **Remediation action:** Deduplicate on `(date_of_birth, postcode)`, retaining
  the lowest `customer_id` per group
- **Status:** **Closed.** Remediated in the Phase 2 `nb_bronze_to_silver`
  notebook.
- **Validation result:** Confirmed via Phase 4 data quality rule (Rule 4b): 0
  duplicates present in the gold layer, down from 60 in bronze — a 100%
  resolution rate, verified by direct query rather than assumed.
- **Closure date:** Validated at Phase 2 pipeline execution; re-confirmed at
  Phase 3 data quality rule execution.

## ISSUE-04 — Inconsistent customer segment casing (CLOSED)

- **Date detected:** Phase 1 data design (deliberately planted); confirmed via
  Phase 3 data quality rule execution
- **Domain / CDE:** Customer (`customer_segment`)
- **Description:** 158 of 3,060 customer records (5.2%) stored
  `customer_segment` in inconsistent casing (e.g. `"standard"`, `"STANDARD"`,
  `"mutual rewards"`) instead of the two standard values
- **DQ Dimension:** Consistency
- **Severity:** Low
- **Business impact:** Reporting and segmentation queries would undercount
  segments unless case-insensitive matching was used everywhere — a fragile,
  error-prone workaround if left unfixed
- **Root cause:** No standardisation applied at the point of capture
  (simulated deliberately)
- **Data Owner:** Compliance & DPO · **Assigned Steward:** Underwriting
- **Remediation action:** Apply `initcap()` standardisation during the
  bronze-to-silver transformation
- **Status:** **Closed.** Remediated in the Phase 2 `nb_bronze_to_silver`
  notebook.
- **Validation result:** Confirmed via Phase 4 data quality rule (Rule 7b):
  100% pass rate in the gold layer, down from 94.84% in bronze — validated by
  direct query.
- **Closure date:** Validated at Phase 2 pipeline execution; re-confirmed at
  Phase 3 data quality rule execution.
