# Aurora Mutual Insurance

**A fictional UK insurer, built end-to-end to demonstrate Microsoft Fabric and
Microsoft Purview data governance skills.**

📄 [Read the full case study](./case-study.md) — the real story: what was built,
what went wrong, and what it revealed.

---

## What this is

A complete data governance and analytics implementation, built independently
from raw SQL through to a governed, catalogued, quality-scored Microsoft
Fabric/Purview platform. Not a tutorial follow-along — every deliverable below
was designed, built, tested, and in several cases debugged against real
platform behaviour, documented as it actually happened.

## Highlights

- **Six deliberately-planted data quality issues**, detected by Purview's data
  quality rules with results matching the design specification exactly (39
  malformed postcodes, 5 illogical dates, 158 casing variants — all exact
  matches)
- **A genuine multi-hour Fabric/Purview permission diagnosis** — tenant admin
  roles, a legitimate Microsoft Entra domain takeover, security group scoping,
  and a workspace-role fix found through Microsoft's own troubleshooting docs
  rather than guesswork — [full story in the case study](./case-study.md#challenges-and-what-they-revealed)
- **A business glossary linked to live, scanned data columns** in Purview's
  Unified Catalog, not just a static document
- **Honest, documented limitations** — lineage gaps, scope decisions, and a
  real Phase 1 data-calibration issue, named explicitly rather than hidden

## Architecture

Azure SQL Database → Fabric Lakehouse (bronze → silver → gold medallion
architecture) → Purview governance layer (catalogue, glossary, classification,
data quality).

![ER Diagram](./Phase-1-data-design/er-diagram.png)

## Repository structure

| Folder | Contents |
|---|---|
| `Phase-0-company-brief/` | Fictional company profile, org chart, ownership model |
| `Phase-1-data-design/` | Schema design, ER diagram, DDL, synthetic data generator |
| `Phase-2-fabric-pipeline/` | Medallion architecture pipeline, documented including issues resolved |
| `Phase-3-purview-governance/` | Business glossary, GDPR classification, data quality rules & scorecard |
| `Phase-4-governance-docs/` | Governance policy, stewardship RACI matrix |
| `case-study.md` | Full narrative write-up |

## Stack

Azure SQL Database · Microsoft Fabric (Lakehouse, Data Factory pipelines,
PySpark notebooks) · Microsoft Purview (Unified Catalog, Data Map, Data
Quality) · Python (Faker, pandas) · T-SQL

## About

Built by Skelly Tagbajumi as a portfolio project targeting Data Governance Analyst /
Data Quality Analyst / Metadata Analyst roles.

