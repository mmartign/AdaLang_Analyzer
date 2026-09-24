# Ada_Drivers_Library: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Current results, refreshed 2026-09-24 for release 1.5.3. This file replaces the earlier dated runs, which remain in the Git history. The refresh picks up `FP-079` (case expressions in `Identical_Case_Alternative`), `FP-080`-`FP-082` (a resolution failure or a positional call no longer silently drops the other checks' findings at the same node) and two harness corrections: GNATcheck's `Duplicate_Branches` now runs with `min_stmt=1,min_size=1` and is matched on the line it names as the duplicate, and the Ada_Drivers_Library runner no longer splits extra passes at spaces. See `benchmarks/README.md`.

## Environment

- Corpus: pinned at `81c04806d267fc12116a6f746c8e05012cef0484` (`ADL_REVISION`), unchanged.
- AdaLang Analyzer: 1.5.3.
- GNATcheck: the same from-source build as prior runs; one pass with the plain `-r` rules, then one pass per column-4 option line of `benchmarks/gnatcheck_rule_map.tsv` (`benchmarks/gnatcheck_rule_args.awk`).
- Reproduce: `ADL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/ada_drivers_library/run_gnatcheck.sh` (see this directory's README for
  any setup step).
- GNATcheck worker crashes ("unparsable worker output"): no crash-free run in 6 attempts; attempt 1 is used (5 crash lines, the most GNATcheck findings of any attempt). AdaLang's side was identical in every attempt; GNATcheck-side counts may be slightly low.

## Totals

| | 2026-09-24 | 2026-09-23 |
| --- | ---: | ---: |
| AdaLang findings | 860 | 860 |
| &nbsp;&nbsp;matched by GNATcheck | 425 (49.4%) | 378 (44.0%) |
| GNATcheck findings | 1136 | 1087 |
| &nbsp;&nbsp;matched by AdaLang | 425 (37.4%) | 378 (34.8%) |

## Duplicate branches

`Identical_Branches` + `Identical_Case_Alternative`: 4 findings, 4 matched by GNATcheck's `duplicate_branches` (100.0%); `duplicate_branches`: 6 findings, 4 matched (66.7%). With GNATcheck's default thresholds (4 statements / 14 tokens) this pair had 0 GNATcheck findings on every corpus.

## Per AdaLang rule

| AdaLang rule | Match | Findings | AdaLang-only | Matched |
| --- | --- | ---: | ---: | ---: |
| Address_Clause | close | 10 | 8 | 20.0% |
| Aliasing_Between_Parameters | direct | 0 | 0 | n/a |
| Constant_Condition | close | 0 | 0 | n/a |
| Cyclomatic_Complexity | direct | 17 | 4 | 76.5% |
| Dead_Store | close | 0 | 0 | n/a |
| Deep_Nesting | direct | 1 | 1 | 0.0% |
| Dependency_Limit | direct | 0 | 0 | n/a |
| Duplicate_Boolean_Operand | close | 0 | 0 | n/a |
| Duplicate_Condition | direct | 0 | 0 | n/a |
| Duplicate_With_Clause | direct | 0 | 0 | n/a |
| Empty_Else_Body | close | 0 | 0 | n/a |
| Empty_Elsif_Body | close | 0 | 0 | n/a |
| Empty_Exception_Handler | direct | 0 | 0 | n/a |
| Empty_If_Body | close | 0 | 0 | n/a |
| Empty_Then_Body | close | 0 | 0 | n/a |
| Exception_Propagation | close | 2 | 2 | 0.0% |
| Exception_Swallowed | close | 0 | 0 | n/a |
| Floating_Equality | direct | 0 | 0 | n/a |
| Identical_Branches | direct | 4 | 0 | 100.0% |
| Identical_Case_Alternative | close | 0 | 0 | n/a |
| Infinite_Loop | close | 2 | 0 | 100.0% |
| Library_Level_Initialization | close | 2 | 2 | 0.0% |
| Long_Line | direct | 0 | 0 | n/a |
| Magic_Number | close | 587 | 268 | 54.3% |
| Missing_Global_Contract | close | 12 | 12 | 0.0% |
| Missing_Overriding_Indicator | direct | 0 | 0 | n/a |
| Naming_Convention | close | 39 | 32 | 17.9% |
| No_Abort | direct | 0 | 0 | n/a |
| No_Access_To_Subp_Def | direct | 1 | 0 | 100.0% |
| No_Controlled_Type | direct | 0 | 0 | n/a |
| No_Goto | direct | 0 | 0 | n/a |
| No_Multiple_Return | direct | 71 | 69 | 2.8% |
| No_Pragma | close | 44 | 1 | 97.7% |
| No_Recursion | direct | 0 | 0 | n/a |
| Non_Short_Circuit_Condition | direct | 10 | 1 | 90.0% |
| Null_Case_Alternative | close | 4 | 4 | 0.0% |
| Null_Statement | direct | 0 | 0 | n/a |
| Overwritten_Assignment | close | 0 | 0 | n/a |
| Redundant_Boolean_Comparison | close | 0 | 0 | n/a |
| Redundant_Type_Conversion | close | 0 | 0 | n/a |
| Same_Operand | direct | 0 | 0 | n/a |
| Self_Assignment | close | 0 | 0 | n/a |
| Too_Many_Parameters | direct | 20 | 12 | 40.0% |
| Trailing_Whitespace | direct | 0 | 0 | n/a |
| Uninitialized_Output | close | 25 | 10 | 60.0% |
| Unused_Parameter | close | 0 | 0 | n/a |
| Unused_Variable | close | 2 | 2 | 0.0% |
| Unused_With_Clause | close | 2 | 2 | 0.0% |
| Wrong_Parameter_Mode | close | 5 | 5 | 0.0% |

## Per GNATcheck rule

| GNATcheck rule | Findings | GNATcheck-only | Matched |
| --- | ---: | ---: | ---: |
| `abort_statements` | 0 | 0 | n/a |
| `address_specifications_for_initialized_objects` | 0 | 0 | n/a |
| `address_specifications_for_local_objects` | 6 | 4 | 33.3% |
| `at_representation_clauses` | 0 | 0 | n/a |
| `boolean_negations` | 0 | 0 | n/a |
| `calls_outside_elaboration` | 0 | 0 | n/a |
| `controlled_type_declarations` | 0 | 0 | n/a |
| `duplicate_branches` | 6 | 2 | 66.7% |
| `exception_propagation_from_callbacks` | 0 | 0 | n/a |
| `exception_propagation_from_export` | 0 | 0 | n/a |
| `exception_propagation_from_tasks` | 0 | 0 | n/a |
| `float_equality_checks` | 0 | 0 | n/a |
| `forbidden_pragmas` | 43 | 0 | 100.0% |
| `goto_statements` | 0 | 0 | n/a |
| `improper_returns` | 340 | 338 | 0.6% |
| `maximum_parameters` | 155 | 147 | 5.2% |
| `metrics_cyclomatic_complexity` | 77 | 64 | 16.9% |
| `min_identifier_length` | 21 | 14 | 33.3% |
| `non_short_circuit_operators` | 55 | 46 | 16.4% |
| `null_paths` | 50 | 50 | 0.0% |
| `numeric_literals` | 319 | 0 | 100.0% |
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
| `simple_loop_statements` | 19 | 17 | 10.5% |
| `spark_procedures_without_globals` | 0 | 0 | n/a |
| `style_checks:M` | 0 | 0 | n/a |
| `style_checks:b` | 0 | 0 | n/a |
| `subprogram_access` | 1 | 0 | 100.0% |
| `too_many_dependencies` | 0 | 0 | n/a |
| `trivial_exception_handlers` | 0 | 0 | n/a |
| `unassigned_out_parameters` | 44 | 29 | 34.1% |
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

- Before this refresh the runner split each extra GNATcheck pass at spaces (an indented `IFS` value), so none of the fourteen pairs added on 2026-09-23 was actually checked on this corpus: the 2026-09-23 run showed GNATcheck at 0 for all of them, including 44 `No_Pragma` findings as AdaLang-only. Fixed; `No_Pragma` now matches.
- The compiler-driven pairs (`warnings:*`, `style_checks:*`) still cannot be judged here: GNATcheck's `Warnings`/`Style_Checks` rules compile each unit, and the two variant projects do not provide every dependency (e.g. `stm32_svd.ads`), so GNAT emits no warnings. Their GNATcheck column is structurally 0 on this corpus, not agreement or disagreement.
- This from-source GNATcheck build hits a deterministic `too_many_dependencies.lkql` internal issue and stack overflow on this corpus (see the attempt record above).
- Matching is on `(file basename, line, rule pair)`; rule pairs are name-level matches, not proven semantic equivalence (`docs/src/gnatcheck-rule-comparison.md`).
- `null_paths` family (`Empty_*_Body`, `Null_Case_Alternative`): GNATcheck reports at the empty statement, AdaLang at the branch or alternative.
- `No_Multiple_Return`/`improper_returns` differ in granularity (per subprogram vs. per return); `Too_Many_Parameters`/`maximum_parameters` report spec vs. body and use different default thresholds; `Missing_Global_Contract` deliberately also fires outside `SPARK_Mode`.
- `Identical_Branches`/`Identical_Case_Alternative` vs. `duplicate_branches` (run with `min_stmt=1,min_size=1`, matched on the line GNATcheck names as the duplicate): AdaLang compares adjacent branches only, so GNATcheck's non-adjacent pairs stay GNATcheck-only; GNATcheck reports one pair per `if`/`case`, so the later members of a run of identical adjacent branches stay AdaLang-only.
