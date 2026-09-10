# Tool-function validation evidence

This page is generated from
[`quality/tool_function_evidence.tsv`](https://github.com/mmartign/AdaLang_Analyzer/blob/main/quality/tool_function_evidence.tsv)
by `tests/gen_tool_qualification_doc.sh`, and is kept in sync with it by
`tests/run_tool_function_evidence.sh` in the repository gate. Do not edit it
by hand.

## Purpose

A tool-qualification argument under EN 50128 §6.7 (T2), ISO 26262-8 §11, or
DO-330 needs, at minimum, a statement of each tool function, validation
evidence traceable to it, and an analysis of what an undetected tool
malfunction could do. This page assembles the first and third of those for
every AdaLang Analyzer check, and links each check to machine-checked
validation cases.

It is **not** a qualification argument and does not discharge one. As the
[assurance model](assurance-model.md) states, absence of a finding is not
evidence that a defect is absent, and no profile or clean run qualifies this
tool. What follows is the raw material a project's own qualification effort
would build on, not a substitute for it.

## How to read this

Every check is placed in one **assurance class**. The class fixes what a
finding asserts and — because tool-error effects cluster by class rather than
varying per check — what a malfunction of that check would mean. The classes
mirror the confidence hierarchy in the [assurance model](assurance-model.md).

| Class | A finding asserts | Effect if the check **under-reports** (misses a real case) | Effect if the check **over-reports** (spurious finding) |
|---|---|---|---|
| `policy` | A construct the selected Ada subset or coding standard prohibits is present. | The prohibited construct stays in subset-restricted code unflagged; the restriction the profile exists to enforce is not enforced on that unit, and a reviewer relying on a clean run keeps it. | Review time is spent on a construct that is within policy. The analyzer only reports and never edits code, so nothing unsafe is introduced; the finding is dismissible with a recorded rationale. |
| `defect` | The check's documented analysis found evidence of a likely or definite defect. | The defect is not reported. A clean run is not evidence of absence, so it can pass review and reach downstream verification or the build. | Effort is spent confirming a flagged construct is not defective. The tool makes no change; the finding can be baselined with rationale and does not mask other findings. |
| `known_failure` | The abstract state was precise enough to show a run-time error is certain for the represented values at that point. | A statically certain error is not classified as definite; with no independent check it reaches run time as the corresponding Ada exception. Loss of a `Known_*`/definite signal is the direction the [false-safe response policy](false-safe-response.md) treats as release-blocking. | A construct is wrongly asserted to be a definite error, causing rework. It creates no unsafe code; the definite-error fixture corpus and, for the obligation kinds it covers, the GNATprove differential guard against it, and a confirmed instance is logged in `quality/known_analysis_issues.tsv`. |
| `readiness` | A construct, missing contract, or data-flow issue likely to obstruct a later SPARK / GNATprove pass or an assurance objective is present. | The readiness condition is not reported, so a later SPARK/GNATprove pass can fail or stall on exactly what this check was meant to surface early. | Effort is spent on a readiness finding GNATprove would not have needed. The tool changes nothing; the finding is suppressible with rationale. |
| `metric` | A configured numeric threshold was exceeded. | A subprogram or unit past the threshold is not reported, so an analyzability/maintainability limit the project set is not enforced there. | A subprogram or unit at or under the threshold is wrongly reported. The threshold is configurable and the finding can be baselined. |
| `style` | A house-style or readability rule was broken. | A style deviation is not reported; impact is limited to code consistency and reviewability. | A compliant construct is wrongly reported; cosmetic only, and suppressible with rationale. |

Across every class, an AdaLang over-report wastes engineering effort but
cannot by itself introduce a defect or mask another finding: the tool
produces diagnostics only and never rewrites source. The consequential
direction is under-reporting, and it is bounded differently per class as
above.

## Independent oracles

The **independent oracle** column records whether a second, independently
implemented tool cross-checks this check's behaviour on the shared benchmark
corpora, over and above the analyzer's own fixtures:

- `gnatcheck-comparison` — the check has a Direct or Close counterpart in
  the [GNATcheck rule comparison](gnatcheck-rule-comparison.md), and
  `benchmarks/`'s GNATcheck oracle run compares the two tools' findings at
  the same `(file, line)` across all ten external corpora.
- `gnatprove-differential` — the check's proof-obligation kind is
  exercised by the clean and broken GNATprove differential corpora described
  in the [assurance model](assurance-model.md), where GNATprove's verdict is
  ground truth.
- `none` — validated by the analyzer's own positive and negative fixtures
  only. This is the majority: most checks have no predefined-rule GNATcheck
  counterpart (see the comparison document), and only scalar run-time-check
  obligations are in the GNATprove differential's scope.

## Coverage summary

- **127 checks**, one per `Rule_Kind` literal in
  `src/adalang_analyzer-rules.ads`; every one has at least one positive and
  one negative validation invocation, each re-run by the gate one check at a
  time.
- **44** carry an independent-tool cross-check
  (37 via the GNATcheck comparison, 7 via the GNATprove
  differential); the remaining 83 are fixture-validated
  only.
- Class distribution:
  - `policy`: 31
  - `defect`: 45
  - `known_failure`: 15
  - `readiness`: 12
  - `metric`: 5
  - `style`: 19

## Exercise against independently-authored code

The fixtures above are hand-built. Separately, the checks are run over the
10 external Ada/SPARK corpora in
[`benchmarks/`](https://github.com/mmartign/AdaLang_Analyzer/tree/main/benchmarks)
as part of the release process, and
[`quality/corpus_exercise_coverage.tsv`](https://github.com/mmartign/AdaLang_Analyzer/blob/main/quality/corpus_exercise_coverage.tsv)
records, per check and derived wholly from the committed benchmark result
JSON, whether a preset run enabled it there, how many corpora did, and how
many findings across how many files it produced.

- **99 of 127** checks were enabled by at least one benchmark
  preset run (`--recommended` / `--spark` / `--automotive` / `--verify`)
  over an external corpus; **78** produced at least one finding on that
  real code.
- The remaining 28 are not reached by those preset
  runs -- mostly style rules outside every preset, plus any check newer than
  the last benchmark refresh -- and remain fixture-validated only:
  `No_Exit`, `No_Pragma`, `Redundant_Abs`, `Redundant_Unary_Minus`, `Integer_Division_Before_Multiplication`, `Excessive_Shift_Amount`, `Known_Negative_Shift_Amount_Failure`, `Known_Negative_Exponent_Failure`, `Succ_Pred_Boundary_Overflow`, `Duplicate_With_Clause`, `Duplicate_Exception_Choice`, `Null_Statement`, `Redundant_Final_Return`, `Contradictory_Range_Condition`, `Too_Many_Parameters`, `Unnecessary_Else_After_Return`, `Redundant_If_Boolean_Return`, `Long_Line`, `Trailing_Whitespace`, `Inefficient_String_Concatenation`, `Assertion_Side_Effect`, `Entry_Barrier_Side_Effect`, `Reraise_Discards_Occurrence`, `Known_Enum_Val_Failure`, `Known_Value_Conversion_Failure`, `Missing_Requirement_Trace`, `Malformed_Requirement_Trace`, `Double_Free`.

This is exercise evidence: the check ran against real, independently authored
Ada, not only against repository fixtures. It is not a soundness or
completeness measure, and a finding count is not a defect count.

The positive and negative invocations below are also exercised, with their
expected outcomes, by the other quality gates: the profile presets through
`run_automotive_evidence.sh` and `run_do178c_evidence.sh`, and the
boundary/negative corpus through `run_precision_corpus.sh`. This page adds
the whole-catalogue view and the per-class tool-error-effect analysis.

## Per-check validation evidence

| Check | Class | Documented function | Independent oracle | Positive invocation | Negative invocation |
|---|---|---|---|---|---|
| `No_Goto` | `policy` | Reports `goto` statements. | `gnatcheck-comparison` | `tests/bug_findings.adb` | `tests/clean_findings.adb` |
| `No_Abort` | `policy` | Reports asynchronous task aborts. | `gnatcheck-comparison` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `No_Raise` | `policy` | Reports explicit `raise` statements. | `none` | `tests/automotive_additional_findings.adb` | `tests/automotive_additional_clean.adb` |
| `No_Exit` | `policy` | Reports loop `exit` statements. | `none` | `tests/precision_named_loop_clean.adb` | `tests/precision_exit_call_clean.adb` |
| `No_Label` | `policy` | Reports statement labels. | `none` | `tests/automotive_additional_findings.adb` | `tests/automotive_additional_clean.adb` |
| `No_Pragma` | `policy` | Reports pragmas. | `gnatcheck-comparison` | `tests/precision_suppress_finding.adb` | `tests/precision_division_by_one_clean.adb` |
| `No_Access_To_Subp_Def` | `policy` | Reports access-to-subprogram type definitions. | `gnatcheck-comparison` | `tests/automotive_additional_findings.adb` | `tests/automotive_additional_clean.adb` |
| `No_Unchecked_Conversion` | `policy` | Reports instantiations of `Ada.Unchecked_Conversion`. | `none` | `tests/high_value_findings.adb` | `tests/high_value_clean.adb` |
| `No_Unchecked_Access` | `policy` | Reports uses of the `'Unchecked_Access` attribute. | `none` | `tests/precision_no_unchecked_access_finding.adb` | `tests/precision_no_unchecked_access_clean.adb` |
| `Floating_Equality` | `defect` | Reports `=` and `/=` applied to floating-point operands. | `gnatcheck-comparison` | `tests/high_value_findings.adb` | `tests/high_value_clean.adb` |
| `Magic_Number` | `style` | Reports unexplained numeric literals other than 0, 1, and -1 outside named constant declarations. | `gnatcheck-comparison` | `tests/high_value_findings.adb` | `tests/high_value_clean.adb` |
| `Unused_Parameter` | `defect` | Reports subprogram parameters that are never referenced. | `none` | `tests/precision_unused_parameter_guard.adb` | `tests/precision_unused_parameter_nested_reference_clean.adb` |
| `Wrong_Parameter_Mode` | `defect` | Reports `in out` parameters that are only read or only written. | `none` | `tests/precision_wrong_parameter_mode_index_read.adb` | `tests/parameter_mode_clean.adb` |
| `Dead_Store` | `defect` | Reports assignments whose value is never read later in the subprogram. | `none` | `tests/advanced_findings.adb` | `tests/advanced_clean.adb` |
| `Overwritten_Assignment` | `defect` | Reports assignments overwritten before an intervening read. | `none` | `tests/advanced_findings.adb` | `tests/advanced_clean.adb` |
| `Shadowed_Declaration` | `defect` | Reports local objects hiding declarations in enclosing subprograms. | `none` | `tests/advanced_findings.adb` | `tests/advanced_clean.adb` |
| `Unreachable_Case_Alternative` | `defect` | Reports choices wholly covered by an earlier case alternative. | `none` | `tests/advanced_findings.adb` | `tests/advanced_clean.adb` |
| `Overlapping_Case_Ranges` | `defect` | Reports intersecting statically evaluable integer choices. | `none` | `tests/advanced_findings.adb` | `tests/advanced_clean.adb` |
| `Infinite_Loop` | `defect` | Reports unconditional loops without an exit, return, or raise. | `gnatcheck-comparison` | `tests/advanced_findings.adb` | `tests/advanced_clean.adb` |
| `Duplicate_Boolean_Operand` | `defect` | Reports repeated boolean operands and double negations. | `gnatcheck-comparison` | `tests/precision_duplicate_boolean_operand_finding.adb` | `tests/precision_duplicate_boolean_operand_clean.adb` |
| `Redundant_Abs` | `style` | Reports `abs` applied to an operand that is itself an `abs` expression. | `none` | `tests/precision_redundant_abs_finding.adb` | `tests/precision_redundant_abs_clean.adb` |
| `Redundant_Unary_Minus` | `style` | Reports unary negation applied to an operand that is itself a unary negation. | `none` | `tests/precision_redundant_unary_minus_finding.adb` | `tests/precision_redundant_unary_minus_clean.adb` |
| `Exception_Swallowed` | `defect` | Reports empty or null-only `when others` handlers. | `gnatcheck-comparison` | `tests/automotive_additional_findings.adb` | `tests/automotive_additional_clean.adb` |
| `Cyclomatic_Complexity` | `metric` | Reports subprograms exceeding the configured complexity threshold. | `gnatcheck-comparison` | `-complexity-threshold=2 tests/advanced_findings.adb` | `-complexity-threshold=20 tests/advanced_clean.adb` |
| `Constant_Condition` | `defect` | Reports conditions that are statically always true or false. | `none` | `tests/flow_findings.adb` | `tests/flow_clean.adb` |
| `Unreachable_Code` | `defect` | Reports statements following an unconditional transfer of control. | `none` | `tests/bug_findings.adb` | `tests/clean_findings.adb` |
| `Division_By_Zero` | `known_failure` | Reports statically detectable division, `mod`, or `rem` by zero. | `gnatprove-differential` | `tests/flow_findings.adb` | `tests/flow_clean.adb` |
| `Integer_Division_Before_Multiplication` | `defect` | Reports integer multiplications whose left operand is an unparenthesized integer division. | `none` | `tests/precision_integer_division_before_multiplication_finding.adb` | `tests/precision_integer_division_before_multiplication_alignment_clean.adb` |
| `Excessive_Shift_Amount` | `known_failure` | Reports `Interfaces` shift/rotate calls whose static amount is not less than the operand type's bit width. | `none` | `tests/precision_excessive_shift_amount_finding.adb` | `tests/precision_excessive_shift_amount_clean.adb` |
| `Known_Negative_Shift_Amount_Failure` | `known_failure` | Reports `Interfaces` shift/rotate calls whose static amount is negative. | `none` | `tests/precision_known_negative_shift_amount_failure_finding.adb` | `tests/precision_known_negative_shift_amount_failure_clean.adb` |
| `Known_Negative_Exponent_Failure` | `known_failure` | Reports `**` exponentiations on an integer base whose static exponent is negative. | `none` | `tests/precision_known_negative_exponent_failure_finding.adb` | `tests/precision_known_negative_exponent_failure_clean.adb` |
| `Succ_Pred_Boundary_Overflow` | `known_failure` | Reports `'Succ` applied to `'Last` or `'Pred` applied to `'First` of the same scalar type. | `none` | `tests/precision_succ_pred_boundary_overflow_succ_finding.adb` | `tests/precision_succ_pred_boundary_overflow_clean.adb` |
| `Reversed_Range` | `known_failure` | Reports static ranges whose lower bound exceeds their upper bound. | `none` | `tests/automotive_additional_findings.adb` | `tests/automotive_additional_clean.adb` |
| `Self_Assignment` | `defect` | Reports assignments whose target and value designate the same object, including through simple renames. | `none` | `tests/call_and_rename_findings.adb` | `tests/data_flow_loop_clean.adb` |
| `Same_Operand` | `defect` | Reports suspicious binary expressions with identical operands. | `gnatcheck-comparison` | `tests/precision_same_operand_subtraction_guard.adb` | `tests/precision_same_operand_identity_ops_clean.adb` |
| `Duplicate_Condition` | `defect` | Reports repeated conditions in an `if`/`elsif` chain. | `gnatcheck-comparison` | `tests/precision_duplicate_condition_nonadjacent_guard.adb` | `tests/precision_duplicate_condition_clean.adb` |
| `Duplicate_With_Clause` | `defect` | Reports with clauses naming a unit already with'd in the same context clause. | `none` | `tests/precision_duplicate_with_clause_finding.adb` | `tests/precision_duplicate_with_clause_clean.adb` |
| `Duplicate_Exception_Choice` | `defect` | Reports an exception handler whose own choice list names the same exception more than once. | `none` | `tests/precision_duplicate_exception_choice_finding.adb` | `tests/precision_duplicate_exception_choice_clean.adb` |
| `Null_Statement` | `style` | Reports executable `null` statements. | `gnatcheck-comparison` | `tests/precision_null_statement_finding.adb` | `tests/precision_null_subp_clean.adb` |
| `Redundant_Final_Return` | `style` | Reports a bare `return;` as the last statement of a procedure body. | `none` | `tests/precision_redundant_final_return_finding.adb` | `tests/precision_redundant_final_return_clean.adb` |
| `Empty_Exception_Handler` | `defect` | Reports handlers containing no substantive statements. | `gnatcheck-comparison` | `tests/advanced_findings.adb` | `tests/advanced_clean.adb` |
| `Unreachable_Branch` | `defect` | Reports branches excluded by earlier static conditions. | `none` | `tests/automotive_additional_findings.adb` | `tests/automotive_additional_clean.adb` |
| `Contradictory_Condition` | `defect` | Reports expressions such as `X and not X` or `X or not X`. | `none` | `tests/bug_findings.adb` | `tests/clean_findings.adb` |
| `Contradictory_Range_Condition` | `defect` | Reports `and`/`and then` conditions combining two relational comparisons on the same expression whose statically known bounds cannot both hold. | `none` | `tests/precision_contradictory_range_condition_finding.adb` | `tests/precision_contradictory_range_condition_clean.adb` |
| `Identical_Branches` | `defect` | Reports adjacent conditional branches with identical bodies. | `gnatcheck-comparison` | `tests/precision_identical_branches_adjacent_guard.adb` | `tests/precision_identical_branches_nonadjacent_clean.adb` |
| `Repeated_Statement` | `defect` | Reports identical consecutive assignments. | `none` | `tests/bug_findings.adb` | `tests/clean_findings.adb` |
| `Ineffective_Operation` | `style` | Reports operations containing an identity operand that has no effect. | `none` | `tests/precision_additive_identity_operand.adb` | `tests/precision_absorbing_multiplication_operand.adb` |
| `Constant_Result_Operation` | `defect` | Reports operations forced to a constant by an absorbing operand. | `none` | `tests/precision_absorbing_multiplication_operand.adb` | `tests/precision_additive_identity_operand.adb` |
| `Empty_Loop` | `defect` | Reports loops containing no substantive statements. | `none` | `tests/precision_empty_loop_guard.adb` | `tests/precision_empty_loop_clean.adb` |
| `No_Recursion` | `policy` | Reports subprograms that call themselves directly. | `gnatcheck-comparison` | `tests/new_checks_findings.adb` | `tests/new_checks_clean.adb` |
| `No_Multiple_Return` | `policy` | Reports subprograms with more than one return statement. | `gnatcheck-comparison` | `tests/new_checks_findings.adb` | `tests/new_checks_clean.adb` |
| `Non_Short_Circuit_Condition` | `defect` | Reports plain `and`/`or` used in an if/elsif/exit-when/while condition. | `gnatcheck-comparison` | `tests/new_checks_findings.adb` | `tests/new_checks_clean.adb` |
| `Address_Clause` | `policy` | Reports address representation clauses. | `gnatcheck-comparison` | `tests/new_checks_findings.adb` | `tests/new_checks_clean.adb` |
| `Too_Many_Parameters` | `metric` | Reports subprograms exceeding the configured parameter-count threshold. | `gnatcheck-comparison` | `tests/precision_too_many_parameters_over_threshold.adb` | `tests/precision_too_many_parameters_at_threshold.adb` |
| `Swappable_Parameters` | `defect` | Reports adjacent parameters sharing a mode and a resolved type, which a positional call could transpose undetected. | `none` | `tests/precision_swappable_parameters_finding.adb` | `tests/precision_swappable_parameters_different_types_clean.adb` |
| `Deep_Nesting` | `metric` | Reports subprograms exceeding the configured nesting-depth threshold. | `gnatcheck-comparison` | `-nesting-threshold=3 tests/new_checks_findings.adb` | `-nesting-threshold=3 tests/new_checks_clean.adb` |
| `Unused_Variable` | `defect` | Reports local objects that are never referenced. | `none` | `tests/precision_unused_variable_guard.adb` | `tests/precision_unused_variable_nested_reference_clean.adb` |
| `Empty_If_Body` | `style` | Reports if statements with no elsif/else whose body has no effect. | `gnatcheck-comparison` | `tests/precision_empty_if_body_guard.adb` | `tests/precision_empty_if_body_with_else_clean.adb` |
| `Empty_Elsif_Body` | `style` | Reports elsif branches with no substantive statements. | `gnatcheck-comparison` | `tests/precision_empty_elsif_body_guard.adb` | `tests/precision_empty_elsif_body_clean.adb` |
| `Empty_Then_Body` | `style` | Reports an empty then branch even when an elsif or else follows. | `gnatcheck-comparison` | `tests/precision_empty_then_body_guard.adb` | `tests/precision_empty_then_body_clean.adb` |
| `Empty_Else_Body` | `style` | Reports else parts with no substantive statements. | `gnatcheck-comparison` | `tests/precision_empty_else_body_guard.adb` | `tests/precision_empty_else_body_clean.adb` |
| `Null_Case_Alternative` | `style` | Reports case alternatives with no substantive statements. | `gnatcheck-comparison` | `tests/precision_null_case_alternative_guard.adb` | `tests/precision_null_case_alternative_clean.adb` |
| `Unnecessary_Else_After_Return` | `style` | Reports else parts made redundant by an earlier unconditional return/raise/exit. | `none` | `tests/precision_unnecessary_else_after_return_guard.adb` | `tests/precision_unnecessary_else_after_return_clean.adb` |
| `Redundant_If_Boolean_Return` | `style` | Reports an if statement whose then and else branches each return only an opposite boolean literal. | `none` | `tests/precision_redundant_if_boolean_return_finding.adb` | `tests/precision_redundant_if_boolean_return_same_literal_clean.adb` |
| `Function_Side_Effect` | `defect` | Reports functions that assign to state outside their own parameters and locals. | `none` | `tests/new_checks_findings.adb` | `tests/new_checks_clean.adb` |
| `Redundant_Boolean_Comparison` | `style` | Reports equality/inequality comparisons against the literal `True`/`False`. | `gnatcheck-comparison` | `tests/new_checks_findings.adb` | `tests/new_checks_clean.adb` |
| `Long_Line` | `style` | Reports source lines longer than the configured threshold. | `none` | `tests/precision_long_line_over_threshold.adb` | `tests/precision_long_line_at_threshold.adb` |
| `Trailing_Whitespace` | `style` | Reports source lines with trailing spaces or tabs. | `none` | `tests/precision_trailing_whitespace_finding.adb` | `tests/precision_blank_line_clean.adb` |
| `SPARK_Mode` | `readiness` | Reports regions that explicitly set `SPARK_Mode` to `Off`. | `none` | `tests/spark_findings.adb` | `tests/spark_clean.adb` |
| `Missing_Global_Contract` | `readiness` | Reports subprograms that access global state without an explicit `Global` contract. | `gnatcheck-comparison` | `tests/spark_readiness_findings.adb` | `tests/spark_readiness_clean.adb` |
| `Global_Contract_Mismatch` | `readiness` | Reports actual global reads or writes that an existing `Global` contract does not permit. | `none` | `tests/spark_readiness_findings.adb` | `tests/spark_readiness_clean.adb` |
| `Missing_Depends_Contract` | `readiness` | Reports subprograms with outputs but no explicit `Depends` contract. | `none` | `tests/spark_readiness_findings.adb` | `tests/spark_readiness_clean.adb` |
| `Incomplete_Depends_Contract` | `readiness` | Reports writable parameters or global outputs omitted from `Depends`. | `none` | `tests/spark_readiness_findings.adb` | `tests/spark_readiness_clean.adb` |
| `Depends_Contract_Mismatch` | `readiness` | Compares inferred data and control flow with declared `Depends` input-to-output relations. | `none` | `tests/spark_dependency_findings.adb` | `tests/spark_dependency_clean.adb` |
| `Uninitialized_Output` | `readiness` | Reports `out` parameters not demonstrably initialized on every normal return path. | `gnatcheck-comparison` | `tests/spark_readiness_findings.adb` | `tests/spark_readiness_clean.adb` |
| `Uninitialized_Read` | `defect` | Reports scalar local variables with no initial value whose first use is a read. | `none` | `tests/uninitialized_read_findings.adb` | `tests/uninitialized_read_clean.adb` |
| `Missing_Overriding_Indicator` | `style` | Reports primitive subprograms that override an inherited operation without the `overriding` keyword. | `gnatcheck-comparison` | `tests/overriding_indicator_findings.ads` | `tests/overriding_indicator_clean.ads` |
| `Inefficient_String_Concatenation` | `defect` | Reports a string variable rebuilt with `&` inside a loop. | `none` | `tests/string_concatenation_findings.adb` | `tests/string_concatenation_clean.adb` |
| `Circular_Package_Dependency` | `defect` | Reports groups of analyzed units whose with clauses form a dependency cycle. | `none` | `tests/circular_dependency_findings_a.ads tests/circular_dependency_findings_b.ads tests/circular_dependency_clean.ads` | `tests/circular_dependency_clean.ads` |
| `Duplicate_Subprogram` | `defect` | Reports subprogram bodies, anywhere in the analyzed project, textually identical to another subprogram's. | `none` | `tests/precision_duplicate_subprogram_finding.adb` | `tests/precision_duplicate_subprogram_trivial_clean.adb` |
| `Known_Precondition_Failure` | `known_failure` | Reports calls whose actual values make a precondition false. | `gnatprove-differential` | `tests/spark_findings.adb` | `tests/spark_clean.adb` |
| `Known_Postcondition_Failure` | `known_failure` | Reports bodies whose resulting state makes their postcondition false. | `gnatprove-differential` | `tests/spark_findings.adb` | `tests/spark_clean.adb` |
| `Known_Assertion_Failure` | `known_failure` | Reports assertion pragmas whose condition is statically false at that program point. | `gnatprove-differential` | `tests/proof_assertion_findings.adb` | `tests/proof_assertion_clean.adb` |
| `Assertion_Side_Effect` | `readiness` | Reports assertion pragmas whose condition calls a function with an out or in out parameter. | `none` | `tests/precision_assertion_side_effect_finding.adb` | `tests/precision_assertion_side_effect_clean.adb` |
| `Entry_Barrier_Side_Effect` | `readiness` | Reports protected entry barrier conditions that call a function with an out or in out parameter. | `none` | `tests/precision_entry_barrier_side_effect_finding.adb` | `tests/precision_entry_barrier_side_effect_clean.adb` |
| `Known_Range_Check_Failure` | `known_failure` | Reports values provably outside an assignment, initialization, or conversion subtype. | `gnatprove-differential` | `tests/runtime_check_findings.adb` | `tests/runtime_check_clean.adb` |
| `Known_Index_Check_Failure` | `known_failure` | Reports array indices provably outside the corresponding index subtype. | `gnatprove-differential` | `tests/runtime_check_findings.adb` | `tests/runtime_check_clean.adb` |
| `Known_Overflow_Failure` | `known_failure` | Reports integer arithmetic provably outside the operation's base type. | `gnatprove-differential` | `tests/overflow_findings.adb` | `tests/overflow_clean.adb` |
| `Identical_Case_Alternative` | `defect` | Reports adjacent case alternatives with identical bodies. | `gnatcheck-comparison` | `tests/precision_identical_case_alternative_adjacent_finding.adb` | `tests/precision_identical_case_alternative_nonadjacent_clean.adb` |
| `Redundant_Type_Conversion` | `style` | Reports explicit type conversions whose operand already has the target subtype. | `none` | `tests/general_checks2_findings.adb` | `tests/general_checks2_clean.adb` |
| `Handler_Order` | `defect` | Reports a `when others` handler that precedes, and thereby shadows, a more specific handler in the same list. | `none` | `tests/general_checks2_findings.adb` | `tests/general_checks2_clean.adb` |
| `Reraise_Discards_Occurrence` | `defect` | Reports an exception handler's last statement re-raising the same single exception it caught by name instead of a bare `raise;`. | `none` | `tests/precision_reraise_discards_occurrence_finding.adb` | `tests/precision_reraise_discards_occurrence_bare_raise_clean.adb` |
| `Aliasing_Between_Parameters` | `defect` | Reports calls that pass the same object or component as two actual parameters when at least one corresponding formal is written. | `gnatcheck-comparison` | `tests/spark_checks2_findings.adb` | `tests/spark_checks2_clean.adb` |
| `Missing_Loop_Variant` | `readiness` | Reports loops with a `Loop_Invariant` pragma but no `Loop_Variant` pragma. | `none` | `tests/spark_checks2_findings.adb` | `tests/spark_checks2_clean.adb` |
| `Known_Discriminant_Check_Failure` | `known_failure` | Reports accesses to a variant-part component that a statically known discriminant constraint provably excludes. | `none` | `tests/discriminant_check_findings.adb` | `tests/discriminant_check_clean.adb` |
| `Known_Enum_Val_Failure` | `known_failure` | Reports `'Val` attribute calls whose statically known argument is outside the enumeration type's literal positions. | `none` | `tests/precision_known_enum_val_failure_finding.adb` | `tests/precision_known_enum_val_failure_boundary_clean.adb` |
| `Known_Value_Conversion_Failure` | `known_failure` | Reports `'Value` attribute calls whose static string literal argument can never denote a value of the prefix integer or enumeration type. | `none` | `tests/precision_known_value_conversion_failure_integer_finding.adb` | `tests/precision_known_value_conversion_failure_integer_clean.adb` |
| `Potentially_Blocking_Operation` | `defect` | Reports entry calls, delay statements, and calls transitively reaching them from a protected operation. | `none` | `tests/interprocedural_blocking_findings.adb` | `tests/interprocedural_blocking_clean.adb` |
| `No_Dynamic_Allocation` | `policy` | Reports allocators. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `Restricted_Access_Type` | `policy` | Reports access-to-object type definitions. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `No_Explicit_Dereference` | `policy` | Reports explicit `.all` dereferences. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `No_Unchecked_Deallocation` | `policy` | Reports semantic instantiations of `Ada.Unchecked_Deallocation`. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `No_Tasking` | `policy` | Reports task declarations. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `No_Rendezvous` | `policy` | Reports entry declarations and accept statements. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `No_Select` | `policy` | Reports selective, timed, conditional, and asynchronous select forms. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `No_Requeue` | `policy` | Reports requeue statements. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `No_Asynchronous_Transfer` | `policy` | Reports asynchronous select/abortable-part constructs. | `none` | `tests/automotive_restrictions_findings.adb` | `tests/automotive_restrictions_clean.adb` |
| `Exception_Propagation` | `defect` | Reports calls that may propagate a direct or transitive explicit exception when the enclosing subprogram has no handler boundary. | `gnatcheck-comparison` | `tests/automotive_semantic_findings.adb` | `tests/automotive_semantic_clean.adb` |
| `No_Dispatching_Call` | `policy` | Reports semantically resolved dispatching calls. | `none` | `tests/automotive_semantic_findings.adb` | `tests/automotive_semantic_clean.adb` |
| `No_Classwide_Type` | `policy` | Reports class-wide subtype marks. | `none` | `tests/automotive_semantic_findings.adb` | `tests/automotive_semantic_clean.adb` |
| `No_Controlled_Type` | `policy` | Reports derivation from controlled or limited-controlled types. | `gnatcheck-comparison` | `tests/automotive_semantic_findings.adb` | `tests/automotive_semantic_clean.adb` |
| `Complete_Initialization` | `policy` | Reports objects and record components without explicit initialization. | `none` | `tests/automotive_state_findings.ads tests/automotive_state_findings.adb` | `tests/automotive_state_clean.ads` |
| `Volatile_Atomic_Consistency` | `policy` | Reports volatile declarations lacking an atomic or full-access policy. | `none` | `tests/automotive_state_findings.ads` | `tests/automotive_state_clean.ads` |
| `Representation_Clause_Policy` | `policy` | Requires every explicit representation clause to receive target-specific review. | `none` | `tests/automotive_state_findings.ads` | `tests/automotive_state_clean.ads` |
| `Library_Level_Initialization` | `policy` | Reports library-level initializers containing calls. | `gnatcheck-comparison` | `tests/automotive_state_findings.ads tests/automotive_state_findings.adb` | `tests/automotive_state_clean.ads` |
| `Generic_Instantiation_Limit` | `metric` | Reports units exceeding the configured generic-instantiation limit. | `none` | `-generic-threshold=1 tests/automotive_policy_findings.adb` | `-generic-threshold=1 tests/automotive_policy_clean.adb` |
| `Dependency_Limit` | `metric` | Reports units exceeding the configured with-clause limit. | `gnatcheck-comparison` | `-dependency-threshold=1 tests/automotive_policy_findings.adb` | `-dependency-threshold=1 tests/automotive_policy_clean.adb` |
| `Naming_Convention` | `style` | Reports one-character identifiers except loop indices and enumeration literals. | `gnatcheck-comparison` | `tests/automotive_policy_findings.adb` | `tests/automotive_policy_clean.adb` |
| `No_Compiler_Extensions` | `policy` | Reports implementation-defined pragmas, including extension-enabling pragmas. | `none` | `tests/automotive_policy_findings.adb` | `tests/automotive_policy_clean.adb` |
| `No_Runtime_Check_Suppression` | `policy` | Reports `Suppress`, `Suppress_All`, and check policies that ignore or disable Ada run-time checks. | `none` | `tests/automotive_runtime_suppression_findings.adb` | `tests/automotive_runtime_suppression_clean.adb` |
| `Missing_Requirement_Trace` | `readiness` | Reports subprogram bodies without a nearby low-level requirement identifier. | `none` | `tests/do178c_findings.adb` | `tests/do178c_clean.adb` |
| `Malformed_Requirement_Trace` | `readiness` | Reports requirement annotations with no identifier. | `none` | `tests/do178c_findings.adb` | `tests/do178c_clean.adb` |
| `Suppression_Without_Rationale` | `policy` | Reports analyzer suppressions that do not record a reviewable rationale. | `none` | `tests/do178c_findings.adb` | `tests/do178c_clean.adb` |
| `Use_After_Free` | `defect` | Reports a local access object read after `Ada.Unchecked_Deallocation` frees it, with no intervening assignment. | `none` | `tests/precision_use_after_free_finding.adb` | `tests/precision_use_after_free_clean.adb` |
| `Double_Free` | `defect` | Reports a local access object passed to `Ada.Unchecked_Deallocation` a second time, with no intervening assignment. | `none` | `tests/precision_double_free_finding.adb` | `tests/precision_double_free_clean.adb` |
| `Unclosed_File_Handle` | `defect` | Reports a local `Ada.Text_IO`/`Ada.Streams.Stream_IO` file opened with `Open`/`Create` and not demonstrably closed on every normal-return or exception-handler path. | `none` | `tests/precision_unclosed_file_handle_finding.adb` | `tests/precision_unclosed_file_handle_clean.adb` |
| `Unused_With_Clause` | `defect` | Reports a with clause naming a unit never referenced elsewhere in the file. | `none` | `tests/precision_unused_with_clause_finding.adb` | `tests/precision_unused_with_clause_clean.adb` |
