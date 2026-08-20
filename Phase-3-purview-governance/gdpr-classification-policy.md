# Aurora Mutual Insurance — GDPR / UK-DPA Classification Policy

## Purpose

This policy defines how Aurora Mutual classifies personal data held in its customer
and policy systems, in line with UK GDPR and the Data Protection Act 2018 (UK-DPA).
It establishes a consistent sensitivity scale, applies that scale to every field in
`dim_customer` (the only table holding personal data in this schema), and assigns
accountability for maintaining these classifications going forward.

---

## Classification scale

| Level | Definition | Handling requirement |
|---|---|---|
| **High** | Directly identifying, or capable of enabling fraud/impersonation if exposed (e.g. date of birth combined with address) | Restricted access; masking in non-production environments; audit-logged access |
| **Medium** | Identifying only in combination with other fields; contact information | Access limited to roles with a legitimate business need |
| **Low** | Business-relevant but not personally identifying on its own | Standard internal access controls |
| **None** | Not personal data | No special handling |

This mirrors the practical distinction UK GDPR draws between data that identifies a
person outright versus data that only becomes identifying in combination — the same
logic that makes "postcode alone" materially less sensitive than "postcode + date of
birth" held together, even though both are stored in the same table here.

---

## Field-level classification — `dim_customer`

| Field | Classification | Rationale |
|---|---|---|
| `customer_id` | None | Internal surrogate key; not personal data on its own |
| `first_name` | Medium | Identifying only in combination with other fields |
| `last_name` | Medium | Identifying only in combination with other fields |
| `date_of_birth` | **High** | Combined with name/address, materially increases identity-fraud risk; also relevant to age-based underwriting decisions |
| `address_line1` | **High** | Directly identifying; a physical location |
| `address_line2` | Medium | Only identifying in combination with address_line1 |
| `city` | Low | Broad geography; not identifying alone |
| `postcode` | **High** | UK postcodes can narrow identification to a small number of households |
| `email` | Medium | Contact/identifying information; not physically locating |
| `phone_number` | Medium | Contact/identifying information; not physically locating |
| `customer_segment` | Low | Business classification, not personal data |
| `join_date` | Low | Business/operational data |
| `marketing_consent_flag` | **High** | Governs a specific legal basis for processing (consent) under GDPR Article 6/7 — mishandling this field has direct compliance consequences beyond identity risk |

No other table in this schema (`dim_policy`, `dim_product`, `dim_branch`, `dim_date`,
`fact_claims`) contains personal data directly. `fact_claims.customer_id` is a
reference key only, not personal data in itself, though it enables joining back to
`dim_customer`.

---

## Legal basis for processing

Aurora Mutual processes customer personal data under two lawful bases (UK GDPR
Article 6):
- **Contract** — data required to administer an active insurance policy
  (name, address, date of birth, policy details)
- **Consent** — marketing communications, governed by `marketing_consent_flag`;
  withdrawable at any time, and the flag itself must reflect the customer's current
  choice accurately

## Data subject rights

Customers may request access to, correction of, or erasure of their personal data
(subject to Aurora Mutual's regulatory retention obligations as an insurer, which
may override erasure requests for active or recently-closed policies). Requests are
routed through Compliance & DPO per the Phase 0 org chart.

## Ownership and review

- **Policy owner:** Compliance & DPO
- **Field-level classification maintained by:** Underwriting (day-to-day steward of
  `dim_customer`), with DPO sign-off required for any classification downgrade
- **Review cadence:** this policy should be reviewed whenever the customer schema
  changes, and at minimum annually
