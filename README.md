# Aurora Mutual Insurance

**A fictional UK insurer, built end-to-end to demonstrate Microsoft Fabric and
Microsoft Purview data governance skills.**

📄 [Read the full case study](./case-study.md) — what got built, what went
wrong along the way, and what it taught me.

---

## What this is

A full data governance and analytics build, from raw SQL through to a
governed, catalogued, quality-scored Microsoft Fabric/Purview platform, with
a governed Power BI semantic model reporting on top of it. Not a tutorial
I followed, every deliverable here was designed, built, tested, and in
several places debugged against real platform behaviour, documented as it
actually happened rather than cleaned up afterward.

## A few things worth knowing before you dig in

- **Six data quality issues were planted on purpose**, and Purview's data
  quality rules caught them with results matching the design almost exactly
  (39 malformed postcodes, 5 illogical dates, 158 casing variants, all exact
  matches)
- **Getting Purview to scan the Fabric Lakehouse properly took a genuine
  multi-hour permission chain** — tenant admin roles, a legitimate Microsoft
  Entra domain takeover, security group scoping, and a workspace-role fix
  found through Microsoft's own docs rather than trial and error. [Full story
  here](./case-study.md#where-it-actually-got-hard)
- **Two relationship bugs in the Power BI model got found by checking every
  chart against a number I already knew**, not by assuming a chart that
  rendered without error was correct — including one bug that silently made
  two dimension tables filter backwards
- **The governance documentation phase includes a Critical Data Elements
  register, a data issue lifecycle register, and a Governance KPI dashboard**
  built on real, queryable Fabric tables. Every proposed metric got checked
  for whether it was honestly computable before it got built, and one
  ("quality trend by domain") got dropped rather than faked from one data
  point
- **RBAC and Dynamic Data Masking are implemented and validated** with three
  genuinely separate, independently authenticated SQL logins, not simulated
  impersonation — full access, partial masking, and outright denial, each
  working exactly as designed
- **The limitations are documented on purpose.** A 143% Loss Ratio, a couple
  of lineage gaps, a missing DAX measure — named clearly rather than hidden

## Architecture

Azure SQL Database → Fabric Lakehouse (bronze → silver → gold) → Power BI
semantic model → Purview governance layer (catalogue, glossary,
classification, data quality, CDE and issue registers).

![ER Diagram](./phase-1-data-design/er-diagram.png)

## What's in each folder

| Folder | What's there |
|---|---|
| `phase-0-company-brief/` | The fictional company profile, org chart, ownership model |
| `phase-1-data-design/` | Schema design, ER diagram, DDL, the synthetic data generator, full sample data |
| `phase-2-fabric-pipeline/` | The medallion pipeline, documented including what broke |
| `phase-3-purview-governance/` | Business glossary, GDPR classification, data quality rules and scorecard |
| `phase-4-power-bi/` | The governed semantic model docs, DAX measures |
| `phase-5-governance-docs/` | Governance policy, RACI matrix, CDE register, issue register, coverage facts, RBAC/masking implementation |
| `case-study.md` | The full write-up |

## Stack

Azure SQL Database · Microsoft Fabric (Lakehouse, Data Factory pipelines,
PySpark notebooks) · Microsoft Purview (Unified Catalog, Data Map, Data
Quality) · Power BI (governed semantic model, DAX) · Python (Faker, pandas) ·
T-SQL

## About

Built by Skelly Tagbajumi as a portfolio project targeting Data Management Analyst | Data Governance Analyst | Data Quality Analyst | Data Management Specialist | Metadata Analyst

