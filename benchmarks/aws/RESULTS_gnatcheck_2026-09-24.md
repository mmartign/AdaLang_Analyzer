# AWS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-09-24 for release 1.5.3. This file replaces the earlier dated runs, which remain in the Git history. The refresh picks up `FP-079` (case expressions in `Identical_Case_Alternative`), `FP-080`-`FP-082` (a resolution failure or a positional call no longer silently drops the other checks' findings at the same node) and two harness corrections: GNATcheck's `Duplicate_Branches` now runs with `min_stmt=1,min_size=1` and is matched on the line it names as the duplicate, and the Ada_Drivers_Library runner no longer splits extra passes at spaces. See `benchmarks/README.md`.

## Environment

- Corpus: pinned at `02cbd01c2f96c288440415a46bf865616c0ee0f8` (`AWS_REVISION`), unchanged.
- AdaLang Analyzer: 1.5.3.
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `AWS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/aws/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): none on the first attempt, per the standing retry policy for that crash class.

## Totals

| | 2026-09-24 | 2026-09-23 |
| --- | ---: | ---: |
| AdaLang findings | 6701 | 6697 |
| &nbsp;&nbsp;matched by GNATcheck | 3635 (54.2%) | 3625 (54.1%) |
| GNATcheck findings | 12991 | 12946 |
| &nbsp;&nbsp;matched by AdaLang | 3625 (27.9%) | 3615 (27.9%) |

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 14 findings, 10 matched by GNATcheck's `duplicate_branches` (71.4%); `duplicate_branches`: 45 findings, 10 matched (22.2%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Address_Clause | close | 21 | 6 | 71.4% |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Constant_Condition | close | 3 | 3 | 0.0% |
| Cyclomatic_Complexity | direct | 88 | 0 | 100.0% |
| Dead_Store | close | 42 | 42 | 0.0% |
| Deep_Nesting | direct | 49 | 49 | 0.0% |
| Dependency_Limit | direct | 4 | 4 | 0.0% |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 2 | 2 | 0.0% |
| Empty_Elsif_Body | close | 2 | 2 | 0.0% |
| Empty_Exception_Handler | direct | 21 | 0 | 100.0% |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 7 | 7 | 0.0% |
| Exception_Propagation | close | 948 | 948 | 0.0% |
| Exception_Swallowed | close | 11 | 0 | 100.0% |
| Floating_Equality | direct | 10 | 5 | 50.0% |
| Identical_Branches | direct | 6 | 1 | 83.3% |
| Identical_Case_Alternative | close | 8 | 3 | 62.5% |
| Infinite_Loop | close | 5 | 0 | 100.0% |
| Library_Level_Initialization | close | 33 | 33 | 0.0% |
| Long_Line | direct | 0 | 0 | n/a |
| Magic_Number | close | 680 | 75 | 89.0% |
| Missing_Global_Contract | close | 827 | 827 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Naming_Convention | close | 2809 | 370 | 86.8% |
| No_Abort | direct | 1 | 0 | 100.0% |
| No_Access_To_Subp_Def | direct | 112 | 0 | 100.0% |
| No_Controlled_Type | direct | 20 | 5 | 75.0% |
| No_Goto | direct | 0 | 0 | n/a |
| No_Multiple_Return | direct | 423 | 423 | 0.0% |
| No_Pragma | close | 290 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| Non_Short_Circuit_Condition | direct | 6 | 0 | 100.0% |
| Null_Case_Alternative | close | 31 | 26 | 16.1% |
| Null_Statement | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 6 | 6 | 0.0% |
| Redundant_Boolean_Comparison | close | 3 | 0 | 100.0% |
| Redundant_Type_Conversion | close | 2 | 2 | 0.0% |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 62 | 62 | 0.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Uninitialized_Output | close | 70 | 66 | 5.7% |
| Unused_Parameter | close | 61 | 61 | 0.0% |
| Unused_Variable | close | 9 | 9 | 0.0% |
| Unused_With_Clause | close | 5 | 5 | 0.0% |
| Wrong_Parameter_Mode | close | 24 | 24 | 0.0% |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 1 | 0 | 100.0% |
| `address_specifications_for_initialized_objects` | 1 | 0 | 100.0% |
| `address_specifications_for_local_objects` | 27 | 12 | 55.6% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `boolean_negations` | 1 | 1 | 0.0% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `controlled_type_declarations` | 170 | 155 | 8.8% |
| `duplicate_branches` | 45 | 35 | 22.2% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 4 | 4 | 0.0% |
| `exception_propagation_from_tasks` | 5 | 5 | 0.0% |
| `float_equality_checks` | 17 | 12 | 29.4% |
| `forbidden_pragmas` | 1328 | 1038 | 21.8% |
| `goto_statements` | 2 | 2 | 0.0% |
| `improper_returns` | 2840 | 2840 | 0.0% |
| `maximum_parameters` | 689 | 689 | 0.0% |
| `metrics_cyclomatic_complexity` | 687 | 599 | 12.8% |
| `min_identifier_length` | 3722 | 1283 | 65.5% |
| `non_short_circuit_operators` | 79 | 73 | 7.6% |
| `null_paths` | 163 | 158 | 3.1% |
| `numeric_literals` | 2243 | 1638 | 27.0% |
| `overly_nested_control_structures` | 119 | 119 | 0.0% |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 11 | 11 | 0.0% |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 13 | 10 | 23.1% |
| `redundant_null_statements` | 4 | 4 | 0.0% |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `silent_exception_handlers` | 239 | 218 | 8.8% |
| `simple_loop_statements` | 204 | 199 | 2.5% |
| `spark_procedures_without_globals` | 0 | 0 | n/a |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 169 | 57 | 66.3% |
| `too_many_dependencies` | 191 | 191 | 0.0% |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 16 | 12 | 25.0% |
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

- GNATcheck analyzes the whole project closure, so findings in dependency sources (`gnatcoll-*`, `sax-*`, `schema-*`, `dom-*`, `unicode-*`) that AdaLang does not analyze in this benchmark's scope count as GNATcheck-only.
- `Deep_Nesting` vs. `overly_nested_control_structures`: GNATcheck reports every over-nested construct at its own line with threshold 3; AdaLang reports one finding per subprogram at its name with threshold 4, so exact lines essentially never coincide (not a defect).
- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
