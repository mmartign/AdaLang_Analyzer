# SPARKNaCl: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-23 as part of a full ten-corpus refresh that extended the
rule map with fourteen more pairs, twelve of them through GNATcheck's
`Warnings` and `Style_Checks` rules (GNAT compiler warnings and style
checks passed through GNATcheck). See `benchmarks/README.md`'s
"Compiler-warning and style-check pairs" section for the method, its
caveats, and the twelve analyzer fixes (`FP-067`-`FP-078`) the new pairs
led to.

## Environment

- Corpus: pinned at `49e3bddf092561ce2b74c134a35acff91a2da9a4` (`SPARKNACL_REVISION`), unchanged.
- AdaLang Analyzer: 1.5.2 plus the `FP-067`-`FP-078` fixes.
- GNATcheck: same from-source build as prior runs. The runner now makes
  one pass with the original `-r` rules, then one pass per column-4
  option line of `benchmarks/gnatcheck_rule_map.tsv`
  (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `SPARKNACL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/sparknacl/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes (`STORAGE_ERROR`, "unparsable worker output"):
  this corpus needed 1 attempt for a crash-free run, per this
  project's standing retry policy for that crash class.

## Totals

| | All mapped rules | Rules mapped before 2026-09-23 |
| --- | ---: | ---: |
| AdaLang findings | 1986 | 1557 |
| &nbsp;&nbsp;matched by GNATcheck | 1752 (88.2%) | 1334 (85.7%) |
| GNATcheck findings | 2196 | 1778 |
| &nbsp;&nbsp;matched by AdaLang | 1752 (79.8%) | 1334 (75.0%) |

The right-hand column re-scores this run with the rule map as it stood
before this refresh, for comparison with `RESULTS_gnatcheck_2026-09-22.md`.
AdaLang's side of it is identical to that run's (1557 findings): none of
this refresh's fixes changed a check that was already paired.
GNATcheck's side is 1778 against 1758 then; every run here was
retried until it contained no worker-crash lines, whereas a crashed
worker silently drops findings, so this crash-free count supersedes
the earlier one.

## New pairs

| AdaLang rule | GNATcheck tag | Match | AdaLang | AdaLang-only | GNATcheck | GNATcheck-only |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| Missing_Overriding_Indicator | `overriding_indicators` | direct | 0 | 0 | 0 | 0 |
| No_Pragma | `forbidden_pragmas` | close | 418 | 0 | 418 | 0 |
| Duplicate_With_Clause | `warnings:r.with` | direct | 0 | 0 | 0 | 0 |
| Long_Line | `style_checks:M` | direct | 0 | 0 | 0 | 0 |
| Trailing_Whitespace | `style_checks:b` | direct | 0 | 0 | 0 | 0 |
| Unused_With_Clause | `warnings:u.unit` | close | 0 | 0 | 0 | 0 |
| Unused_Variable | `warnings:u.object` | close | 0 | 0 | 0 | 0 |
| Unused_Parameter | `warnings:f` | close | 0 | 0 | 0 | 0 |
| Wrong_Parameter_Mode | `warnings:k.mode` | close | 0 | 0 | 0 | 0 |
| Overwritten_Assignment | `warnings:m.overwritten` | close | 0 | 0 | 0 | 0 |
| Dead_Store | `warnings:m.never` | close | 11 | 11 | 0 | 0 |
| Redundant_Type_Conversion | `warnings:r.conversion` | close | 0 | 0 | 0 | 0 |
| Self_Assignment | `warnings:r.self` | close | 0 | 0 | 0 | 0 |
| Constant_Condition | `warnings:c.always` | close | 0 | 0 | 0 | 0 |
