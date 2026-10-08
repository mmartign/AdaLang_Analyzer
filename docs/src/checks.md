# Checks

AdaLang Analyzer's 302 checks fall into six broad groups:

- **Defect detection** — control-flow, data-flow, expression, case/
  conditional, exception-handling, arithmetic, assignment, and complexity
  checks that flag likely or definite runtime and logic defects.
- **SPARK readiness** — `Global`/`Depends` contract checks and known
  precondition/postcondition/assertion/range/index/overflow/discriminant/
  enum-val/value-conversion failures that anticipate what a later
  GNATprove pass will need.
- **Bounded verification** — `--verify`'s scalar proof-obligation
  classification (a mode, not a rule in the table below; see the following
  sections).
- **Safety profiles** — the `Automotive` and `DO-178C support` checks behind
  `--automotive` and `--do178c=<level>`.
- **Style & maintainability** — restricted-construct policies, style, and
  naming checks.
- **Coding-standard policies** — 175 opt-in checks for the rules project
  coding standards impose: naming conventions, layout, restricted
  constructs, object-oriented design, representation items and complexity
  limits. No preset enables them; select each by name. Those that need a
  limit or a list take it from `-rule-param=<check>.<name>=<value>`. Each is
  paired with a GNATcheck rule (see the
  [GNATcheck rule comparison](gnatcheck-rule-comparison.md)).

Run `./bin/adalang_analyzer -list-checks` for the authoritative catalog and
guidance shipped by the current binary.

The last column gives the GNATcheck rule a check is paired with, if any; that
name is accepted wherever the check's own name is (see
[Configuration](configuration.md)).

<details>
<summary><strong>Browse all 302 checks</strong></summary>

<br>

| Category | Check | Software Quality | Severity | Purpose | GNATcheck rule |
|----------|-------|-------------------|----------|---------|----------------|
| Restricted construct | `No_Goto` | Maintainability | Medium | Reports `goto` statements. | `goto_statements` |
| Restricted construct | `No_Abort` | Reliability | High | Reports asynchronous task aborts. | `abort_statements` |
| Restricted construct | `No_Raise` | Maintainability | Low | Reports explicit `raise` statements. | — |
| Restricted construct | `No_Exit` | Maintainability | Low | Reports loop `exit` statements. | — |
| Restricted construct | `No_Label` | Maintainability | Low | Reports statement labels. | — |
| Restricted construct | `No_Pragma` | Maintainability | Low | Reports pragmas. | `forbidden_pragmas` |
| Restricted construct | `No_Access_To_Subp_Def` | Maintainability | Medium | Reports access-to-subprogram type definitions. | `subprogram_access` |
| Safety | `No_Unchecked_Conversion` | Security | High | Reports instantiations of `Ada.Unchecked_Conversion`. | — |
| Safety | `No_Unchecked_Access` | Security | High | Reports uses of the `'Unchecked_Access` attribute. | — |
| Numerical safety | `Floating_Equality` | Reliability | Medium | Reports `=` and `/=` applied to floating-point operands. | `float_equality_checks` |
| Maintainability | `Magic_Number` | Maintainability | Low | Reports unexplained numeric literals other than 0, 1, and -1 outside named constant declarations. | `numeric_literals` |
| Data flow | `Unused_Parameter` | Maintainability | Low | Reports subprogram parameters that are never referenced. | — |
| Data flow | `Wrong_Parameter_Mode` | Maintainability | Medium | Reports `in out` parameters that are only read or only written. | — |
| Data flow | `Dead_Store` | Maintainability | Medium | Reports assignments whose value is never read later in the subprogram. | — |
| Data flow | `Overwritten_Assignment` | Reliability | Medium | Reports assignments overwritten before an intervening read. | — |
| Data flow | `Uninitialized_Read` | Reliability | High | Reports scalar local variables with no initial value whose first use is a read. | — |
| Data flow | `Inefficient_String_Concatenation` | Reliability | Medium | Reports a string variable rebuilt with `&` inside a loop. | — |
| Scope | `Shadowed_Declaration` | Reliability | Medium | Reports local objects hiding declarations in enclosing subprograms. | — |
| Case analysis | `Unreachable_Case_Alternative` | Reliability | Medium | Reports choices wholly covered by an earlier case alternative. | — |
| Case analysis | `Overlapping_Case_Ranges` | Reliability | High | Reports intersecting statically evaluable integer choices. | — |
| Control flow | `Infinite_Loop` | Reliability | High | Reports unconditional loops without an exit, return, or raise. | `simple_loop_statements` |
| Expression | `Duplicate_Boolean_Operand` | Reliability | Medium | Reports repeated boolean operands and double negations. | `redundant_boolean_expressions`, `same_operands` |
| Expression | `Redundant_Abs` | Maintainability | Low | Reports `abs` applied to an operand that is itself an `abs` expression. | — |
| Expression | `Redundant_Unary_Minus` | Maintainability | Low | Reports unary negation applied to an operand that is itself a unary negation. | — |
| Exception handling | `Exception_Swallowed` | Reliability | High | Reports empty or null-only `when others` handlers. | `silent_exception_handlers`, `trivial_exception_handlers` |
| Complexity | `Cyclomatic_Complexity` | Maintainability | Medium | Reports subprograms exceeding the configured complexity threshold. | `metrics_cyclomatic_complexity` |
| Control flow | `Constant_Condition` | Reliability | Medium | Reports conditions that are statically always true or false. | — |
| Control flow | `Unreachable_Code` | Maintainability | Medium | Reports statements following an unconditional transfer of control. | — |
| Arithmetic | `Division_By_Zero` | Reliability | Blocker | Reports statically detectable division, `mod`, or `rem` by zero. | — |
| Arithmetic | `Integer_Division_Before_Multiplication` | Reliability | Medium | Reports integer multiplications whose left operand is an unparenthesized integer division. | — |
| Arithmetic | `Excessive_Shift_Amount` | Reliability | High | Reports `Interfaces` shift/rotate calls whose static amount is not less than the operand type's bit width. | — |
| Arithmetic | `Known_Negative_Shift_Amount_Failure` | Reliability | High | Reports `Interfaces` shift/rotate calls whose static amount is negative. | — |
| Arithmetic | `Known_Negative_Exponent_Failure` | Reliability | High | Reports `**` exponentiations on an integer base whose static exponent is negative. | — |
| Arithmetic | `Succ_Pred_Boundary_Overflow` | Reliability | Blocker | Reports `'Succ` applied to `'Last` or `'Pred` applied to `'First` of the same scalar type. | — |
| Arithmetic | `Reversed_Range` | Reliability | Medium | Reports static ranges whose lower bound exceeds their upper bound. | — |
| Assignment | `Self_Assignment` | Reliability | Medium | Reports assignments whose target and value designate the same object, including through simple renames. | — |
| Expression | `Same_Operand` | Reliability | Medium | Reports suspicious binary expressions with identical operands. | `same_operands` |
| Conditional | `Duplicate_Condition` | Reliability | Medium | Reports repeated conditions in an `if`/`elsif` chain. | `same_tests` |
| Duplication | `Duplicate_With_Clause` | Maintainability | Low | Reports with clauses naming a unit already with'd in the same context clause. | — |
| Style | `Null_Statement` | Maintainability | Low | Reports executable `null` statements. | `redundant_null_statements` |
| Style | `Redundant_Final_Return` | Maintainability | Low | Reports a bare `return;` as the last statement of a procedure body. | — |
| Exception handling | `Empty_Exception_Handler` | Reliability | High | Reports handlers containing no substantive statements. | `silent_exception_handlers` |
| Exception handling | `Duplicate_Exception_Choice` | Maintainability | Low | Reports an exception handler whose own choice list names the same exception more than once. | — |
| Control flow | `Unreachable_Branch` | Reliability | Medium | Reports branches excluded by earlier static conditions. | — |
| Conditional | `Contradictory_Condition` | Reliability | High | Reports expressions such as `X and not X` or `X or not X`. | — |
| Conditional | `Contradictory_Range_Condition` | Reliability | High | Reports `and`/`and then` conditions combining two relational comparisons on the same expression whose statically known bounds cannot both hold. | — |
| Conditional | `Identical_Branches` | Reliability | Medium | Reports adjacent conditional branches with identical bodies. | `duplicate_branches` |
| Assignment | `Repeated_Statement` | Reliability | Medium | Reports identical consecutive assignments. | — |
| Expression | `Ineffective_Operation` | Maintainability | Low | Reports operations containing an identity operand that has no effect. | — |
| Expression | `Constant_Result_Operation` | Reliability | Medium | Reports operations forced to a constant by an absorbing operand. | — |
| Control flow | `Empty_Loop` | Reliability | Medium | Reports loops containing no substantive statements. | — |
| Restricted construct | `No_Recursion` | Reliability | High | Reports subprograms that call themselves directly. | `recursive_subprograms` |
| Restricted construct | `No_Multiple_Return` | Maintainability | Low | Reports subprograms with more than one return statement. | `improper_returns` |
| Control flow | `Non_Short_Circuit_Condition` | Reliability | High | Reports plain `and`/`or` used in an if/elsif/exit-when/while condition. | `non_short_circuit_operators` |
| Safety | `Address_Clause` | Security | High | Reports address representation clauses. | `address_specifications_for_initialized_objects`, `address_specifications_for_local_objects`, `at_representation_clauses` |
| Complexity | `Too_Many_Parameters` | Maintainability | Medium | Reports subprograms exceeding the configured parameter-count threshold. | `maximum_parameters` |
| Complexity | `Swappable_Parameters` | Reliability | Medium | Reports adjacent parameters sharing a mode and a resolved type, which a positional call could transpose undetected. | — |
| Complexity | `Deep_Nesting` | Maintainability | Medium | Reports subprograms exceeding the configured nesting-depth threshold. | `overly_nested_control_structures` |
| Data flow | `Unused_Variable` | Maintainability | Low | Reports local objects that are never referenced. | — |
| Style | `Empty_If_Body` | Maintainability | Low | Reports if statements with no elsif/else whose body has no effect. | `null_paths` |
| Style | `Empty_Elsif_Body` | Maintainability | Low | Reports elsif branches with no substantive statements. | `null_paths` |
| Style | `Empty_Then_Body` | Maintainability | Low | Reports an empty then branch even when an elsif or else follows. | `null_paths` |
| Style | `Empty_Else_Body` | Maintainability | Low | Reports else parts with no substantive statements. | `null_paths` |
| Style | `Null_Case_Alternative` | Maintainability | Low | Reports case alternatives with no substantive statements. | `null_paths` |
| Style | `Unnecessary_Else_After_Return` | Maintainability | Low | Reports else parts made redundant by an earlier unconditional return/raise/exit. | — |
| Style | `Redundant_If_Boolean_Return` | Maintainability | Low | Reports an if statement whose then and else branches each return only an opposite boolean literal. | — |
| Data flow | `Function_Side_Effect` | Reliability | High | Reports functions that assign to state outside their own parameters and locals. | — |
| Expression | `Redundant_Boolean_Comparison` | Maintainability | Low | Reports equality/inequality comparisons against the literal `True`/`False`. | `boolean_negations`, `redundant_boolean_expressions` |
| Style | `Long_Line` | Maintainability | Low | Reports source lines longer than the configured threshold. | — |
| Style | `Trailing_Whitespace` | Maintainability | Low | Reports source lines with trailing spaces or tabs. | — |
| SPARK | `SPARK_Mode` | Reliability | High | Reports regions that explicitly set `SPARK_Mode` to `Off`. | — |
| SPARK | `Missing_Global_Contract` | Maintainability | Medium | Reports subprograms that access global state without an explicit `Global` contract. | `spark_procedures_without_globals` |
| SPARK | `Global_Contract_Mismatch` | Reliability | High | Reports actual global reads or writes that an existing `Global` contract does not permit. | — |
| SPARK | `Missing_Depends_Contract` | Maintainability | Medium | Reports subprograms with outputs but no explicit `Depends` contract. | — |
| SPARK | `Incomplete_Depends_Contract` | Reliability | High | Reports writable parameters or global outputs omitted from `Depends`. | — |
| SPARK | `Depends_Contract_Mismatch` | Reliability | High | Compares inferred data and control flow with declared `Depends` input-to-output relations. | — |
| SPARK | `Uninitialized_Output` | Reliability | High | Reports `out` parameters not demonstrably initialized on every normal return path. | `unassigned_out_parameters` |
| SPARK | `Known_Precondition_Failure` | Reliability | High | Reports calls whose actual values make a precondition false. | — |
| SPARK | `Known_Postcondition_Failure` | Reliability | High | Reports bodies whose resulting state makes their postcondition false. | — |
| SPARK | `Known_Assertion_Failure` | Reliability | High | Reports assertion pragmas whose condition is statically false at that program point. | — |
| SPARK | `Assertion_Side_Effect` | Reliability | Medium | Reports assertion pragmas whose condition calls a function with an out or in out parameter. | — |
| Tasking | `Entry_Barrier_Side_Effect` | Reliability | Medium | Reports protected entry barrier conditions that call a function with an out or in out parameter. | — |
| SPARK | `Known_Range_Check_Failure` | Reliability | High | Reports values provably outside an assignment, initialization, or conversion subtype. | — |
| SPARK | `Known_Index_Check_Failure` | Reliability | High | Reports array indices provably outside the corresponding index subtype. | — |
| SPARK | `Known_Overflow_Failure` | Reliability | High | Reports integer arithmetic provably outside the operation's base type. | — |
| Case analysis | `Identical_Case_Alternative` | Reliability | Medium | Reports adjacent case alternatives (in case statements or case expressions) with identical bodies. | `duplicate_branches` |
| Expression | `Redundant_Type_Conversion` | Maintainability | Low | Reports explicit type conversions whose operand already has the target subtype. | — |
| Style | `Missing_Overriding_Indicator` | Maintainability | Medium | Reports primitive subprograms that override an inherited operation without the `overriding` keyword. | `overriding_indicators` |
| Exception handling | `Handler_Order` | Reliability | High | Reports a `when others` handler that precedes, and thereby shadows, a more specific handler in the same list. | — |
| Exception handling | `Reraise_Discards_Occurrence` | Reliability | Medium | Reports an exception handler's last statement re-raising the same single exception it caught by name instead of a bare `raise;`. | — |
| Data flow | `Aliasing_Between_Parameters` | Reliability | High | Reports calls that pass the same object or component as two actual parameters when at least one corresponding formal is written. | `parameters_aliasing`, `potential_parameters_aliasing` |
| SPARK | `Missing_Loop_Variant` | Maintainability | Medium | Reports loops with a `Loop_Invariant` pragma but no `Loop_Variant` pragma. | — |
| SPARK | `Known_Discriminant_Check_Failure` | Reliability | High | Reports accesses to a variant-part component that a statically known discriminant constraint provably excludes. | — |
| SPARK | `Known_Enum_Val_Failure` | Reliability | High | Reports `'Val` attribute calls whose statically known argument is outside the enumeration type's literal positions. | — |
| SPARK | `Known_Value_Conversion_Failure` | Reliability | High | Reports `'Value` attribute calls whose static string literal argument can never denote a value of the prefix integer or enumeration type. | — |
| SPARK | `Potentially_Blocking_Operation` | Reliability | High | Reports entry calls, delay statements, and calls transitively reaching them from a protected operation. | — |
| Automotive | `No_Dynamic_Allocation` | Reliability | High | Reports allocators. | — |
| Automotive | `Restricted_Access_Type` | Reliability | High | Reports access-to-object type definitions. | — |
| Automotive | `No_Explicit_Dereference` | Reliability | High | Reports explicit `.all` dereferences. | — |
| Automotive | `No_Unchecked_Deallocation` | Security | High | Reports semantic instantiations of `Ada.Unchecked_Deallocation`. | — |
| Automotive | `No_Tasking` | Reliability | High | Reports task declarations. | — |
| Automotive | `No_Rendezvous` | Reliability | High | Reports entry declarations and accept statements. | — |
| Automotive | `No_Select` | Reliability | High | Reports selective, timed, conditional, and asynchronous select forms. | — |
| Automotive | `No_Requeue` | Reliability | High | Reports requeue statements. | — |
| Automotive | `No_Asynchronous_Transfer` | Reliability | High | Reports asynchronous select/abortable-part constructs. | — |
| Automotive | `Exception_Propagation` | Reliability | High | Reports calls that may propagate a direct or transitive explicit exception when the enclosing subprogram has no handler boundary. | `exception_propagation_from_callbacks`, `exception_propagation_from_export`, `exception_propagation_from_tasks` |
| Automotive | `No_Dispatching_Call` | Reliability | High | Reports semantically resolved dispatching calls. | — |
| Automotive | `No_Classwide_Type` | Reliability | High | Reports class-wide subtype marks. | — |
| Automotive | `No_Controlled_Type` | Reliability | High | Reports derivation from controlled or limited-controlled types. | `controlled_type_declarations` |
| Automotive | `Complete_Initialization` | Reliability | High | Reports objects and record components without explicit initialization. | — |
| Automotive | `Volatile_Atomic_Consistency` | Reliability | High | Reports volatile declarations lacking an atomic or full-access policy. | — |
| Automotive | `Representation_Clause_Policy` | Reliability | Medium | Requires every explicit representation clause to receive target-specific review. | — |
| Automotive | `Library_Level_Initialization` | Reliability | High | Reports library-level initializers containing calls. | `calls_outside_elaboration` |
| Automotive | `Generic_Instantiation_Limit` | Maintainability | Medium | Reports units exceeding the configured generic-instantiation limit. | — |
| Automotive | `Dependency_Limit` | Maintainability | Medium | Reports units exceeding the configured with-clause limit. | `too_many_dependencies` |
| Automotive | `Circular_Package_Dependency` | Maintainability | Medium | Reports groups of analyzed units whose with clauses form a dependency cycle. | — |
| Duplication | `Duplicate_Subprogram` | Maintainability | Medium | Reports subprogram bodies, anywhere in the analyzed project, textually identical to another subprogram's. | — |
| Automotive | `Naming_Convention` | Maintainability | Low | Reports one-character identifiers except loop indices and enumeration literals. | `min_identifier_length` |
| Automotive | `No_Compiler_Extensions` | Maintainability | High | Reports implementation-defined pragmas, including extension-enabling pragmas. | — |
| Automotive | `No_Runtime_Check_Suppression` | Reliability | High | Reports `Suppress`, `Suppress_All`, and check policies that ignore or disable Ada run-time checks. | — |
| DO-178C support | `Missing_Requirement_Trace` | Reliability | High | Reports subprogram bodies without a nearby low-level requirement identifier. | — |
| DO-178C support | `Malformed_Requirement_Trace` | Maintainability | Medium | Reports requirement annotations with no identifier. | — |
| DO-178C support | `Suppression_Without_Rationale` | Maintainability | High | Reports analyzer suppressions that do not record a reviewable rationale. | — |
| Safety | `Use_After_Free` | Security | High | Reports a local access object read after `Ada.Unchecked_Deallocation` frees it, with no intervening assignment. | — |
| Safety | `Double_Free` | Security | High | Reports a local access object passed to `Ada.Unchecked_Deallocation` a second time, with no intervening assignment. | — |
| Data flow | `Unclosed_File_Handle` | Reliability | Medium | Reports a local `Ada.Text_IO`/`Ada.Streams.Stream_IO` file opened with `Open`/`Create` and not demonstrably closed on every normal-return or exception-handler path. | — |
| Data flow | `Unused_With_Clause` | Maintainability | Low | Reports a with clause naming a unit never referenced elsewhere in the file. | — |
| Restricted construct | `No_Use_Package_Clause` | Maintainability | Low | Reports use clauses that make a whole package's declarations directly visible (use type clauses are not reported). | `use_package_clauses` |
| Restricted construct | `Others_In_Case_Statement` | Reliability | Low | Reports an others choice in a case statement alternative, which hides values added to the selecting type later. | `others_in_case_statements` |
| Restricted construct | `Others_In_Exception_Handler` | Reliability | Medium | Reports an others choice in an exception handler, which catches exceptions the code never anticipated. | `others_in_exception_handlers` |
| Restricted construct | `Others_In_Aggregate` | Reliability | Low | Reports an others choice in an aggregate, except the plain (others => X) form and an others choice following exactly one single-value association. | `others_in_aggregates` |
| Restricted construct | `Unnamed_Exit` | Maintainability | Low | Reports exit statements that do not name the loop they leave even though that loop is named. | `unnamed_exits` |
| Restricted construct | `Unnamed_Block_Or_Loop` | Maintainability | Low | Reports block statements, and loops that nest or are nested in another loop, that carry no statement identifier. | `unnamed_blocks_and_loops` |
| Restricted construct | `Implicit_In_Mode` | Maintainability | Low | Reports parameter specifications that rely on the default in mode instead of writing it (access parameters are not reported). | `implicit_in_mode_parameters` |
| Restricted construct | `Function_Out_Parameter` | Reliability | Medium | Reports functions that declare an out or in out parameter. | `function_out_parameters` |
| Restricted construct | `Raising_Predefined_Exception` | Reliability | Medium | Reports raise statements that explicitly raise Constraint_Error, Program_Error, Storage_Error, Tasking_Error or Numeric_Error, directly or through a renaming. | `raising_predefined_exceptions` |
| Restricted construct | `Anonymous_Array_Type` | Maintainability | Low | Reports object declarations whose type is an anonymous array type. | `anonymous_arrays` |
| Restricted construct | `Enumeration_Representation_Clause` | Maintainability | Low | Reports enumeration representation clauses. | `enumeration_representation_clauses` |
| Restricted construct | `Relative_Delay` | Reliability | Medium | Reports delay statements that are relative rather than 'delay until'. | `relative_delay_statements` |
| Restricted construct | `No_Block_Statement` | Maintainability | Low | Reports block statements. | `blocks` |
| Restricted construct | `Global_Variable` | Maintainability | Medium | Reports variables declared in the visible or private part of a library-level package specification. | `global_variables` |
| Restricted construct | `Predefined_Numeric_Type` | Reliability | Medium | Reports explicit references to the predefined numeric subtypes of package Standard (Integer, Natural, Positive, Float, Duration and their Short/Long variants), whose ranges and precision depend on the target. | `predefined_numeric_types` |
| Restricted construct | `Abstract_Type_Declaration` | Maintainability | Low | Reports declarations of abstract types. | `abstract_type_declarations` |
| Restricted construct | `Exit_From_Conditional_Loop` | Maintainability | Low | Reports exit statements that leave a for or while loop. | `exits_from_conditional_loops` |
| Restricted construct | `Expanded_Loop_Exit_Name` | Maintainability | Low | Reports exit statements that name the loop with an expanded name. | `expanded_loop_exit_names` |
| Restricted construct | `Conditional_Expression` | Maintainability | Low | Reports if expressions and case expressions. | `conditional_expressions` |
| Restricted construct | `Quantified_Expression` | Maintainability | Low | Reports quantified expressions. | `quantified_expressions` |
| Restricted construct | `Membership_Test` | Maintainability | Low | Reports membership tests. | `membership_tests` |
| Restricted construct | `Generic_In_Out_Object` | Reliability | Medium | Reports generic formal objects of mode in out. | `generic_in_out_objects` |
| Restricted construct | `Generic_In_Subprogram` | Maintainability | Low | Reports generic units declared inside a subprogram body. | `generics_in_subprograms` |
| Restricted construct | `Local_Use_Clause` | Maintainability | Low | Reports use clauses, including use type clauses, that are not part of a context clause. | `local_use_clauses` |
| Restricted construct | `Library_Level_Subprogram` | Maintainability | Low | Reports subprogram bodies and subprogram instantiations that are library units. | `library_level_subprograms` |
| Restricted construct | `Multiple_Protected_Entries` | Reliability | Medium | Reports a second or later entry declared in the same part of a protected definition. | `multiple_entries_in_protected_definitions` |
| Restricted construct | `Non_Tagged_Derived_Type` | Maintainability | Low | Reports derived type definitions that are neither a record extension nor a private extension. | `non_tagged_derived_types` |
| Restricted construct | `No_Closing_Name` | Maintainability | Low | Reports subprogram, package, task and protected units whose end does not repeat the unit name. | `no_closing_names` |
| Restricted construct | `Operator_Renaming` | Maintainability | Low | Reports subprogram renaming declarations that rename an operator. | `operator_renamings` |
| Restricted construct | `Overloaded_Operator` | Maintainability | Low | Reports declarations, bodies without a separate declaration, and instantiations that define an operator symbol. | `overloaded_operators` |
| Restricted construct | `Single_Value_Enumeration_Type` | Maintainability | Low | Reports enumeration types that define a single literal. | `single_value_enumeration_types` |
| Restricted construct | `Unconstrained_Array_Type` | Reliability | Low | Reports unconstrained array type definitions other than generic formal array types. | `unconstrained_arrays` |
| Restricted construct | `Unconditional_Exit` | Maintainability | Low | Reports exit statements that have no when condition. | `unconditional_exits` |
| Restricted construct | `Binary_Case_Statement` | Maintainability | Low | Reports case statements with exactly two alternatives of one choice each. | `binary_case_statements` |
| Restricted construct | `Concurrent_Interface` | Maintainability | Low | Reports task, protected and synchronized interface types. | `concurrent_interfaces` |
| Restricted construct | `Anonymous_Access_Type` | Reliability | Medium | Reports objects and components declared with an anonymous access-to-object type. | `anonymous_access` |
| Restricted construct | `Renaming_Declaration` | Maintainability | Low | Reports renaming declarations. | `renamings` |
| Restricted construct | `Separate_Unit` | Maintainability | Low | Reports subunits (separate bodies). | `separates` |
| Restricted construct | `Array_Slice` | Maintainability | Low | Reports array slices. | `slices` |
| Restricted construct | `Number_Declaration` | Maintainability | Low | Reports named number declarations. | `number_declarations` |
| Restricted construct | `Local_Package` | Maintainability | Low | Reports package specifications declared inside another package specification. | `local_packages` |
| Restricted construct | `Declaration_In_Block` | Maintainability | Low | Reports block statements with a declarative part, unless that part holds a use clause or a pragma. | `declarations_in_blocks` |
| Restricted construct | `Outer_Loop_Exit` | Maintainability | Medium | Reports named exit statements that leave a loop other than the innermost enclosing one. | `outer_loop_exits` |
| Restricted construct | `Exit_Without_Loop_Name` | Maintainability | Low | Reports exit statements that do not name a loop. | `exit_statements_with_no_loop_name` |
| Restricted construct | `Expression_Function` | Maintainability | Low | Reports expression functions declared in a package specification. | `expression_functions` |
| Restricted construct | `Size_Attribute_For_Type` | Reliability | Medium | Reports the Size attribute applied to a type or subtype outside a representation item. | `size_attribute_for_types` |
| Restricted construct | `Enumeration_Range_In_Case_Statement` | Reliability | Low | Reports case statements over an enumeration type with a choice written as a range, a subtype name or a Range attribute. | `enumeration_ranges_in_case_statements` |
| Style | `Missing_Header` | Maintainability | Low | Reports compilation units whose text does not start with the header given by the header parameter (\n stands for a line break); nothing is reported when no header is configured. | `headers` |
| Style | `Lowercase_Keyword` | Maintainability | Low | Reports reserved words that are not written entirely in lower case. | `lowercase_keywords` |
| Style | `Printable_ASCII` | Maintainability | Low | Reports comments, literals and white space that contain a character outside printable ASCII, including horizontal tabs. | `printable_ascii` |
| Style | `End_Of_Line_Comment` | Maintainability | Low | Reports comments that share a line with code. | `end_of_line_comments` |
| Style | `Annotated_Comment` | Maintainability | Low | Reports comments that carry one of the annotation markers listed in the s parameter, such as '#hide'; nothing is reported when no marker is configured. | `annotated_comments` |
| Complexity | `Maximum_Lines` | Maintainability | Medium | Reports source files with more lines than the n parameter allows (default 10000). | `maximum_lines` |
| Complexity | `Maximum_Identifier_Length` | Maintainability | Low | Reports defining names, other than enumeration literals, longer than the n parameter allows (default 20). | `max_identifier_length` |
| Style | `Numeric_Format` | Maintainability | Low | Reports numeric literals that are not written with upper-case letters and with digits grouped by underscores: by three for decimal and base 8 or 10, by four for base 2 or 16; other bases are reported. | `numeric_format` |
| Style | `Parameters_Out_Of_Order` | Maintainability | Low | Reports parameters declared before a parameter that belongs earlier in the order in, access, in out, out, defaulted in. | `parameters_out_of_order` |
| Complexity | `Maximum_Subprogram_Lines` | Maintainability | Medium | Reports subprogram bodies whose statement part spans more lines than the n parameter allows (default 1000). | `maximum_subprogram_lines` |
| Complexity | `Maximum_Out_Parameters` | Maintainability | Medium | Reports subprograms with more out and in out parameters than the n parameter allows (default 3). | `maximum_out_parameters` |
| Complexity | `Default_Parameter` | Reliability | Low | Reports parameter lists with more defaulted parameters than the n parameter allows (default 0). | `default_parameters` |
| Style | `Forbidden_Identifier` | Maintainability | Low | Reports declarations of a name listed in the forbidden parameter (comma-separated, case-insensitive); nothing is reported when no name is configured. | `name_clashes` |
| Style | `Uncommented_Begin` | Maintainability | Low | Reports the begin of a subprogram, package, entry or task body with declarations that is not directly followed by a comment naming the unit. | `uncommented_begin` |
| Style | `Uncommented_Begin_In_Package_Body` | Maintainability | Low | Reports the begin of a package body with declarations that is not directly followed by a comment naming the package. | `uncommented_begin_in_package_bodies` |
| Style | `Uncommented_End_Record` | Maintainability | Low | Reports record definitions spanning at least as many lines as the n parameter (default 10) whose end record is not followed on the same line by a comment naming the type. | `uncommented_end_record` |
| Style | `Object_Declaration_Out_Of_Order` | Maintainability | Low | Reports object declarations in a library unit body that directly follow a program unit declaration. | `object_declarations_out_of_order` |
| Style | `One_Construct_Per_Line` | Maintainability | Low | Reports statements, declarations, clauses and pragmas that share a line with other code. | `one_construct_per_line` |
| Complexity | `Logical_SLOC` | Maintainability | Medium | Reports packages, subprograms, tasks and protected units with more statements and declarations than the n parameter allows (default 200). | `metrics_lsloc` |
| Coding standard | `Positional_Parameter` | Maintainability | Low | Reports positional parameter associations in calls to subprograms with two or more parameters (three for prefixed calls), unless the actual is the only one given and stands for the single parameter without a default; with the all parameter set to true, every positional association is reported. | `positional_parameters` |
| Coding standard | `Positional_Defaulted_Parameter` | Maintainability | Low | Reports positional actuals passed to a parameter that has a default value. | `positional_actuals_for_defaulted_parameters` |
| Coding standard | `Positional_Generic_Parameter` | Maintainability | Low | Reports positional associations in generic instantiations, unless the generic has a single formal parameter. | `positional_generic_parameters` |
| Coding standard | `Positional_Component` | Maintainability | Low | Reports array and record aggregates that have a positional component association. | `positional_components` |
| Coding standard | `Non_Qualified_Aggregate` | Maintainability | Low | Reports aggregates of a named type that are not the operand of a qualified expression, other than subaggregates and aggregates nested in such an aggregate. | `non_qualified_aggregates` |
| Coding standard | `Nested_Subprogram` | Maintainability | Low | Reports subprograms declared inside a subprogram, task or entry body. | `nested_subprograms` |
| Coding standard | `Boolean_Relational_Operator` | Maintainability | Low | Reports predefined relational operators applied to Boolean operands. | `boolean_relational_operators` |
| Coding standard | `Fixed_Equality` | Reliability | Medium | Reports predefined equality and inequality operators applied to fixed-point operands. | `fixed_equality_checks` |
| Coding standard | `Unconstrained_Array_Return` | Reliability | Medium | Reports functions whose result subtype is an unconstrained array type. | `unconstrained_array_returns` |
| Coding standard | `Deriving_From_Predefined_Type` | Reliability | Low | Reports derived types, other than type extensions, whose parent type is declared in Standard, System, Ada or Interfaces. | `deriving_from_predefined_type` |
| Coding standard | `Visible_Component` | Maintainability | Medium | Reports record types and record extensions whose components are visible in the specification of a non-private library package; with the tagged_only parameter set to true, only tagged types are reported. | `visible_components` |
| Coding standard | `Object_Of_Anonymous_Type` | Maintainability | Low | Reports objects of an anonymous array or access type declared in a package. | `objects_of_anonymous_types` |
| Coding standard | `Numeric_Indexing` | Maintainability | Low | Reports integer literals used as array index values. | `numeric_indexing` |
| Coding standard | `Local_Instantiation` | Maintainability | Low | Reports generic instantiations made in a subprogram, task, entry, protected body or block. | `local_instantiations` |
| Coding standard | `Explicit_Inlining` | Maintainability | Low | Reports subprograms that carry the Inline aspect or pragma. | `explicit_inlining` |
| Coding standard | `Pos_On_Enumeration_Type` | Maintainability | Low | Reports the Pos attribute applied to an enumeration type. | `pos_on_enumeration_types` |
| Coding standard | `Implicit_Small` | Reliability | Medium | Reports ordinary fixed-point type declarations without a Small specification. | `implicit_small_for_fixed_point_types` |
| Coding standard | `Ada05_Formal_Package` | Maintainability | Low | Reports formal packages that mix box and explicit actuals, a form introduced by Ada 2005. | `ada05_formal_packages` |
| Coding standard | `Separate_Numeric_Error_Handler` | Reliability | Low | Reports exception handlers that name Constraint_Error without Numeric_Error, or the reverse. | `separate_numeric_error_handlers` |
| Coding standard | `Forbidden_Aspect` | Maintainability | Medium | Reports aspects listed in the forbidden parameter (or every aspect when the all parameter is true) and not listed in the allowed parameter; nothing is reported when neither is configured. | `forbidden_aspects` |
| Coding standard | `Forbidden_Attribute` | Maintainability | Medium | Reports attributes listed in the forbidden parameter (or every attribute when the all parameter is true) and not listed in the allowed parameter; nothing is reported when neither is configured. | `forbidden_attributes` |
| Coding standard | `Forbidden_Dependence` | Maintainability | Medium | Reports with clauses that name a unit listed in the unit_names parameter; nothing is reported when no unit is configured. | `no_dependence` |
| Coding standard | `One_Tagged_Type_Per_Package` | Maintainability | Low | Reports package specifications whose visible part declares more than one tagged type. | `one_tagged_type_per_package` |
| Coding standard | `Explicit_Full_Discrete_Range` | Maintainability | Low | Reports ranges written T'First .. T'Last. | `explicit_full_discrete_ranges` |
| Coding standard | `Universal_Range` | Reliability | Low | Reports loop ranges and index constraints whose bounds are both integer literals or named numbers. | `universal_ranges` |
| Coding standard | `Missing_Others_Handler` | Reliability | Medium | Reports exception handler parts without an others choice, in the scopes switched on by the all_handlers, subprogram and task parameters; nothing is reported when none is set. | `no_others_in_exception_handlers` |
| Object orientation | `Default_Value_For_Record_Component` | Maintainability | Low | Reports record components declared with a default value. | `default_values_for_record_components` |
| Object orientation | `Uninitialized_Global_Variable` | Reliability | Medium | Reports variables declared outside any subprogram, task, entry, protected body or block without an initial value. | `uninitialized_global_variables` |
| Complexity | `Deep_Library_Hierarchy` | Maintainability | Low | Reports packages and package instantiations with more ancestor units than the n parameter allows (default 3). | `deep_library_hierarchy` |
| Complexity | `Deeply_Nested_Generic` | Maintainability | Low | Reports generic units nested in more generic units than the n parameter allows (default 5). | `deeply_nested_generics` |
| Complexity | `Overly_Nested_Scope` | Maintainability | Medium | Reports packages, subprograms, tasks, protected units, entries and blocks nested in more such scopes than the n parameter allows (default 10). | `overly_nested_scopes` |
| Object orientation | `Specific_Type_Invariant` | Reliability | Medium | Reports Type_Invariant aspects on tagged types; such an invariant is not inherited by extensions. | `specific_type_invariants` |
| Object orientation | `Volatile_Object_Without_Address` | Reliability | Medium | Reports objects that are volatile, or of a volatile type, and have no address specification. | `volatile_objects_without_address_clauses` |
| Complexity | `Too_Many_Primitives` | Maintainability | Medium | Reports tagged types declared in the visible part of a package with more primitive operations than the n parameter allows (default 5). | `too_many_primitives` |
| Complexity | `Deep_Inheritance_Hierarchy` | Maintainability | Medium | Reports tagged types whose derivation chain is longer than the n parameter allows (default 2). | `deep_inheritance_hierarchies` |
| Complexity | `Too_Many_Parents` | Maintainability | Medium | Reports tagged, task and protected types that derive, directly or not, from more types and interfaces than the n parameter allows (default 5). | `too_many_parents` |
| Object orientation | `Specific_Pre_Post` | Reliability | Medium | Reports primitive operations of tagged types with a Pre or Post aspect that is not class-wide. | `specific_pre_post` |
| Object orientation | `Constructor` | Maintainability | Low | Reports primitive functions of a tagged type that return the type and take no parameter of it. | `constructors` |
| Object orientation | `Misnamed_Controlling_Parameter` | Maintainability | Low | Reports primitive operations of a tagged type whose first parameter is not a controlling parameter named This. | `misnamed_controlling_parameters` |
| Object orientation | `Non_Component_In_Barrier` | Reliability | Medium | Reports entry barriers that refer to an object, a parameter or a component that does not belong to the protected object. | `non_component_in_barriers` |
| Style | `Identifier_Casing` | Maintainability | Low | Reports defining names whose casing differs from the scheme (upper, lower or mixed) given by the type, enum, constant, exception and others parameters; the exclude parameter lists words with a fixed spelling. Nothing is reported for a kind whose scheme is not configured. | `identifier_casing` |
| Style | `Identifier_Prefixes` | Maintainability | Low | Reports defining names that lack the prefix required for their kind by the type, concurrent, access, class_access, subprogram_access, derived, constant, exception and enum parameters, or that carry a prefix reserved for another kind (unless the exclusive parameter is false). | `identifier_prefixes` |
| Style | `Identifier_Suffixes` | Maintainability | Low | Reports defining names that lack the suffix required for their kind by the type_suffix, access_suffix, access_access_suffix, class_access_suffix, class_subtype_suffix, constant_suffix, renaming_suffix, access_obj_suffix and interrupt_suffix parameters; the default parameter selects _T, _A, _C and _R. | `identifier_suffixes` |
| Representation | `Constant_Overlay` | Reliability | High | Reports address specifications that make a variable, or a volatile object, overlay a constant object. | `constant_overlays` |
| Representation | `Non_Constant_Overlay` | Reliability | High | Reports address specifications that make a constant or a non-volatile object overlay a variable that can change underneath it. | `non_constant_overlays` |
| Representation | `Nonoverlay_Address_Specification` | Reliability | Medium | Reports address specifications of objects whose address is not the Address of another object. | `nonoverlay_address_specifications` |
| Representation | `Not_Imported_Overlay` | Reliability | High | Reports objects that overlay another object without being imported, so that default initialization may overwrite the overlaid object. | `not_imported_overlays` |
| Representation | `Address_Of_Non_Volatile_Object` | Reliability | Medium | Reports the Address attribute applied to a variable that is not volatile, atomic or shared. | `address_attribute_for_non_volatile_objects` |
| Representation | `Access_To_Local_Object` | Reliability | High | Reports the Access attribute applied to an object, or part of an object, that is a parameter or is declared in a subprogram, task, entry, protected body or block. | `access_to_local_objects` |
| Representation | `Bit_Record_Without_Layout` | Reliability | Medium | Reports packed record types with a modular component or discriminant and no record representation clause. | `bit_records_without_layout_definition` |
| Representation | `No_Scalar_Storage_Order` | Reliability | Medium | Reports record types with a record representation clause, their own or inherited, that do not specify Scalar_Storage_Order. | `no_scalar_storage_order_specified` |
| Representation | `Incomplete_Representation_Specification` | Reliability | Medium | Reports record types with a record representation clause that do not also have both a Size and a Pack specification. | `incomplete_representation_specifications` |
| Representation | `Misplaced_Representation_Item` | Maintainability | Low | Reports representation clauses and representation pragmas that do not directly follow the declaration they apply to, other representation items of the same entity aside. | `misplaced_representation_items` |
| Representation | `Representation_Specification` | Maintainability | Low | Reports record and enumeration representation clauses and declarations that carry a representation aspect; with the record_rep_clauses_only parameter set to true, only record representation clauses are reported. | `representation_specifications` |
| Representation | `Unchecked_Address_Conversion` | Security | High | Reports instantiations of Ada.Unchecked_Conversion from System.Address to an access type; with the all parameter set to true, any instantiation involving System.Address is reported. | `unchecked_address_conversions` |
| Representation | `Unchecked_Conversion_As_Actual` | Security | Medium | Reports calls to an instance of Ada.Unchecked_Conversion used as an actual parameter or as a default parameter value. | `unchecked_conversions_as_actuals` |
| Simplification | `Use_Simple_Loop` | Maintainability | Low | Reports while loops whose condition is statically true. | `use_simple_loops` |
| Simplification | `Use_While_Loop` | Maintainability | Low | Reports plain loops whose first statement is an exit from that loop. | `use_while_loops` |
| Simplification | `Use_For_Loop` | Maintainability | Low | Reports while loops that test a local counter and increment or decrement it by one as their last statement, where the counter is not otherwise written and not used after the loop. | `use_for_loops` |
| Simplification | `Use_Range` | Maintainability | Low | Reports T'First .. T'Last ranges, and T'Range of a discrete subtype used as a loop range, a membership choice or a case choice. | `use_ranges` |
| Simplification | `Use_Membership` | Maintainability | Low | Reports Boolean expressions that only compare one variable with several values or ranges; with the short_circuit parameter set to true, 'or else' and 'and then' forms are reported too. | `use_memberships` |
| Simplification | `Use_If_Expression` | Maintainability | Low | Reports if statements with an else part whose every branch is a single return statement, or a single assignment to the same target. | `use_if_expressions` |
| Simplification | `Use_Case_Statement` | Maintainability | Low | Reports if statements with elsif parts whose conditions all compare the same discrete variable or component with a static value. | `use_case_statements` |
| Simplification | `Use_Record_Aggregate` | Maintainability | Low | Reports consecutive assignments that set every component of an untagged record without discriminants one by one. | `use_record_aggregates` |
| Simplification | `Use_For_Of_Loop` | Maintainability | Low | Reports for loops over the Range of a one-dimensional array that use the loop parameter only to index that array. | `use_for_of_loops` |
| Simplification | `Use_Array_Slice` | Maintainability | Low | Reports for loops whose only statement assigns to an array component indexed by the loop parameter a static value or the same-indexed component of another array. | `use_array_slices` |
| Design | `Discriminated_Record` | Maintainability | Low | Reports type declarations with a known discriminant part, other than private types and derived types that only pass their discriminants on to the parent type. | `discriminated_records` |
| Design | `Anonymous_Subtype` | Maintainability | Low | Reports constrained subtype indications, ranges and Range attributes used where a named subtype could be, other than in a subtype declaration, a type definition or a constraint that depends on a discriminant. | `anonymous_subtypes` |
| Design | `No_Explicit_Real_Range` | Reliability | Medium | Reports floating-point and fixed-point types and subtypes that neither declare nor inherit an explicit range. | `no_explicit_real_range` |
| Design | `Direct_Equality` | Reliability | Medium | Reports equality and inequality tests on the objects listed, by fully qualified name, in the actuals parameter; nothing is reported when no object is configured. | `direct_equalities` |
| Design | `Membership_For_Validity` | Reliability | Medium | Reports membership tests of an object in its own subtype, written as the subtype mark, T'Range or T'First .. T'Last. | `membership_for_validity` |
| Design | `Positional_Defaulted_Generic_Parameter` | Maintainability | Low | Reports positional actuals passed to a generic formal object or subprogram that has a default. | `positional_actuals_for_defaulted_generic_parameters` |
| Complexity | `Deeply_Nested_Instantiation` | Maintainability | Medium | Reports instantiations of a generic whose declaration contains an instantiation, to a depth beyond the n parameter (default 3). | `deeply_nested_instantiations` |
| Complexity | `Too_Many_Generic_Dependencies` | Maintainability | Medium | Reports with clauses naming a generic unit that itself depends on generic units through its with clauses, to a depth beyond the n parameter (default 3). | `too_many_generic_dependencies` |
| Design | `Raising_External_Exception` | Reliability | Medium | Reports raise statements in a library package that raise an exception which is neither predefined, nor handled in the same unit, nor declared in the visible part of that package. | `raising_external_exceptions` |
| Design | `Final_Package` | Maintainability | Medium | Reports child packages of a package marked with Annotate => (GNATcheck, Final). | `final_package` |
| Design | `Direct_Call_To_Primitive` | Reliability | Medium | Reports statically bound calls to a primitive operation of a tagged type, other than a call to the parent type's operation from its own overriding. | `direct_calls_to_primitives` |
| Design | `Downward_View_Conversion` | Reliability | Medium | Reports view conversions from a tagged type, or an access to one, to a type derived from it. | `downward_view_conversions` |
| Design | `Specific_Parent_Type_Invariant` | Reliability | Medium | Reports type extensions whose parent type, or one of its ancestors, has a Type_Invariant aspect that is not class-wide. | `specific_parent_type_invariant` |
| Design | `No_Inherited_Classwide_Pre` | Reliability | Medium | Reports overriding primitive operations whose overridden root declaration has no Pre'Class aspect. | `no_inherited_classwide_pre` |
| Coding standard | `Non_SPARK_Attribute` | Maintainability | Low | Reports attributes outside the SPARK 2005 attribute subset. | `non_spark_attributes` |
| Coding standard | `Nested_Path` | Maintainability | Low | Reports statements kept inside one branch of an if statement whose other branch always leaves it by return, raise, exit or goto. | `nested_paths` |
| Complexity | `Essential_Complexity` | Maintainability | Medium | Reports subprogram bodies whose essential complexity (one plus the compound statements left early by a return, raise, exit or goto) exceeds the n parameter (default 3). | `metrics_essential_complexity` |
| Complexity | `Maximum_Expression_Complexity` | Maintainability | Medium | Reports expressions with more names, literals, conditional and quantified expressions and aggregates than the n parameter allows (default 10). | `maximum_expression_complexity` |
| Coding standard | `Improperly_Located_Instantiation` | Maintainability | Low | Reports generic instantiations in a library package specification or in a subprogram body. | `improperly_located_instantiations` |
| Coding standard | `Function_Style_Procedure` | Maintainability | Low | Reports procedures with a single out parameter of a non-limited type, no in out parameter and no Global aspect. | `function_style_procedures` |
| Coding standard | `Exception_As_Control_Flow` | Reliability | Medium | Reports raise statements whose exception is handled in the same subprogram body. | `exceptions_as_control_flow` |
| Complexity | `Complex_Inlined_Subprogram` | Maintainability | Medium | Reports inlined subprograms whose body declares a nested unit, contains a loop, case or if statement, or has more statements than the n parameter allows (default 5). | `complex_inlined_subprograms` |
| Coding standard | `Call_In_Exception_Handler` | Reliability | Medium | Reports exception handlers that call a subprogram listed, by fully qualified name, in the subprograms parameter; nothing is reported when none is configured. | `calls_in_exception_handlers` |
| Coding standard | `Ada_2022_In_Ghost_Code` | Maintainability | Medium | Reports Ada 2022 constructs used outside ghost code and generic units: Image of a composite object, reduction, declare expressions, target names, delta and iterated aggregates, user-defined literals and aspects on parameters and formal subprograms. | `ada_2022_in_ghost_code` |
| Coding standard | `Actual_Parameter` | Reliability | Medium | Reports calls that pass a listed object to a listed formal parameter; the forbidden parameter holds comma-separated subprogram:formal:object triples of fully qualified names. Nothing is reported when none is configured. | `actual_parameters` |
| Coding standard | `Same_Logic` | Reliability | Medium | Reports conditions joined by one logical operator in which the same operand appears twice. | `same_logic` |
| Coding standard | `Suspicious_Equality` | Reliability | High | Reports conditions that test the same name for equality with two literals joined by and, or for inequality with two literals joined by or. | `suspicious_equalities` |
| Coding standard | `Non_Visible_Exception` | Reliability | Medium | Reports exceptions declared in a subprogram body, task body or block that the same scope does not handle, and handlers that raise or re-raise such a local exception. | `non_visible_exceptions` |
| Coding standard | `Outbound_Protected_Assignment` | Reliability | Medium | Reports assignments in a protected body to an object declared outside the protected unit. | `outbound_protected_assignments` |
| Coding standard | `Outside_Reference_From_Subprogram` | Maintainability | Medium | Reports references in a nested subprogram to a local object or a parameter of an enclosing subprogram. | `outside_references_from_subprograms` |
| Coding standard | `Variable_Scoping` | Maintainability | Low | Reports local variables without an initial value that are used only inside one declare block of the subprogram, outside any loop. | `variable_scoping` |
| Coding standard | `Out_Parameter_Read_In_Exception_Handler` | Reliability | High | Reports out and in out actuals of a call that an exception handler of an enclosing block reads; the call may have raised before assigning them. | `out_parameter_read_in_exception_handler` |
| Coding standard | `Predicate_Testing` | Reliability | Low | Reports membership tests naming a subtype with a predicate, and Valid attributes of an object of such a subtype. | `predicate_testing` |
| Coding standard | `Profile_Discrepancy` | Maintainability | Low | Reports subprogram and entry bodies whose parameter profile is written differently from their declaration: grouping of names, explicit modes or the spelling of type names. | `profile_discrepancies` |
| Coding standard | `Side_Effect_Parameter` | Reliability | Medium | Reports calls and instantiations whose actuals call the same function, listed by fully qualified name in the functions parameter, more than once; nothing is reported when none is configured. | `side_effect_parameters` |
| Coding standard | `Use_Clause` | Maintainability | Low | Reports each package name in a use clause; the allowed parameter exempts packages by fully qualified name and exempt_operator_packages those that declare only operators. | `use_clauses` |
| Coding standard | `Unavailable_Body_Call` | Reliability | Low | Reports calls to a subprogram whose body is not among the sources the analyzer can see, and with indirect_calls also calls through an access value. | `unavailable_body_calls` |
| Coding standard | `Deeply_Nested_Inlining` | Maintainability | Low | Reports inlined subprograms that call inlined subprograms to a depth above the n parameter (3 by default). | `deeply_nested_inlining` |
| Coding standard | `Integer_Type_As_Enumeration` | Maintainability | Low | Reports integer types that no analyzed source uses in arithmetic, converts, derives from, declares a subtype of or passes to a generic instantiation. | `integer_types_as_enum` |
| Coding standard | `Same_Instantiation` | Maintainability | Low | Reports generic package instantiations that repeat another instantiation of the same generic with the same actual parameters among the analyzed sources. | `same_instantiations` |
| Coding standard | `Compiler_Warning` | Reliability | Medium | Reports the GNAT warnings selected by the options parameter (the letters of a -gnatw switch), found by compiling the sources for semantic checks only; nothing is reported when none is configured. | `warnings` |
| Coding standard | `Compiler_Style_Check` | Maintainability | Low | Reports the GNAT style messages selected by the options parameter (the letters of a -gnaty switch), found by compiling the sources for semantic checks only; nothing is reported when none is configured. | `style_checks` |
| Coding standard | `Compiler_Restriction` | Reliability | Medium | Reports violations of the language restrictions listed in the restrictions parameter, as GNAT detects them when compiling the sources for semantic checks only; nothing is reported when none is configured. | `restrictions` |

</details>

<details>
<summary><strong>Read the analysis and bounded-verification model</strong></summary>

<br>

Every check also carries a SonarQube-style classification: a **Software
Quality** it primarily affects (`Security`, `Reliability`, or
`Maintainability`) and a **Severity** (`Blocker`, `High`, `Medium`, or
`Low`). This is the analyzer's own judgment applying SonarQube's Clean
Code taxonomy to Ada constructs, not an imported SonarQube ruleset. The
classification is not just documentation — the tool surfaces it at
runtime:

- `-list-checks` prints each check's classification next to its name,
  e.g. `No_Recursion [Reliability/High] - ...`.
- Every reported violation includes a `quality:` line, e.g.
  `quality: Reliability (High)`.
- The end-of-run summary breaks violations down both by check (with its
  classification) and with dedicated "Violations by software quality"
  and "Violations by severity" rollups.

Diagnostics can also carry analysis-specific explanations and evidence.
Text output prints these as `why:` and `evidence:` lines when the producing
check supplies them. JSON findings expose `explanation` and `evidence`
fields, and SARIF results preserve both values in their `properties` object.
This is initially populated for contradictory conditions and selected
assertion, contract, range, index, overflow, and division-by-zero findings;
other checks retain their existing message and rule guidance while they are
migrated incrementally. In text output, individual proof obligations are only
listed with `-v`; without it, only the aggregate total and per-status counts
are printed. Running with `-v` prints each obligation's location, method,
explanation, abstract-state evidence, and source of imprecision. Tooling that
parses the text report for individual proof obligations must pass `-v`, or use
JSON/SARIF, which always include the full per-obligation data regardless of
verbosity. When scalar VC translation is unsupported, the obligation also
records a stable `reasonCode`, the exact `blockingExpression`, and an
`inlinePath` such as `Outer -> Inner` when the blocker occurs inside one or
more inlined expression functions. These appear as `reason:`, `blocked at:`,
and `inline path:` in verbose text; JSON exposes them directly on each proof
obligation, and SARIF carries the proof-obligation array in the run's
`properties` object. This provenance is preserved for assertions,
preconditions, postconditions, leading loop-invariant initialization and
preservation, and scalar range, index, integer-overflow, and division-by-zero
obligations whenever VC translation is attempted.

An initialization obligation is about one object. It is located where the
check is made: at a read of the object, or, for an `out` parameter that has
to be initialized when its subprogram returns, at the parameter itself. JSON
gives it a `subject` (`file`, `line`, `column`), the declaration of that
object, so that the obligations about one object can be gathered; that is
how GNATprove reports them ("initialization of X proved", once, at the
declaration).

The data-flow checks are intraprocedural and deliberately conservative.
`Dead_Store` follows resolved simple-object and array-component assignments in
source order, while `Overwritten_Assignment` stays within one statement list.
Textually equal dynamic components such as `Arr (I)` are equated only while no
intervening assignment or potentially mutating call changes `I`. The case
checks compare statically evaluable integer literals and ranges. These
boundaries keep findings predictable without requiring whole-program
control-flow analysis. Calls with resolved `out` formal parameters are treated
as writes to simple local-object actuals, so an output value that is never
consumed can be reported as a dead store. An `in out` actual also consumes its
incoming value and is not reduced to a pure-output dead store. Simple object
renames are resolved to their underlying declaration. Explicit access
dereferences remain outside the tracked target model because soundly equating
them requires points-to/alias analysis.
`No_Recursion` and `Function_Side_Effect` are likewise scoped conservatively:
`No_Recursion` only recognizes calls written with an explicit call syntax, and
`Function_Side_Effect` only flags assignments through a simple identifier
destination, to avoid false positives from unresolved or complex constructs.

A separate reusable control-flow graph models the structured sequential
subset used by `--verify`. It distinguishes normal and
exceptional exits, represents conditional and case branches, loop back and
exit edges, returns, raises, nested begin/declare blocks, and exception
handlers.
Implicit exceptions are conservatively over-approximated so later proof
analysis can remove infeasible exceptional edges without having to recover
missing paths. Unsupported transfers remain explicit and make the graph
incomplete. The verification interpreter propagates an abstract state to a
fixed point over this graph and applies interval widening at loop headers.

SPARK contracts participate in the flow-sensitive pass. A `Pre` aspect
narrows the abstract state at subprogram entry, and resolved formal-to-actual
parameter mappings allow a call with statically incompatible arguments to be
reported as a `Known_Precondition_Failure`. A `Post` aspect is evaluated using
the state established by the body, and facts it establishes for simple `out`
and `in out` parameters are transferred back to the caller. A postcondition
that the body makes statically false is reported as a
`Known_Postcondition_Failure`.

Assertion obligations are checked in the same abstract state. This covers
`Assert`, `Assert_And_Cut`, `Check`, and `Loop_Invariant` pragmas; a successful
assertion narrows the following state, while `Assume` narrows it without
creating an obligation. This mirrors useful local proof behavior from
GNATprove while remaining limited to conditions the abstract domain can
decide.

The same state is used for common Ada run-time proof obligations. Integer
initializations, assignments, and type conversions are compared with resolved
subtype bounds, and array subscripts are compared with the resolved index type
for each dimension. When interval reasoning is inconclusive in verification
mode, the scalar VC backend receives the expression, permitted bounds, and
path-sensitive symbolic state. It can prove containment, refute it, or retain
an unproved result with explicit unsupported-translation provenance.

Integer arithmetic is also checked against the resolved base type of the
operation. This models Ada's overflow check separately from the subtype check
performed by a later assignment and avoids reporting both obligations for the
same definitely overflowing expression. Division-by-zero obligations use the
same fallback to prove that a divisor is nonzero or refute that condition when
abstract ranges alone cannot decide it.

Division, integer arithmetic, range checks, index checks, selected discriminant
checks, assertions, preconditions, and postconditions reached by the
corresponding enabled checks are also recorded in a proof-obligation registry.
Text output summarizes their statuses, and JSON output includes both
`proofSummary` and `proofObligations`. Normal analysis records known failures
as `Definite_Error` and unresolved obligations as `Unproved`.

`--verify` enables a deliberately bounded scalar verification pass. Within a
complete supported control-flow and semantic boundary it classifies every
enumerated obligation as `Proved_Safe`, `Definite_Error`, `Unproved`, or
`Unreachable`. If that boundary is incomplete, affected obligations are
`Unsupported`; they are never silently treated as safe. `Proved_Safe` applies
only to that individual operation under the reported assumptions. It is not a
claim that a subprogram or program is correct, and this mode is not a
replacement for GNATprove.

Where the same sources are also proved with GNATprove, `--gnatprove-log`
sets what GNATprove said of each check beside the obligation that stands
for it, without changing anything AdaLang reports of its own; see
"GNATprove's verdicts beside AdaLang's" in the configuration reference.

The supported verification core is structured sequential integer and Boolean
code, statically bounded array indexing, initialization tracking, and simple
assertion, precondition, and postcondition facts. Calls to bodies present in
the analyzed source set use conservative interprocedural summaries for formal
writes, definite initialization on every normal return, and transitive
nonlocal writes. A summary is trusted only when its complete transitive call
boundary resolves; otherwise unknown effects retain the existing conservative
invalidation. Relational contract transfer still requires SPARK mode, an
explicit `Global` aspect, and non-aliased simple writable actuals. Access types
and explicit dereference, dispatching/class-wide behavior, tasking and
protected operations, floating-point proof, generic subprogram instantiations,
and unsupported transfers such as a `goto` back up to a label are outside the
proof boundary.

For assertions that remain unknown after abstract interpretation, `--verify`
also has a small scalar verification-condition backend. It translates
side-effect-free integer/Boolean formulas using literals, initialized
variables, `+`, `-`, `*`, comparisons, equality, and Boolean connectives to
SMT-LIB. Current exact values and interval bounds become assumptions. A
`Proved_Safe` or `Definite_Error` external-prover result is accepted only when
both CVC5 and Z3 independently return the same UNSAT conclusion. Missing
solvers, timeouts, disagreement, uninitialized operands, division/remainder,
calls, or unsupported syntax remain `Unproved`.

The backend locates `cvc5` and `z3` on `PATH` or in Alire's standard
GNATprove installation. `ADALANG_CVC5` and `ADALANG_Z3` can select explicit
executables. Solver calls have a two-second limit each and never pass source
text through a shell.

The CFG verifier also carries a symbolic state beside the interval state.
Straight-line assignments are retained as symbolic substitutions, relational
subprogram preconditions and branch conditions become path assumptions, and
simple actual-to-formal substitutions feed call-precondition VCs. At a CFG
join, an identical symbolic assignment from every predecessor survives;
conflicting assignments receive a fresh unconstrained merge symbol. Calls
without a relational postcondition, exceptional edges, and unsupported writes
clear symbolic facts.

Leading `Loop_Invariant` pragmas now form inductive cut points for straight-line
scalar loop bodies. The verifier separately proves initialization from the
non-back-edge input and preservation for one generic iteration. Only when both
VCs succeed does a second CFG pass replace the loop fixed point with an
invariant summary, cut the back edge, and use the invariant plus the negated
loop condition for post-loop and subprogram-postcondition proofs. Failed
preservation never feeds downstream proofs. A single leading `Loop_Variant`
with `Increases` or `Decreases` is also checked across that generic iteration:
the value must move strictly in the declared direction and remain within its
static scalar bounds; decreasing variants must additionally be nonnegative at
the iteration entry. Invariants after executable loop statements, multiple or
non-leading variants, and branched, nested, call-containing, or otherwise
unsupported iteration paths remain `Unproved`. These fallbacks trade precision
for soundness and never create a speculative proof.

Effective `SPARK_Mode` inherited through a declaration is respected by these
contract checks. The SPARK-readiness pass separately compares semantic global
reads and writes with `Global` modes, follows the declared global effects of
resolved callees, checks that every writable formal or declared global output
has a `Depends` association, and performs branch-sensitive definite
initialization for scalar `out` parameters. It also infers input-to-output
information flow for explicit `Depends` contracts. Expression data flow,
conditional control flow, loop and exit conditions, normal-return paths,
exception handlers, global state, and resolved calls with dependency summaries
all participate. This detects missing and demonstrably extra edges, incorrect
`null` associations, omitted self-dependencies (`=>+`), incomplete input
coverage, and output dependencies on `Proof_In` state.

Missing explicit `Global` and `Depends` contracts are selectable
maintainability findings: SPARK permits tools to synthesize defaults, but
explicit contracts make review and regression checking substantially
stronger.

For abstract execution, `Global` contracts distinguish read-only `Input` and
`Proof_In` state from `Output` and `In_Out` state that a call may modify,
avoiding the previous loss of all global facts. The readiness checks are
conservative for component-level assignment targets, aliasing, unresolved
calls, dispatching, and exceptional prefixes. Dependency sets reach a fixed
point through loops; at unsupported boundaries the analyzer suppresses
precision-dependent "extra edge" findings while retaining conservative
"may depend" information. These checks establish inexpensive flow properties;
they do not generate verification conditions or replace GNATprove.

A named number is known to the analysis by its value: a division by one that
is zero is a `Division_By_Zero`, an index written with one is checked against
the bounds. The checks that look for a condition which is constant as it is
written -- `Constant_Condition`, `Unreachable_Branch`, the redundant Boolean
operators -- do not count a test of a named number among them: `if
Buffer_Limit = 0 then` is the usual way of selecting code for one
configuration, not a condition that has gone constant by mistake.

`Division_By_Zero` and `Constant_Condition` are additionally strengthened by a
flow-sensitive abstract-execution pass that tracks both a variable's known
integer value and its known boolean value across straight-line code,
`if`/`elsif`/`else` and `case` branches, declare blocks, and loops. A loop
havocs every variable its body assigns before interpreting the body once, so
a value known before the loop is never wrongly assumed to survive a
reassignment that happens later in the same loop body. A `case` statement
whose selector is statically known interprets only the one alternative it
actually matches, rather than joining every alternative, so an assignment
made in that single live branch is not diluted away at the merge point the
way it would be if two disagreeing branches were joined. An `if` expression
whose condition itself resolves is folded to its live branch's value the
same way. This lets both checks catch cases only reachable through an
earlier assignment or a resolved conditional, not just literal constants,
e.g. `X := 0; ... Y := 10 / X;`, `Flag := True; ... if Flag then ...`, or
`case Selector is when 5 => D := 0; when others => D := 2; end case; ...
Y := 10 / D;` when `Selector` is known to be 5.

Alongside each variable's exact known value, the same pass tracks a
best-effort *range* it is known to stay within, independently bounded from
below and/or above (unlike the exact-value domain, which is all-or-nothing).
A comparison against `if`/`elsif`/`while` narrows that range for the
branch(es) where the comparison is known to hold or not hold, including
through `not`, `and`/`and then`, and `or`/`or else`, so `if X > 0 then if
X >= 1 then ...` proves the inner condition constant even when `X`'s exact
value is never known. A `for` loop's own control variable is seeded from its
`Low .. High` bounds the same way, so `for I in 1 .. N loop if I > 0 then
...` is provably true on every iteration despite `I` changing each pass.
Range narrowing only ever tightens a bound it can prove, and joining two
branches unions rather than intersects their ranges, so an unresolvable or
unrelated comparison simply leaves the range as wide (and the check as
silent) as it already was.

The pass conservatively stops tracking at constructs it does not model
(`select`, `accept`, `goto` targets) and for subprogram or declare-block
bodies with their own exception handlers.

Four further checks strengthen the SPARK-readiness layer without attempting
proof. `Aliasing_Between_Parameters` walks each call's actual parameters
alongside their resolved formal modes and reports two actuals that are
textually the same object or component when at least one of the
corresponding formals is written — the same anti-aliasing legality rule
GNATprove enforces, checked here by simple structural comparison rather than
points-to analysis. `Missing_Loop_Variant` flags a loop that carries a
`Loop_Invariant` pragma without a matching `Loop_Variant`, since GNATprove
needs the latter to prove termination. `Known_Discriminant_Check_Failure`
resolves a selected component's variant part and the accessing object's own
discriminant constraint (when it is a literal or enumeration-literal
constant) and reports an access to a component that constraint provably
excludes, the same way a `case` statement with a statically known selector is
resolved to its one live alternative. `Potentially_Blocking_Operation` reports
a `delay` statement or entry call in a protected procedure or function. Before
the checking pass, a compact call-summary registry propagates blocking and
raising effects to a fixed point, so calls that transitively reach a blocking
operation are also reported. The same registry records incoming formal reads,
body-observed formal writes, all-path normal-return initialization, and direct
or transitive writes to nonlocal objects. Ordinary data-flow checks and
`--verify` use those effects to retain unaffected facts and initialize simple
`out` actuals only when every normal return writes the corresponding formal.
Nested subprogram bodies remain independently summarized rather than being
mistaken for direct execution by their parent. The summaries store monotone
effects rather than paths or complete states to keep the pass bounded; any
unresolved transitive call makes state effects incomplete and restores the
unknown-call fallback.

The `--automotive` preset combines these checks into a deliberately strict Ada
profile. It covers allocation and access use; unchecked conversion,
deallocation, and access; tasking,
rendezvous, select, requeue, and asynchronous transfer; exception handling and
escape; dispatching, class-wide, access-to-subprogram, controlled, and
finalization features; initialization; volatile/atomic use; representation
clauses; library elaboration; numeric operations and conversions; unreachable
selection logic; loop evidence; complexity and nesting; shadowing and naming;
generic/dependency limits; implementation-defined pragmas; run-time-check
suppression; and analyzer-suppression rationale. It is a strict superset of
`--spark`: it also requires an explicit `Global` and `Depends` contract on
every subprogram that needs one, and flags any region that explicitly leaves
the SPARK subset via `SPARK_Mode => Off`.

The preset is an engineering aid, not a claim of official MISRA or AUTOSAR
conformance. MISRA and AUTOSAR rule applicability, documented deviations,
compiler configuration, target representation evidence, traceability, and
tool-qualification evidence remain project responsibilities. In particular,
`Representation_Clause_Policy` creates a mandatory review finding rather than
pretending that a source-only analyzer can validate every target ABI, and
exception/dispatch summaries are conservative rather than full CodePeer-style
path proofs.

See the [Automotive Ada Compliance Matrix](automotive-compliance-matrix.md)
for a non-normative rule-by-rule mapping to the Ada Reference Manual's Annex H
high-integrity restrictions and SPARK Reference Manual guidance, limitations,
and remaining compliance gaps. The same `--automotive` rule set is also read
under EN 50128 (rail) verification-support vocabulary; see the
[EN 50128 Rail Compliance Matrix](en50128-rail-compliance-matrix.md).

</details>

