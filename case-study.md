# Aurora Mutual Insurance — Project Case Study

*A data governance and analytics portfolio project demonstrating Microsoft Fabric
and Microsoft Purview skills for a fictional UK insurer.*

---

## The problem

Most data governance portfolios are built one of two ways: either as a pure
documentation exercise (glossaries and policies with no real data behind them),
or as a guided tutorial project (following someone else's dataset and someone
else's steps). Neither demonstrates what a Data Governance/Quality Analyst
actually needs to do in practice — which is judge the trustworthiness of systems
they didn't build, using tools that don't always cooperate, in organisations
where they don't control every permission.

This project set out to build something closer to that reality: a complete,
end-to-end insurance data platform — from raw SQL through a governed, catalogued,
quality-scored Fabric/Purview implementation — built independently from scratch,
including the parts that went wrong.

---

## Approach

The build followed four phases, each producing real, verifiable deliverables
rather than descriptions of intended work:

1. **Data design** — a star-schema SQL database for a fictional UK insurer
   (Aurora Mutual), with six deliberately-planted data quality issues designed
   in from the start, so later governance work would have something genuine to
   detect rather than a suspiciously perfect dataset.
2. **Microsoft Fabric pipeline** — a bronze/silver/gold medallion architecture,
   ingesting from Azure SQL, with a documented, deliberate decision about which
   data quality issues get resolved in the pipeline versus left for governance
   tooling to catch.
3. **Microsoft Purview governance** — a live, scanned data catalogue; a business
   glossary linked to real columns; GDPR/UK-DPA classification applied to actual
   PII fields; and data quality rules run against real data with results that
   matched the planted issues precisely.
4. **Governance documentation** — the policy, stewardship, and case study work
   tying all of the above into a coherent framework.

---

## Architecture

*(See `er-diagram.png` for the full schema, `pipeline-documentation.md` for the
Fabric pipeline design, and the Purview lineage screenshots for the catalogued
data flow.)*

At a glance: Azure SQL Database (source) → Fabric Lakehouse bronze layer (raw
copy) → silver layer (PySpark-cleaned) → gold layer (business-ready, star
schema). Governance sits alongside this pipeline rather than at the end of it:
Purview catalogues the Fabric workspace directly, and classification/glossary
work was built against the same live tables the pipeline produces.

---

## Key decisions

A few choices in this project were deliberate engineering/governance judgment
calls, not defaults — worth calling out explicitly, since the reasoning behind
a decision is usually more interesting than the decision itself:

- **The `fact_claims.policy_id` foreign key was added `WITH NOCHECK`, after data
  load, rather than enforced from the start.** This let the deliberately-planted
  ~1% orphaned claims load successfully while still enforcing referential
  integrity for all future inserts — a genuine pattern for handling "known,
  tolerated" data issues rather than either blocking the load or silently
  allowing bad data indefinitely.
- **Extended properties in the DDL used the exact property name `MS_Description`**,
  specifically because that's the name SQL Server tooling and Purview scans
  recognise as a column description. A generic property name would have sat in
  the database inertly, never surfacing in the catalogue three phases later.
- **The silver layer deliberately does not fix every data quality issue.**
  Deduplication and casing standardisation were resolved in the pipeline;
  malformed postcodes, missing contact fields, and orphaned claims were left
  untouched specifically so Purview's data quality rules would have something
  real to detect, rather than measuring an artificially clean dataset.

---

## Challenges, and what they revealed

This project hit real, substantial technical obstacles — documented honestly
here because working through them demonstrated more practical skill than a
frictionless build would have:

**Infrastructure friction (Phase 1).** Azure region capacity restrictions on a
free-tier subscription, the retirement of Azure Data Studio mid-project (pivoted
to VS Code + the MSSQL extension), and a database-context bug that silently
created tables in `master` instead of the intended database — each required
independent diagnosis rather than following a script.

**A genuine multi-hour Fabric/Purview permission chain (Phase 3).** Getting
Purview to successfully scan table-level metadata from a Fabric Lakehouse
required, in order: recognising a tenant permission wall, performing a legitimate
Microsoft Entra domain takeover (via DNS verification through the organisation's
domain registrar) to obtain genuine admin rights, configuring Fabric's Admin API
settings, correctly scoping a security group's membership (twice — the first
attempt silently added zero members), enabling a separate OneLake external-access
tenant setting, and finally discovering — through Microsoft's own troubleshooting
documentation rather than trial and error — that the scanning identity needed
**Contributor**, not Viewer, access at the workspace level. Every one of these
was a distinct, correctly-diagnosed root cause, not a single lucky fix.

---

## Outcomes

Every deliverable from the original project plan for these four phases was
produced, verified, and is included in this repository:

- Company brief, schema design, ER diagram, DDL scripts, synthetic data
  generator, and a populated Azure SQL database with all planted data quality
  issues confirmed present and measurable
- A working Fabric medallion pipeline (bronze/silver/gold), fully documented
  including the issues encountered and resolved
- A live, scanned Purview data catalogue; an 8-term business glossary linked to
  real columns; a GDPR classification policy with labels applied to real PII
  fields; data quality rules that, when run, matched the Phase 1 design
  specification with exact precision on several measures (39 malformed
  postcodes, 5 illogical dates, 158 casing variants — all matched exactly)
- This governance policy, stewardship RACI matrix, and case study

---

## Honest limitations

A credible governance project names its own gaps rather than letting someone
else find them first:

- **SQL → bronze lineage is not rendered in Purview**, because the source Azure
  SQL Database lives in a separate personal Microsoft tenant from the Fabric
  workspace, which would require a cross-tenant scanning setup out of scope for
  this build.
- **Bronze → silver → gold table-level lineage is not rendered**, because those
  transformations run as PySpark notebook code, which Fabric does not
  automatically trace the way it does native pipeline Copy activities.
  Workspace-level lineage (Lakehouse → SQL analytics endpoint) is confirmed
  working; table-level lineage would require additional notebook instrumentation
  not implemented here.
- **Access enforcement (RBAC, dynamic data masking) was scoped out.**
  Classification — identifying what data needs protection — was fully
  implemented and verified. The subsequent step of actually restricting access
  based on that classification was considered and deliberately not carried
  through, in favour of finishing the full project scope rather than
  open-endedly extending any single phase.

---

## Reflection

Building the entire pipeline — not just the governance layer on top of it — was
a deliberate choice, even though a real Data Governance Analyst role would not
typically involve building the source system being governed. The reasoning: it
is much easier to correctly judge the trustworthiness of a schema, a pipeline,
or a lineage gap having personally built and debugged one, than to have only
ever read about what governance analysts are supposed to check. Several of the
findings in this project — the OneLake permission requirements for Fabric
scanning, the notebook lineage limitation, and the exact match between the
data quality scorecard's results and the issues planted three phases earlier —
are exactly the kind of thing a governance analyst is meant to catch and verify
in someone else's system. Having caught and verified them in my own is, if
anything, better preparation for that role, not a substitute for it.
