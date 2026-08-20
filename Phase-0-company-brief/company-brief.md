# Aurora Mutual Insurance — Company Brief

## Who they are
Aurora Mutual Insurance is a mid-size UK mutual insurer headquartered in Manchester, with
~450 staff and a national personal-lines customer base. As a mutual, Aurora is owned by its
policyholders rather than shareholders — this shapes its stated priorities around trust,
transparency, and responsible data stewardship, which gives this project's governance work
a genuine business rationale rather than a compliance checkbox.

## What they sell
Three personal-lines products:
- **Motor** insurance
- **Home** insurance
- **Travel** insurance

Personal lines only (no commercial/business insurance) — this keeps the customer and policy
schema focused while still allowing for realistic cross-product behaviour (e.g. a customer
holding both Motor and Home policies).

## Who their customers are
- **Standard retail customers** — single-product policyholders, the majority segment.
- **Mutual Rewards members** — a loyalty tier for policyholders with 2+ active products or
  5+ years' tenure. Gets preferential renewal pricing and a dedicated service line.

This two-segment structure gives the customer dimension a meaningful attribute to slice by
in later dashboards, without requiring a full CRM-grade segmentation model.

## What "success" looks like
Aurora's leadership tracks three top-line KPIs:
1. **Policy growth** — year-on-year growth in active policy count
2. **Loss ratio** — claims paid out as a proportion of premium earned, held below a target
   ceiling
3. **Retention** — renewal rate across the existing book

These three metrics anchor the Phase 4 DAX measure set later in the project, so defining
them here isn't just narrative colour — it's the first governance decision in the chain.

## Org chart

| Function | Owns | Consumes |
|---|---|---|
| **Underwriting** | Product & policy data | Claims data (risk pricing input) |
| **Claims** | Claims data | Policy data (validating cover) |
| **Actuarial** | Pricing & risk models | Claims + policy data |
| **Finance** | Premium & financial reporting data | Policy + claims data |
| **Compliance & DPO** | Data protection policy, PII classification sign-off | All domains (oversight) |

This five-function structure is deliberately minimal — just enough named roles to support a
believable **stewardship RACI matrix** in Phase 5, mapped against the three core data
domains (Customer, Policy, Claims). Each domain will need a named Owner (accountable,
typically a Head of function), Steward (responsible for day-to-day data quality, typically
an analyst/manager), and the DPO will sit across all three for PII sign-off.

---
*This brief is the reference document for all later phases — schema design, glossary terms,
classification decisions, and stewardship roles should all be traceable back to something
defined here.*
