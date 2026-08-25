# Aurora Mutual Insurance — Critical Data Elements (CDE) Register

## Purpose

A Critical Data Element is a field whose failure — wrong, missing, or delayed —
would cause material business or regulatory harm. Governance attention is
finite; this register identifies the ~10-20 fields across Aurora Mutual's
schema that warrant active quality monitoring and named accountability, rather
than treating every column with equal rigour.

**Selection criteria** (a field qualifies if it meets at least one):
- Feeds regulatory or financial reporting
- Directly affects customer treatment or service
- Errors here would cause a financial misstatement or bad business decision
- Acts as a control point other data depends on (e.g. a referential integrity key)

Note: CDE status is a distinct lens from the GDPR classification in
`gdpr-classification-policy.md`. Classification asks "does this need protecting
from unauthorised access?" (a privacy/security question). CDE status asks
"does this need active quality monitoring because errors cause business harm?"
(an operational-risk question). The two overlap on some fields and not others —
see `postcode` and `annual_premium` below for one of each case.

---

## Register

| CDE ID | Business Domain | Business Term | Technical Asset.Column | Definition | Data Owner | Data Steward | Sensitivity | Quality Dimension(s) | Quality Threshold | Latest Result | Meets Threshold? | Source System | Downstream Use | Regulatory/Business Impact |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CDE-01 | Customer | Postcode | `dim_customer.postcode` | Customer's postal code | Compliance & DPO | Underwriting | High (PII) | Validity | ≥99% | 98.73% | ❌ No | Azure SQL → Fabric | Correspondence, risk-based pricing | Customer correspondence failure; poor location-based servicing |
| CDE-02 | Customer | Date of Birth | `dim_customer.date_of_birth` | Customer's date of birth | Compliance & DPO | Underwriting | High (PII) | Completeness, Validity | 100% | 100% | ✅ Yes | Azure SQL → Fabric | Age-based underwriting | Miscalculated premium; fraud/identity risk |
| CDE-03 | Customer | Email | `dim_customer.email` | Customer's contact email | Compliance & DPO | Underwriting | Medium (PII) | Completeness | ≥98% | 95.57% | ❌ No | Azure SQL → Fabric | Digital correspondence | Missed communications, renewal notices |
| CDE-04 | Policy | Gross Written Premium (source) | `dim_policy.annual_premium` | Annual premium value per policy | Finance | Underwriting | None | Validity | 100% | 100% | ✅ Yes | Azure SQL → Fabric | Gross Written Premium (glossary measure) | Direct financial reporting error |
| CDE-05 | Policy | Policy Status | `dim_policy.status` | Active / Lapsed / Cancelled | Underwriting | Underwriting | None | Validity | 100% | 100% | ✅ Yes | Azure SQL → Fabric | Coverage determination | Customer wrongly believes they are/aren't covered |
| CDE-06 | Policy | Policy Start Date | `dim_policy.policy_start_date` | Date coverage begins | Underwriting | Underwriting | None | Validity | 100% | 100% | ✅ Yes | Azure SQL → Fabric | Coverage window checks | Valid claim wrongly rejected, or invalid claim wrongly paid |
| CDE-07 | Claims | Claim Amount | `fact_claims.claim_amount` | Value of the claim | Claims | Claims | None | Validity | 100% | 100% | ✅ Yes | Fabric pipeline | Loss Ratio, payout processing | Direct financial impact — over/under payment |
| CDE-08 | Claims | Claim Status | `fact_claims.claim_status` | Open / Approved / Rejected / Paid | Claims | Claims | None | Validity | 100% | 100% | ✅ Yes | Fabric pipeline | Payment processing | Incorrect payment or payment delay |
| CDE-09 | Claims | Policy Reference | `fact_claims.policy_id` | Links a claim to its policy | Claims | Claims | None | Referential Integrity | 100% | 99% | ❌ No | Fabric pipeline (ETL) | Claims eligibility validation | Claim cannot be validated against coverage; potential fraud exposure |

**Summary: 6 of 9 CDEs (66.7%) meet their quality threshold** as of the latest
data quality rule execution. The three breaches (CDE-01, CDE-03, CDE-09) each
have a corresponding tracked entry in `data-issue-register.md`.

---

## Notes

- **CDE-01 and CDE-09 already have measured, real quality results** in
  `data-quality-scorecard.md` — this register does not introduce new
  investigation, it reframes existing findings under an operational-risk lens
  rather than a data-quality-testing lens.
- **CDE-04 is a useful contrast with CDE-01**: `annual_premium` carries no PII
  classification at all (it isn't personal data), but it is unambiguously
  critical, since it feeds Gross Written Premium — a core financial figure.
  This illustrates why CDE status and PII classification are separate,
  independent assessments rather than the same exercise twice.
- This register should be reviewed whenever the schema changes, and CDE status
  re-assessed rather than assumed permanent — a field's criticality can change
  as the business changes (e.g. a new regulatory reporting requirement could
  promote a previously non-critical field).
