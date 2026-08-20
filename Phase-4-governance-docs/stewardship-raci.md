# Aurora Mutual Insurance — Stewardship RACI Matrix

## Purpose

This matrix maps the Phase 0 organisational roles against concrete governance
activities for each data domain, making explicit who does what — beyond the
high-level Owner/Steward/Custodian model in `data-governance-policy.md`.

**Key:** R = Responsible (does the work) · A = Accountable (answerable for the
outcome; one per activity) · C = Consulted (input sought beforehand) ·
I = Informed (kept up to date afterward)

---

## Customer domain

| Activity | Underwriting | Compliance & DPO | Claims | Actuarial | Finance |
|---|---|---|---|---|---|
| Data quality monitoring (completeness, duplicates) | R | I | — | — | — |
| PII classification decisions | C | A/R | — | — | — |
| Data subject access/erasure requests | C | A/R | — | — | — |
| Glossary term maintenance (Policyholder, Mutual Rewards) | R | A | — | — | — |
| Schema change approval | R | A | I | I | I |

## Policy domain

| Activity | Underwriting | Compliance & DPO | Claims | Actuarial | Finance |
|---|---|---|---|---|---|
| Data quality monitoring | R | I | — | C | C |
| Glossary term maintenance (Sum Insured, GWP) | R | I | — | C | A |
| Pricing/premium range decisions | C | I | — | A/R | C |
| Schema change approval | A/R | I | I | C | C |

## Claims domain

| Activity | Underwriting | Compliance & DPO | Claims | Actuarial | Finance |
|---|---|---|---|---|---|
| Data quality monitoring (referential integrity, illogical dates) | I | I | A/R | C | — |
| Glossary term maintenance (Claim Status) | I | I | A/R | C | — |
| Loss Ratio / Claims Frequency measure definitions | — | — | C | A/R | C |
| Fraud/anomaly investigation | I | C | A/R | C | — |

## Product & Branch (reference data)

| Activity | Underwriting | Compliance & DPO | Claims | Actuarial | Finance |
|---|---|---|---|---|---|
| Data quality monitoring | A/R | — | — | — | I |
| New product/branch onboarding | A/R | I | I | C | C |

---

## Notes

- **Compliance & DPO holds Accountable on all PII-related activities** regardless
  of domain, consistent with the classification policy's principle that
  Underwriting stewards day-to-day customer data quality, but DPO retains sign-off
  authority on anything touching personal data specifically.
- **Actuarial is Accountable for claims-derived measures** (Loss Ratio, Claims
  Frequency) since these are pricing/risk inputs, even though the underlying
  `fact_claims` data is Claims-owned — a common real-world split between who
  owns the *data* and who owns the *interpretation* of it for a specific business
  purpose.
- This matrix should be reviewed alongside the data governance policy, and
  whenever a new data domain or measure is introduced.
