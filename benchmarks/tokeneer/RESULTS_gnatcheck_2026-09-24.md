# Tokeneer: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-09-24 for release 1.5.3. This file replaces the earlier dated runs, which remain in the Git history. The refresh picks up `FP-079` (case expressions in `Identical_Case_Alternative`), `FP-080`-`FP-082` (a resolution failure or a positional call no longer silently drops the other checks' findings at the same node) and two harness corrections: GNATcheck's `Duplicate_Branches` now runs with `min_stmt=1,min_size=1` and is matched on the line it names as the duplicate, and the Ada_Drivers_Library runner no longer splits extra passes at spaces. See `benchmarks/README.md`.

## Environment

- Corpus: pinned at `a97467e91a16409c866434fcc7a5f553bbd98b8a` (`TOKENEER_REVISION`), unchanged.
- AdaLang Analyzer: 1.5.3.
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `TOKENEER_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/tokeneer/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): none on the first attempt, per the standing retry policy for that crash class.

## Totals

| | 2026-09-24 | 2026-09-23 |
| --- | ---: | ---: |
| AdaLang findings | 772 | 769 |
| &nbsp;&nbsp;matched by GNATcheck | 611 (79.1%) | 609 (79.2%) |
| GNATcheck findings | 1851 | 1849 |
| &nbsp;&nbsp;matched by AdaLang | 592 (32.0%) | 590 (31.9%) |

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 1 findings, 1 matched by GNATcheck's `duplicate_branches` (100.0%); `duplicate_branches`: 2 findings, 1 matched (50.0%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Address_Clause | close | 0 | 0 | n/a |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Constant_Condition | close | 0 | 0 | n/a |
| Cyclomatic_Complexity | direct | 3 | 1 | 66.7% |
| Dead_Store | close | 22 | 22 | 0.0% |
| Deep_Nesting | direct | 4 | 4 | 0.0% |
| Dependency_Limit | direct | 0 | 0 | n/a |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 2 | 2 | 0.0% |
| Empty_Elsif_Body | close | 1 | 1 | 0.0% |
| Empty_Exception_Handler | direct | 19 | 0 | 100.0% |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 0 | 0 | n/a |
| Exception_Propagation | close | 2 | 2 | 0.0% |
| Exception_Swallowed | close | 19 | 0 | 100.0% |
| Floating_Equality | direct | 0 | 0 | n/a |
| Identical_Branches | direct | 0 | 0 | n/a |
| Identical_Case_Alternative | close | 1 | 0 | 100.0% |
| Infinite_Loop | close | 0 | 0 | n/a |
| Library_Level_Initialization | close | 1 | 1 | 0.0% |
| Long_Line | direct | 4 | 0 | 100.0% |
| Magic_Number | close | 296 | 60 | 79.7% |
| Missing_Global_Contract | close | 3 | 3 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Naming_Convention | close | 88 | 9 | 89.8% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 0 | 0 | n/a |
| No_Goto | direct | 0 | 0 | n/a |
| No_Multiple_Return | direct | 24 | 24 | 0.0% |
| No_Pragma | close | 87 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| Non_Short_Circuit_Condition | direct | 101 | 11 | 89.1% |
| Null_Case_Alternative | close | 2 | 2 | 0.0% |
| Null_Statement | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 1 | 1 | 0.0% |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 15 | 0 | 100.0% |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 6 | 6 | 0.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Uninitialized_Output | close | 0 | 0 | n/a |
| Unused_Parameter | close | 11 | 2 | 81.8% |
| Unused_Variable | close | 1 | 0 | 100.0% |
| Unused_With_Clause | close | 51 | 2 | 96.1% |
| Wrong_Parameter_Mode | close | 8 | 8 | 0.0% |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 0 | 0 | n/a |
| `address_specifications_for_initialized_objects` | 0 | 0 | n/a |
| `address_specifications_for_local_objects` | 0 | 0 | n/a |
| `at_representation_clauses` | 0 | 0 | n/a |
| `boolean_negations` | 1 | 1 | 0.0% |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `controlled_type_declarations` | 0 | 0 | n/a |
| `duplicate_branches` | 2 | 1 | 50.0% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 0 | 0 | n/a |
| `exception_propagation_from_tasks` | 1 | 1 | 0.0% |
| `float_equality_checks` | 0 | 0 | n/a |
| `forbidden_pragmas` | 91 | 4 | 95.6% |
| `goto_statements` | 0 | 0 | n/a |
| `improper_returns` | 34 | 34 | 0.0% |
| `maximum_parameters` | 61 | 61 | 0.0% |
| `metrics_cyclomatic_complexity` | 45 | 43 | 4.4% |
| `min_identifier_length` | 117 | 38 | 67.5% |
| `non_short_circuit_operators` | 832 | 742 | 10.8% |
| `null_paths` | 6 | 6 | 0.0% |
| `numeric_literals` | 247 | 11 | 95.5% |
| `overly_nested_control_structures` | 8 | 8 | 0.0% |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 0 | 0 | n/a |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 6 | 6 | 0.0% |
| `redundant_null_statements` | 0 | 0 | n/a |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `silent_exception_handlers` | 130 | 111 | 14.6% |
| `simple_loop_statements` | 10 | 10 | 0.0% |
| `spark_procedures_without_globals` | 36 | 36 | 0.0% |
| `style_checks:M` | 4 | 0 | 100.0% |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 0 | 0 | n/a |
| `too_many_dependencies` | 43 | 43 | 0.0% |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 25 | 25 | 0.0% |
| `warnings:c.always` | 8 | 8 | 0.0% |
| `warnings:f` | 9 | 0 | 100.0% |
| `warnings:k.mode` | 0 | 0 | n/a |
| `warnings:m.never` | 0 | 0 | n/a |
| `warnings:m.overwritten` | 0 | 0 | n/a |
| `warnings:r.conversion` | 19 | 4 | 78.9% |
| `warnings:r.self` | 0 | 0 | n/a |
| `warnings:r.with` | 1 | 1 | 0.0% |
| `warnings:u.object` | 63 | 62 | 1.6% |
| `warnings:u.unit` | 52 | 3 | 94.2% |

## Known, explained differences

- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
