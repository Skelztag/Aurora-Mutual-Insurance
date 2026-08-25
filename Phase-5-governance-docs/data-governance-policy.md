# Aurora Mutual Insurance — Data Governance Policy

## Purpose

This policy establishes how Aurora Mutual governs its data: who is accountable for
it, how it is classified, and how access is controlled. It formalises the roles
and decisions made informally throughout Phases 0–4 of this project into a single
governing document.

---

## Roles

Aurora Mutual distinguishes three levels of data accountability, following the
DAMA-DMBOK stewardship model:

| Role | Definition | Accountable for |
|---|---|---|
| **Data Owner** | Senior accountable role for a data domain, typically a function head | Policy-level decisions: what data may be collected, retention, classification sign-off |
| **Data Steward** | Operational role responsible for day-to-day data quality within a domain | Monitoring the DQ scorecard, maintaining glossary term accuracy, requesting corrections |
| **Data Custodian** | Technical role responsible for the systems data physically lives in | Database/pipeline uptime, backup, technical access provisioning |

In this project, the same person (the author) performed all three roles across all
domains — a limitation of a solo portfolio build, documented honestly rather than
implied otherwise. Role assignments below describe the *intended* organisational
structure Aurora Mutual would use at real headcount, mapped from the Phase 0
company brief.

## Data domains and ownership

| Domain | Owner | Steward | Custodian |
|---|---|---|---|
| Customer | Compliance & DPO (PII policy) | Underwriting | Data Engineering |
| Policy | Underwriting | Underwriting | Data Engineering |
| Claims | Claims | Claims | Data Engineering |
| Product / Branch (reference data) | Underwriting | Underwriting | Data Engineering |

This table is expanded into a full RACI matrix in `stewardship-raci.md`.

---

## Classification policy

See `gdpr-classification-policy.md` for the full field-level classification of
`dim_customer`. In summary: personal data is classified High, Medium, Low, or None
based on identifying risk in combination with other fields, per UK GDPR / UK-DPA.
Classification is descriptive — it identifies what data requires protection — and
is deliberately kept separate from access enforcement (below), matching real-world
practice where these are typically owned by different teams.

---

## Access policy

**Principle:** access to personal data should be scoped to the minimum required
for a role's function (least-privilege), with classification driving the access
level, not vice versa. Classification (Phase 3) identifies *what* needs
protecting; access enforcement is the separate, subsequent step of actually
restricting who can see it — Aurora Mutual treats these as two distinct
governance activities, often owned by different teams in practice.

| Classification | Who may see unmasked | Who may see masked/restricted |
|---|---|---|
| High | Compliance & DPO only | All other roles |
| Medium | Compliance & DPO, Underwriting | Claims, Actuarial, Finance |
| Low / None | All roles | — |

**Implementation status: implemented and validated.** Role-based access
control and Dynamic Data Masking were implemented against the source Azure
SQL Database (`access-control-implementation.sql`) — five database roles
matching the org chart, table-level `GRANT`s (Claims has no access to
`dim_customer` at all, not even masked), and Dynamic Data Masking on the
High/Medium sensitivity columns with `UNMASK` granted selectively per the
table above. Validated with three genuinely separate, independently
authenticated SQL logins (not simulated impersonation): Compliance & DPO saw
fully unmasked data; Underwriting saw names/email/phone in the clear but
`date_of_birth`/`postcode` masked; Claims was denied `SELECT` on
`dim_customer` outright. All three matched the intended policy exactly.

---

## Data quality policy

See `data-quality-rules.md` and `data-quality-scorecard.md`. In summary: data
quality is measured across five dimensions (Completeness, Validity, Uniqueness,
Referential Integrity, Consistency), with rule ownership assigned per domain.
Issues are expected to be resolved at the appropriate medallion layer (silver)
where a clear, low-risk fix exists (e.g. deduplication, casing standardisation),
and tracked as known, owned issues where resolution requires a business decision
outside a data pipeline's remit (e.g. what to do about orphaned claims).

---

## Review

This policy should be reviewed whenever the data model changes materially, and at
minimum annually, led by the Compliance & DPO function.
