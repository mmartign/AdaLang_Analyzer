# Changelog

All notable changes to AdaLang Analyzer are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `Known_Enum_Val_Failure` check: flags `'Val` attribute calls whose
  statically known argument is outside the enumeration type's literal
  positions (always raises `Constraint_Error`).
- `Known_Value_Conversion_Failure` check: flags `'Value` attribute calls
  whose static string literal argument can never denote a value of the
  prefix integer or enumeration type (always raises `Constraint_Error`).
- `Known_Negative_Shift_Amount_Failure` check: flags `Interfaces`
  shift/rotate calls whose statically known amount is negative (always
  raises `Constraint_Error`, since every such function's `Amount`
  parameter is subtype `Natural`).
- `Known_Negative_Exponent_Failure` check: flags `**` exponentiations on
  an integer base whose statically known exponent is negative (always
  raises `Constraint_Error`, since the predefined integer `**` operator's
  exponent is subtype `Natural`).
- `Redundant_Abs` check: flags `abs` applied to an operand that is itself
  an `abs` expression.
- `Redundant_Unary_Minus` check: flags unary negation applied to an
  operand that is itself a unary negation.
- `Contradictory_Range_Condition` check: flags `and`/`and then`
  conditions combining two relational comparisons on the same expression
  whose statically known bounds cannot both hold (e.g. `X > 10 and then
  X < 5`).
- `Null_Case_Alternative` check: flags a case alternative naming a
  specific choice whose body has no effect (only `null;` and/or pragmas).
  The case-statement counterpart of `Empty_If_Body`, which is deliberately
  scoped to plain `if` statements and does not see case alternatives. Does
  not flag a catch-all `when others => null;`, a common, deliberate Ada
  idiom.

## [1.0.0] - 2026-08-18

Initial public release.

### Added

- 112 checks spanning five groups: defect detection (control-flow,
  data-flow, expression, case/conditional, exception-handling,
  arithmetic, assignment, and complexity), SPARK readiness
  (`Global`/`Depends` contracts and known precondition/postcondition/
  assertion/range/index/overflow/discriminant failures), safety profiles
  (`--automotive` and `--do178c=<level>`), and style/maintainability
  checks. See the [Checks](README.md#checks) table for the full list.
- `--verify`, a bounded mode that classifies individual scalar proof
  obligations as proved safe, definite error, unproved, unreachable, or
  unsupported.
- `--automotive` and `--do178c=<level>` verification-support profiles.
- Text, JSON, and SARIF output for CI integration.
- `--recommended` profile selecting a curated default check set.
- Cross-file duplicate-subprogram (clone) detection.
- Alire packaging (`alire.toml`); submitted to the community index as
  `adalang_analyzer`.

[1.0.0]: https://github.com/mmartign/AdaLang_Analyzer/releases/tag/v1.0.0
