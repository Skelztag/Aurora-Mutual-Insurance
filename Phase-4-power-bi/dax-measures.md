# Aurora Mutual Insurance — DAX Measures Documentation

## Overview

This document defines the DAX measures built into `AuroraMutualSemanticModel`,
hosted in a dedicated `_Measures` table. Each measure's definition is deliberately
identical in wording to its corresponding business glossary term from Phase 3
(`enterprise glossary` in Purview) — the semantic model implements the same
definitions the business already agreed on, rather than introducing a second,
potentially inconsistent version of the same concept.

---

## Measures

### Gross Written Premium
```dax
Gross Written Premium = SUM(dim_policy[annual_premium])
```
**Description:** The total premium income from all policies written in a period,
before deducting reinsurance costs.
**Format:** Currency (£)
**Glossary term:** Gross Written Premium (GWP)

### Loss Ratio
```dax
Loss Ratio = DIVIDE(SUM(fact_claims[claim_amount]), [Gross Written Premium])
```
**Description:** Claims paid out as a proportion of premium earned, expressed as
a percentage; a core measure of underwriting profitability.
**Format:** Percentage
**Glossary term:** Loss Ratio
**Note:** Uses `DIVIDE()` rather than the `/` operator specifically to handle the
case where GWP is filtered to zero (e.g. an empty date range) without throwing a
divide-by-zero error — `DIVIDE()` returns blank instead of erroring.
**Known result — 143.5%, left uncorrected deliberately.** This is mathematically
correct DAX exposing a real Phase 1 data design gap: claim severity ranges were
never calibrated against premium ranges to produce a realistic book-level ratio.
See `case-study.md` for the full reasoning. A caveat note is displayed next to
this measure's card on the live dashboard.

### Claims Frequency
```dax
Claims Frequency = DIVIDE(COUNTROWS(fact_claims), COUNTROWS(dim_policy))
```
**Description:** The number of claims made per policy over a given period.
**Format:** Percentage
**Glossary term:** Claims Frequency

### Average Claim Cost
```dax
Average Claim Cost = AVERAGE(fact_claims[claim_amount])
```
**Description:** The mean claim payout amount across all claims, regardless of
status.
**Format:** Currency (£)
**Glossary term:** none (added per the original Phase 4 action list as a useful
supporting KPI, not one of the four originally-glossaried measures)

---

## Governance KPI measures

Added as part of the post-Phase-5 governance maturity extension, sourced from
`cde_register.csv`, `issue_register.csv`, and `governance_coverage_facts.csv` —
loaded as real Fabric tables, not hardcoded values, so every figure below is a
genuine computed measure.

### Open Issues
```dax
Open Issues = COUNTROWS(FILTER(issue_register, issue_register[status] <> "Closed"))
```
**Description:** Count of data issues not yet closed. Breaks down automatically
by severity when grouped by the `severity` column in a visual.

### Overdue Remediation Actions
```dax
Overdue Remediation Actions = COUNTROWS(FILTER(issue_register, issue_register[status] <> "Closed" && issue_register[due_date] < TODAY()))
```
**Description:** Open issues whose due date has passed.

### Average Issue Age (Days)
```dax
Average Issue Age (Days) = AVERAGEX(FILTER(issue_register, issue_register[status] <> "Closed"), DATEDIFF(issue_register[detected_date], TODAY(), DAY))
```
**Description:** Mean number of days open issues have remained unresolved.

### % CDEs Meeting Threshold
```dax
% CDEs Meeting Threshold = DIVIDE(COUNTROWS(FILTER(cde_register, cde_register[meets_threshold] = "Yes")), COUNTROWS(cde_register))
```
**Description:** Proportion of the 9 registered Critical Data Elements whose
latest data quality result meets its assigned threshold. Result: 66.7% (6 of 9)
— the 3 breaches (postcode, email, claim-policy referential integrity) each
have a corresponding tracked entry in `data-issue-register.md`.

### Coverage measures (Catalogue, Glossary Publication, Glossary Column Linkage, PII Classification, Workspace Lineage, Table Lineage)
```dax
Catalogue Coverage % = CALCULATE(SUM(governance_coverage_facts[coverage_pct]), governance_coverage_facts[fact_id] = "FACT-01") / 100
```
*(and five more, identical pattern, one per row in `governance_coverage_facts`,
FACT-02 through FACT-06)*
**Description:** Each pulls a single pre-computed coverage percentage from the
facts table. **Deliberately not blended into fewer, broader measures** —
Workspace Lineage (100%) and Table Lineage (0%) in particular are kept as two
separate measures rather than averaged into one misleading 50% figure.

---

**Renewal Rate was defined as a glossary term in Phase 3, but deliberately not
implemented as a DAX measure here.** The current schema has no field linking an
expiring policy to the policy that renewed it — each row in `dim_policy` is an
independent policy record with no "renewed from" reference. Any DAX formula
written against the current schema would be approximating or guessing at
renewal behaviour rather than measuring it directly.

**What would be needed to implement this properly:** a `renewed_from_policy_id`
field on `dim_policy` (nullable, self-referencing), populated at the point a
renewal transaction occurs in the source system. This is flagged here as a
documented schema gap rather than worked around with a misleading measure — a
DAX measure that looks correct but measures the wrong thing is a worse outcome
for a report consumer than an honestly missing one.
