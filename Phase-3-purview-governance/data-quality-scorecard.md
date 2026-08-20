# Aurora Mutual Insurance — Data Quality Scorecard

**Run date:** 17 August 2026
**Executed against:** Fabric SQL analytics endpoint (AuroraMutualLakehouse)
**Method:** Manual SQL execution of rules defined in `data-quality-rules.md`
(run via `data-quality-checks.sql`)

---

## Results

| # | Dimension | Rule | Layer | Result | Status |
|---|---|---|---|---|---|
| 1 | Completeness | Email should not be null | Bronze | 95.57% pass | ✅ Known issue — matches ~5% planted missing rate |
| 2 | Completeness | Phone number should not be null | Bronze | 95.03% pass | ✅ Known issue — matches ~5% planted missing rate |
| 3 | Validity | Postcode should match UK format | Bronze | 39 failures (98.73% pass) | ✅ Known issue — exact match to independently verified generator output |
| 4a | Uniqueness | No duplicate customers (DOB + postcode) | Bronze | 60 duplicate rows (1.96%) | ✅ Known issue — matches planted ~2% duplicate rate |
| 4b | Uniqueness | No duplicate customers (DOB + postcode) | **Gold** | **0 duplicates** | ✅ **Resolved** — Phase 2 silver dedup confirmed working end-to-end |
| 5 | Referential integrity | Every claim must reference a valid policy | Bronze | 99% pass (8 orphaned) | ✅ Known issue — matches planted ~1% orphan rate exactly |
| 6 | Validity | Settled date must not precede incurred date | Bronze | 5 illogical rows | ✅ Known issue — exact match to planted count |
| 7a | Consistency | Customer segment should be standardized | Bronze | 158 failures (94.84% pass) | ✅ Known issue — exact match to generator's casing-variant count |
| 7b | Consistency | Customer segment should be standardized | **Gold** | **0 failures (100% pass)** | ✅ **Resolved** — Phase 2 `initcap()` standardization confirmed working |
| 8 | Validity | Claim amount must be positive | Bronze | 0 failures (100% pass) | ✅ Pass — baseline sanity check, not a planted issue |

---

## Interpretation

**Every result matches the Phase 1 design specification precisely** — not
approximately, but exact row-count matches in several cases (39 malformed
postcodes, 5 illogical dates, 158 casing variants). This confirms two things
simultaneously: the synthetic data generator produced exactly the flaws it was
designed to produce, and these SQL-based rules correctly detect them.

**Rules 4 and 7 demonstrate the medallion architecture's actual value**, not
just its existence: the same rule, run against bronze vs. gold, shows a
measurable before/after improvement (duplicates 1.96% → 0%; segment consistency
94.84% → 100%). This is the single clearest piece of evidence in the whole
project that the bronze → silver → gold pipeline does real, verifiable work,
not just relabeling.

**Rules 1, 2, 3, 5, 6, and 8 are deliberately left unresolved through to gold**,
per the Phase 2 design decision — these represent the category of data quality
issue a governance analyst would be expected to *detect and report*, not
silently fix in a pipeline. In a real organisation, these would typically
become tracked remediation items owned by the relevant data steward (see
`data-quality-rules.md` for ownership mapping), rather than being corrected
automatically without a business decision about acceptable thresholds.

## Known limitations of this run

- Executed manually via SQL rather than through Purview's Data Quality feature
  (see `pipeline-documentation.md` for the reasoning — avoiding a further
  permission-configuration cycle after an already extensive Fabric/Purview
  integration effort). The rule *definitions* are tool-agnostic and could be
  re-implemented in Purview's Data Quality UI directly against the now-scanned
  Fabric tables in a follow-up iteration.
- Rule 6 reports an absolute count rather than a percentage, since the query
  as run did not separately capture the total settled-claims denominator.
