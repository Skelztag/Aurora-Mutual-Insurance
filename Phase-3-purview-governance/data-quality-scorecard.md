# Aurora Mutual Insurance — Data Quality Scorecard

**Run date:** 17 August 2026
**Executed against:** Fabric SQL analytics endpoint (AuroraMutualLakehouse)
**Method:** Manual SQL execution of rules defined in `data-quality-rules.md`
(run via `data-quality-checks.sql`)

---

## Results

Targets are set per the Critical Data Elements in `cde-register.md` where a CDE
exists for the field; otherwise a standard default threshold is applied
(≥99% for Validity/Referential Integrity rules, 100% for zero-tolerance
checks like illogical dates). A rule **breaches** when the actual result falls
below its target — breach status is independent of whether the issue is
"known" or planted; a known issue can still be a real, tracked breach.

| # | Dimension | Rule | Layer | Target | Actual | Breach? | CDE | Owner |
|---|---|---|---|---|---|---|---|---|
| 1 | Completeness | Email should not be null | Bronze | ≥98% | 95.57% | ⚠️ Yes | CDE-03 | Compliance & DPO |
| 2 | Completeness | Phone number should not be null | Bronze | ≥98% | 95.03% | ⚠️ Yes | — | Compliance & DPO |
| 3 | Validity | Postcode should match UK format | Bronze | ≥99% | 98.73% | ⚠️ Yes | CDE-01 | Compliance & DPO |
| 4a | Uniqueness | No duplicate customers (DOB + postcode) | Bronze | 100% unique | 98.04% (60 dupes) | ⚠️ Yes | — | Compliance & DPO |
| 4b | Uniqueness | No duplicate customers (DOB + postcode) | **Gold** | 100% unique | **100%** | ✅ No | — | Compliance & DPO |
| 5 | Referential integrity | Every claim must reference a valid policy | Bronze | 100% | 99% (8 orphaned) | ⚠️ Yes | CDE-09 | Claims |
| 6 | Validity | Settled date must not precede incurred date | Bronze | 0 breaches | 5 illogical rows | ⚠️ Yes | — | Claims |
| 7a | Consistency | Customer segment should be standardized | Bronze | 100% | 94.84% | ⚠️ Yes | — | Underwriting |
| 7b | Consistency | Customer segment should be standardized | **Gold** | 100% | **100%** | ✅ No | — | Underwriting |
| 8 | Validity | Claim amount must be positive | Bronze | 100% | 100% | ✅ No | CDE-07 | Claims |

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

**Every breach flagged above that involves a Critical Data Element has a
corresponding entry in `data-issue-register.md`** — Rules 3 and 5 (postcode
validity, referential integrity) map directly to ISSUE-01 and ISSUE-02, both
tracked as open, owned, accepted-risk issues with a named remediation plan.
Rules 4a and 7a's breaches at bronze correspond to ISSUE-03 and ISSUE-04,
both already closed with validated remediation — the scorecard's bronze/gold
comparison *is* the validation evidence cited in those closed issues.

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
