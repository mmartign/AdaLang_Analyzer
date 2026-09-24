# gnatcoll-core: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-09-24 for release 1.5.3. This file replaces the earlier dated runs, which remain in the Git history. The refresh picks up `FP-079` (case expressions in `Identical_Case_Alternative`), `FP-080`-`FP-082` (a resolution failure or a positional call no longer silently drops the other checks' findings at the same node) and two harness corrections: GNATcheck's `Duplicate_Branches` now runs with `min_stmt=1,min_size=1` and is matched on the line it names as the duplicate, and the Ada_Drivers_Library runner no longer splits extra passes at spaces. See `benchmarks/README.md`.

## Environment

- Corpus: pinned at `9f6ffb394793b0ac098fb1e9b206a659680788b3` (`GNATCOLL_REVISION`), unchanged.
- AdaLang Analyzer: 1.5.3.
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `GNATCOLL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/gnatcoll/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): this corpus needed 11 attempts for a crash-free run, per the standing retry policy for that crash class.

## Totals

| | 2026-09-24 | 2026-09-23 |
| --- | ---: | ---: |
| AdaLang findings | 2108 | 2096 |
| &nbsp;&nbsp;matched by GNATcheck | 1269 (60.2%) | 1261 (60.2%) |
| GNATcheck findings | 2943 | 2933 |
| &nbsp;&nbsp;matched by AdaLang | 1267 (43.1%) | 1259 (42.9%) |

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 8 findings, 8 matched by GNATcheck's `duplicate_branches` (100.0%); `duplicate_branches`: 10 findings, 8 matched (80.0%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Address_Clause | close | 6 | 5 | 16.7% |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Constant_Condition | close | 1 | 1 | 0.0% |
| Cyclomatic_Complexity | direct | 69 | 0 | 100.0% |
| Dead_Store | close | 9 | 9 | 0.0% |
| Deep_Nesting | direct | 31 | 31 | 0.0% |
| Dependency_Limit | direct | 0 | 0 | n/a |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 1 | 1 | 0.0% |
| Empty_Elsif_Body | close | 4 | 4 | 0.0% |
| Empty_Exception_Handler | direct | 4 | 0 | 100.0% |
| Empty_If_Body | close | 1 | 1 | 0.0% |
| Empty_Then_Body | close | 10 | 10 | 0.0% |
| Exception_Propagation | close | 2 | 2 | 0.0% |
| Exception_Swallowed | close | 2 | 0 | 100.0% |
| Floating_Equality | direct | 4 | 0 | 100.0% |
| Identical_Branches | direct | 7 | 0 | 100.0% |
| Identical_Case_Alternative | close | 1 | 0 | 100.0% |
| Infinite_Loop | close | 1 | 0 | 100.0% |
| Library_Level_Initialization | close | 0 | 0 | n/a |
| Long_Line | direct | 0 | 0 | n/a |
| Magic_Number | close | 493 | 13 | 97.4% |
| Missing_Global_Contract | close | 121 | 121 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Naming_Convention | close | 630 | 196 | 68.9% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 39 | 0 | 100.0% |
| No_Controlled_Type | direct | 14 | 9 | 35.7% |
| No_Goto | direct | 2 | 0 | 100.0% |
| No_Multiple_Return | direct | 333 | 333 | 0.0% |
| No_Pragma | close | 215 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| Non_Short_Circuit_Condition | direct | 0 | 0 | n/a |
| Null_Case_Alternative | close | 11 | 10 | 9.1% |
| Null_Statement | direct | 1 | 0 | 100.0% |
| Overwritten_Assignment | close | 2 | 2 | 0.0% |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 0 | 0 | n/a |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 23 | 23 | 0.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Uninitialized_Output | close | 49 | 46 | 6.1% |
| Unused_Parameter | close | 13 | 13 | 0.0% |
| Unused_Variable | close | 3 | 3 | 0.0% |
| Unused_With_Clause | close | 2 | 2 | 0.0% |
| Wrong_Parameter_Mode | close | 4 | 4 | 0.0% |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 0 | 0 | n/a |
| `address_specifications_for_initialized_objects` | 0 | 0 | n/a |
| `address_specifications_for_local_objects` | 6 | 5 | 16.7% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `boolean_negations` | 0 | 0 | n/a |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `controlled_type_declarations` | 21 | 16 | 23.8% |
| `duplicate_branches` | 10 | 2 | 80.0% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 4 | 4 | 0.0% |
| `exception_propagation_from_tasks` | 0 | 0 | n/a |
| `float_equality_checks` | 9 | 5 | 44.4% |
| `forbidden_pragmas` | 267 | 52 | 80.5% |
| `goto_statements` | 2 | 0 | 100.0% |
| `improper_returns` | 669 | 669 | 0.0% |
| `maximum_parameters` | 197 | 197 | 0.0% |
| `metrics_cyclomatic_complexity` | 202 | 133 | 34.2% |
| `min_identifier_length` | 654 | 220 | 66.4% |
| `non_short_circuit_operators` | 31 | 31 | 0.0% |
| `null_paths` | 43 | 42 | 2.3% |
| `numeric_literals` | 578 | 98 | 83.0% |
| `overly_nested_control_structures` | 29 | 29 | 0.0% |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 3 | 3 | 0.0% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 6 | 6 | 0.0% |
| `redundant_null_statements` | 1 | 0 | 100.0% |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `silent_exception_handlers` | 64 | 60 | 6.2% |
| `simple_loop_statements` | 42 | 41 | 2.4% |
| `spark_procedures_without_globals` | 0 | 0 | n/a |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 41 | 2 | 95.1% |
| `too_many_dependencies` | 59 | 59 | 0.0% |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 4 | 1 | 75.0% |
| `warnings:c.always` | 0 | 0 | n/a |
| `warnings:f` | 0 | 0 | n/a |
| `warnings:k.mode` | 0 | 0 | n/a |
| `warnings:m.never` | 0 | 0 | n/a |
| `warnings:m.overwritten` | 0 | 0 | n/a |
| `warnings:r.conversion` | 0 | 0 | n/a |
| `warnings:r.self` | 0 | 0 | n/a |
| `warnings:r.with` | 0 | 0 | n/a |
| `warnings:u.object` | 0 | 0 | n/a |
| `warnings:u.unit` | 1 | 1 | 0.0% |

## Known, explained differences

- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
