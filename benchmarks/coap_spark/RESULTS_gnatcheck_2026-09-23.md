# coap_spark: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Re-run 2026-09-23 as part of a full ten-corpus refresh that extended the
rule map with fourteen more pairs, twelve of them through GNATcheck's
`Warnings` and `Style_Checks` rules (GNAT compiler warnings and style
checks passed through GNATcheck). See `benchmarks/README.md`'s
"Compiler-warning and style-check pairs" section for the method, its
caveats, and the twelve analyzer fixes (`FP-067`-`FP-078`) the new pairs
led to.

## Environment

- Corpus: pinned at `2fa345b8c70d621287b932aee7ea39b3520a5adf` (`COAP_SPARK_REVISION`), unchanged.
- AdaLang Analyzer: 1.5.2 plus the `FP-067`-`FP-078` fixes.
- GNATcheck: same from-source build as prior runs. The runner now makes
  one pass with the original `-r` rules, then one pass per column-4
  option line of `benchmarks/gnatcheck_rule_map.tsv`
  (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `COAP_SPARK_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/coap_spark/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes (`STORAGE_ERROR`, "unparsable worker output"):
  this corpus needed 3 attempts for a crash-free run, per this
  project's standing retry policy for that crash class.

## Totals

| | All mapped rules | Rules mapped before 2026-09-23 |
| --- | ---: | ---: |
| AdaLang findings | 3044 | 776 |
| &nbsp;&nbsp;matched by GNATcheck | 2090 (68.7%) | 641 (82.6%) |
| GNATcheck findings | 10076 | 7629 |
| &nbsp;&nbsp;matched by AdaLang | 2090 (20.7%) | 641 (8.4%) |

The right-hand column re-scores this run with the rule map as it stood
before this refresh, for comparison with `RESULTS_gnatcheck_2026-09-22.md`.
AdaLang's side of it is identical to that run's (776 findings): none of
this refresh's fixes changed a check that was already paired.
GNATcheck's side is 7629 against 6545 then; every run here was
retried until it contained no worker-crash lines, whereas a crashed
worker silently drops findings, so this crash-free count supersedes
the earlier one.

## New pairs

| AdaLang rule | GNATcheck tag | Match | AdaLang | AdaLang-only | GNATcheck | GNATcheck-only |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| Missing_Overriding_Indicator | `overriding_indicators` | direct | 0 | 0 | 0 | 0 |
| No_Pragma | `forbidden_pragmas` | close | 1449 | 0 | 2439 | 990 |
| Duplicate_With_Clause | `warnings:r.with` | direct | 0 | 0 | 0 | 0 |
| Long_Line | `style_checks:M` | direct | 801 | 801 | 0 | 0 |
| Trailing_Whitespace | `style_checks:b` | direct | 0 | 0 | 5 | 5 |
| Unused_With_Clause | `warnings:u.unit` | close | 1 | 1 | 2 | 2 |
| Unused_Variable | `warnings:u.object` | close | 0 | 0 | 1 | 1 |
| Unused_Parameter | `warnings:f` | close | 3 | 3 | 0 | 0 |
| Wrong_Parameter_Mode | `warnings:k.mode` | close | 4 | 4 | 0 | 0 |
| Overwritten_Assignment | `warnings:m.overwritten` | close | 0 | 0 | 0 | 0 |
| Dead_Store | `warnings:m.never` | close | 0 | 0 | 0 | 0 |
| Redundant_Type_Conversion | `warnings:r.conversion` | close | 9 | 9 | 0 | 0 |
| Self_Assignment | `warnings:r.self` | close | 0 | 0 | 0 | 0 |
| Constant_Condition | `warnings:c.always` | close | 1 | 1 | 0 | 0 |
