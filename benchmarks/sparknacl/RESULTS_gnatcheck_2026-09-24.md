# SPARKNaCl: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-09-24 for release 1.5.3. This file replaces the earlier dated runs, which remain in the Git history. The refresh picks up `FP-079` (case expressions in `Identical_Case_Alternative`), `FP-080`-`FP-082` (a resolution failure or a positional call no longer silently drops the other checks' findings at the same node) and two harness corrections: GNATcheck's `Duplicate_Branches` now runs with `min_stmt=1,min_size=1` and is matched on the line it names as the duplicate, and the Ada_Drivers_Library runner no longer splits extra passes at spaces. See `benchmarks/README.md`.

## Environment

- Corpus: pinned at `49e3bddf092561ce2b74c134a35acff91a2da9a4` (`SPARKNACL_REVISION`), unchanged.
- AdaLang Analyzer: 1.5.3.
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `SPARKNACL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/sparknacl/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): this corpus needed 2 attempts for a crash-free run, per the standing retry policy for that crash class.

## Totals

| | 2026-09-24 | 2026-09-23 |
| --- | ---: | ---: |
| AdaLang findings | 1986 | 1986 |
| &nbsp;&nbsp;matched by GNATcheck | 1752 (88.2%) | 1752 (88.2%) |
| GNATcheck findings | 2196 | 2196 |
| &nbsp;&nbsp;matched by AdaLang | 1752 (79.8%) | 1752 (79.8%) |

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 0 findings, 0 matched by GNATcheck's `duplicate_branches` (n/a); `duplicate_branches`: 0 findings, 0 matched (n/a). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Address_Clause | close | 0 | 0 | n/a |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Constant_Condition | close | 0 | 0 | n/a |
| Cyclomatic_Complexity | direct | 3 | 2 | 33.3% |
| Dead_Store | close | 11 | 11 | 0.0% |
| Deep_Nesting | direct | 0 | 0 | n/a |
| Dependency_Limit | direct | 0 | 0 | n/a |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 0 | 0 | n/a |
| Empty_Elsif_Body | close | 0 | 0 | n/a |
| Empty_Exception_Handler | direct | 0 | 0 | n/a |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 0 | 0 | n/a |
| Exception_Propagation | close | 0 | 0 | n/a |
| Exception_Swallowed | close | 0 | 0 | n/a |
| Floating_Equality | direct | 0 | 0 | n/a |
| Identical_Branches | direct | 0 | 0 | n/a |
| Identical_Case_Alternative | close | 0 | 0 | n/a |
| Infinite_Loop | close | 0 | 0 | n/a |
| Library_Level_Initialization | close | 0 | 0 | n/a |
| Long_Line | direct | 0 | 0 | n/a |
| Magic_Number | close | 945 | 88 | 90.7% |
| Missing_Global_Contract | close | 3 | 3 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Naming_Convention | close | 595 | 120 | 79.8% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 0 | 0 | n/a |
| No_Controlled_Type | direct | 0 | 0 | n/a |
| No_Goto | direct | 0 | 0 | n/a |
| No_Multiple_Return | direct | 2 | 2 | 0.0% |
| No_Pragma | close | 418 | 0 | 100.0% |
| No_Recursion | direct | 0 | 0 | n/a |
| Non_Short_Circuit_Condition | direct | 1 | 0 | 100.0% |
| Null_Case_Alternative | close | 0 | 0 | n/a |
| Null_Statement | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 0 | 0 | n/a |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 0 | 0 | n/a |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 1 | 1 | 0.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Uninitialized_Output | close | 7 | 7 | 0.0% |
| Unused_Parameter | close | 0 | 0 | n/a |
| Unused_Variable | close | 0 | 0 | n/a |
| Unused_With_Clause | close | 0 | 0 | n/a |
| Wrong_Parameter_Mode | close | 0 | 0 | n/a |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 0 | 0 | n/a |
| `address_specifications_for_initialized_objects` | 0 | 0 | n/a |
| `address_specifications_for_local_objects` | 0 | 0 | n/a |
| `at_representation_clauses` | 0 | 0 | n/a |
| `boolean_negations` | 0 | 0 | n/a |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `controlled_type_declarations` | 0 | 0 | n/a |
| `duplicate_branches` | 0 | 0 | n/a |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 0 | 0 | n/a |
| `exception_propagation_from_tasks` | 0 | 0 | n/a |
| `float_equality_checks` | 0 | 0 | n/a |
| `forbidden_pragmas` | 418 | 0 | 100.0% |
| `goto_statements` | 0 | 0 | n/a |
| `improper_returns` | 6 | 6 | 0.0% |
| `maximum_parameters` | 27 | 27 | 0.0% |
| `metrics_cyclomatic_complexity` | 9 | 8 | 11.1% |
| `min_identifier_length` | 680 | 205 | 69.9% |
| `non_short_circuit_operators` | 191 | 190 | 0.5% |
| `null_paths` | 0 | 0 | n/a |
| `numeric_literals` | 857 | 0 | 100.0% |
| `overly_nested_control_structures` | 0 | 0 | n/a |
| `overriding_indicators` | 0 | 0 | n/a |
| `parameters_aliasing` | 0 | 0 | n/a |
| `potential_parameters_aliasing` | 0 | 0 | n/a |
| `recursive_subprograms` | 0 | 0 | n/a |
| `redundant_boolean_expressions` | 0 | 0 | n/a |
| `redundant_null_statements` | 0 | 0 | n/a |
| `same_operands` | 0 | 0 | n/a |
| `same_tests` | 0 | 0 | n/a |
| `silent_exception_handlers` | 0 | 0 | n/a |
| `simple_loop_statements` | 3 | 3 | 0.0% |
| `spark_procedures_without_globals` | 5 | 5 | 0.0% |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 0 | 0 | n/a |
| `too_many_dependencies` | 0 | 0 | n/a |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 0 | 0 | n/a |
| `warnings:c.always` | 0 | 0 | n/a |
| `warnings:f` | 0 | 0 | n/a |
| `warnings:k.mode` | 0 | 0 | n/a |
| `warnings:m.never` | 0 | 0 | n/a |
| `warnings:m.overwritten` | 0 | 0 | n/a |
| `warnings:r.conversion` | 0 | 0 | n/a |
| `warnings:r.self` | 0 | 0 | n/a |
| `warnings:r.with` | 0 | 0 | n/a |
| `warnings:u.object` | 0 | 0 | n/a |
| `warnings:u.unit` | 0 | 0 | n/a |

## Known, explained differences

- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
