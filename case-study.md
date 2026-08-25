# Aurora Mutual Insurance — Project Case Study

*A data governance and analytics portfolio project demonstrating Microsoft Fabric
and Microsoft Purview skills for a fictional UK insurer.*

---

## Why I built this

Most data governance portfolios go one of two ways. Either it's pure
documentation — a glossary and some policy PDFs with no actual data behind
them — or it's a tutorial project where you follow someone else's dataset and
someone else's steps. Neither really shows what the job is like. A Data
Governance or Data Quality Analyst spends most of their time judging systems
they didn't build, using tools that don't always cooperate, in organisations
where they don't control every permission. I wanted something closer to that.

So I built a complete insurance data platform from scratch: raw SQL through to
a governed, catalogued, quality-scored Fabric/Purview implementation, with a
Power BI layer reporting on top of it. Independently. Including the bits that
went wrong, which I've left in rather than cleaned up.
---

## How it's structured

Five phases, each with real deliverables you can actually open and check, not
just a description of what I planned to do:

1. **Data design** — a star-schema SQL database for a fictional UK insurer,
   Aurora Mutual. Six data quality issues were planted deliberately from the
   start, so the governance work later would have something real to find
   instead of a suspiciously perfect dataset.
2. **Microsoft Fabric pipeline** — bronze/silver/gold medallion architecture
   pulling from Azure SQL. I made a conscious call about which quality issues
   get fixed in the pipeline and which get left for governance tooling to
   catch; that decision is documented, not accidental.
3. **Microsoft Purview governance** — a live, scanned catalogue; a business
   glossary linked to actual columns; GDPR/UK-DPA classification applied to
   real PII fields; data quality rules that, when run, matched the planted
   issues almost exactly.
4. **Power BI semantic model & dashboards** — a governed model on the gold
   layer, DAX measures that implement the same definitions written into the
   Phase 3 glossary, feeding a three-page executive dashboard.
5. **Governance documentation** — policy, stewardship RACI, a Critical Data
   Elements register, a full data issue lifecycle register, a Governance KPI
   dashboard reporting on both of those, and this write-up.

---

## Architecture, briefly

Azure SQL Database → Fabric Lakehouse bronze (raw copy) → silver (cleaned via
PySpark) → gold (business-ready star schema) → Power BI semantic model →
dashboards. Purview sits alongside this and catalogues the Fabric workspace
directly rather than bolting on at the end. See `er-diagram.png` for the full
schema and `pipeline-documentation.md` for how the pipeline actually works.

---

## Decisions worth explaining

A handful of choices here were deliberate, not defaults. The reasoning behind
them is usually more interesting than the choice itself, so:

**`fact_claims.policy_id` uses `WITH NOCHECK`**, added after the data load
rather than enforced from day one. This let the deliberately-planted orphaned
claims (about 1% of them) load successfully, while still enforcing referential
integrity for anything inserted afterwards. It's a real pattern for handling a
known, tolerated issue instead of either blocking the load outright or letting
bad data through indefinitely.

**The DDL uses the exact property name `MS_Description`** for extended
properties. That's the specific name SQL Server tooling and Purview
recognise as a column description. Anything else would have just sat there
doing nothing, and I wouldn't have found out until the catalogue three phases
later showed no descriptions.

**Silver doesn't fix everything.** Deduplication and casing got cleaned up;
malformed postcodes, missing contact fields, and orphaned claims were left
alone on purpose, so the Purview data quality rules in Phase 3 had something
real left to catch.

**The semantic model only exposes gold tables.** Bronze and silver are
internal staging — nobody building a report should need to know they exist.

**Loss Ratio shows 143.5% and I left it that way.** The DAX is correct. The
actual problem is upstream — Phase 1's claim severity ranges were never
calibrated against premium ranges to produce a realistic book-level ratio.
Fixing the DAX to hide that would've been the easy move. Leaving the real
number visible, with a caveat note on the dashboard itself explaining why,
felt more honest.

**Lineage is reported as two separate numbers, not blended into one.**
Averaging "100% and 0%" into "50%" would misrepresent both facts, so the
Governance KPI dashboard keeps workspace-level and table-level lineage
distinct.

**One proposed KPI ("quality trend by domain") never got built.** It needs
multiple scorecard runs over time and this project only has one snapshot.
Faking a trend from a single data point seemed like exactly the wrong thing
to do on a dashboard whose whole point is credibility.

---

## Where it actually got hard

**Infrastructure friction, Phase 1.** Azure region capacity limits on the
free tier, Azure Data Studio getting retired mid-project (had to switch to
VS Code with the MSSQL extension), and a database-context bug that silently
created tables in `master` instead of the actual database. None of these had
an obvious fix — each one needed independent digging.

**A genuinely long Fabric/Purview permission chain, Phase 3.** Getting
Purview to actually scan table-level metadata from a Fabric Lakehouse took,
in order: finding a tenant permission wall, doing a legitimate Microsoft
Entra domain takeover (DNS verification through the domain registrar) to get
real admin rights, configuring Fabric's Admin API settings, fixing a security
group's membership twice (the first attempt silently added zero members),
turning on a separate OneLake external-access setting, and finally — via
Microsoft's own troubleshooting docs rather than guesswork — discovering the
scanning identity needed Contributor access, not Viewer, at the workspace
level. Every step was a distinct, correctly diagnosed cause. Not one lucky
fix at the end.

**Two real data model bugs, found only because I checked every chart against
a number I already knew.** A bar chart was silently summing ID values
instead of counting rows — obvious once I noticed the axis went up to
300,000 for 800 total claims. More significant: two relationships
(`dim_policy → fact_claims` and `dim_date → fact_claims`) had reversed
cardinality. Power BI treated each dimension as the "many" side and each
fact table as the "one" side, backwards. Both relationships showed "Active,"
which looked fine at a glance. I only found this because every chart got
checked against a figure I already knew from earlier phases, rather than
trusted just because it rendered without an error.

**A Direct Lake limitation, and a delay that was on me.** The semantic
model's storage mode doesn't support calculated columns, which blocked my
first plan for fixing a missing `dim_date`–`dim_policy` relationship — worked
around it by relating the tables directly on their existing date columns
instead. Separately, trying to add three new governance tables to an
already-published Direct Lake model kept failing through the standard "Get
data" workflow. The actual fix, "Edit tables," was sitting right there in the
ribbon the whole time. Should have spotted it sooner.

**Getting RBAC and masking actually validated, not just written.** Five
database roles, table-level grants, and Dynamic Data Masking on the
sensitive PII columns, built against the source Azure SQL Database and then
tested with three genuinely separate SQL logins — not simulated
impersonation, since `EXECUTE AS` turned out not to be reliable enough on
Azure SQL Database to trust. Getting three real logins working surfaced
three more platform rules along the way: `CREATE LOGIN` only works against
`master`, never the user database; it has to be the only statement in its
batch; and Azure's password policy quietly rejects any password that
resembles the username it belongs to. Three separate gotchas, not one
mistake repeated three times. All three logins ended up behaving exactly as
designed — full access, partial masking, outright denial.

---

## What actually got built

Everything from the original five-phase plan, produced and checked, sitting
in this repository:

- Company brief, schema design, ER diagram, DDL, synthetic data generator,
  and a populated Azure SQL database with every planted data quality issue
  confirmed present and measurable
- A working Fabric medallion pipeline, documented including what broke and
  how it got fixed
- A live, scanned Purview catalogue; an 8-term business glossary linked to
  real columns; a GDPR classification policy with labels actually applied to
  PII fields; data quality rules whose results matched the Phase 1 design
  spec almost exactly (39 malformed postcodes, 5 illogical dates, 158 casing
  variants, all exact matches)
- A governed Power BI semantic model with proper relationships, a marked
  date table, and DAX measures matching the Phase 3 glossary, feeding a
  three-page dashboard where every number was checked against something
  already known to be true
- A Critical Data Elements register (9 fields), a formal issue register
  (4 issues, 2 closed with real remediation evidence, 2 open with named
  owners and due dates), a governance coverage facts table, and role-based
  access control with Dynamic Data Masking — validated, not just designed
- This case study, the governance policy, and the stewardship RACI matrix

---

## What's still missing

Worth naming these myself rather than hoping nobody notices:

- **SQL → bronze lineage doesn't render in Purview.** The source Azure SQL
  Database lives in a separate personal Microsoft tenant from the Fabric
  workspace. Doing this properly would mean cross-tenant scanning, which was
  out of scope here.
- **Bronze → silver → gold table lineage doesn't render either.** Those
  transformations run as PySpark notebook code, and Fabric doesn't
  automatically trace that the way it traces native pipeline Copy
  activities. Workspace-level lineage (Lakehouse → SQL endpoint) works fine
  and is confirmed; table-level lineage sits at 0% on the Governance KPI
  dashboard, reported honestly rather than hidden.
- **Renewal Rate has no DAX measure.** It's a glossary term with nothing
  behind it, because the schema was never built with a field linking an
  expiring policy to its renewal. I'd rather leave that visibly missing than
  fake a measure that looks right but isn't actually measuring renewals.
- **The Phase 1 claim severity ranges were never recalibrated** after the
  Loss Ratio issue turned up. Fixing it properly would mean regenerating the
  synthetic data and pushing it back through every phase since. Documented
  instead, visible on the live dashboard via a caveat note.

---

## Reflection

I built the whole pipeline myself, not just the governance layer sitting on
top of it, even though a real Data Governance Analyst role wouldn't normally
involve building the system being governed. My reasoning: it's a lot easier
to judge whether a schema, a pipeline, or a semantic model is trustworthy
once you've actually built and broken one yourself, rather than only ever
having read about what you're supposed to check. The reversed relationship
cardinalities, the missing filter path between dim_date and dim_policy, the
Loss Ratio calibration problem, the notebook lineage gap, the exact match
between the scorecard results and issues planted three phases earlier — all
of that is exactly the kind of thing a governance analyst is meant to catch
in someone else's system. Catching it in my own probably prepared me better
for that job, not worse.

The Phase 5 governance work got the same scrutiny as everything before it.
Several of the Governance KPI dashboard's proposed metrics got checked
against real project data before I built anything, and one metric got
dropped entirely rather than faked from a single data point pretending to be
a trend. Checking whether a number is honestly computable before you build a
dashboard around it is itself a governance skill. Arguably more so than the
dashboard.
