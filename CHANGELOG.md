# Changelog

All notable changes to AdaLang Analyzer are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versioning follows [Semantic Versioning](https://semver.org/).

## [1.2.0] - 2026-08-25

### Added

- `Use_After_Free` check: flags a local access object read or dereferenced
  after it was passed to an instantiation of `Ada.Unchecked_Deallocation`,
  with no intervening assignment.
- `Unclosed_File_Handle` check: flags a local `Ada.Text_IO`/
  `Ada.Streams.Stream_IO` `File_Type` object opened with `Open`/`Create`
  that is not demonstrably closed on every normal-return or
  exception-handler path out of the enclosing subprogram.
- `Unused_With_Clause` check: flags a with clause naming a unit never
  referenced elsewhere in the compilation unit.
- `Empty_Then_Body` check: flags an if statement's then branch whose body
  has no effect (only `null;` and/or non-`Assert` pragmas), even when a
  later `elsif` or `else` does real work. Unlike `Empty_If_Body`, not
  scoped to a bare `if` with no `elsif`/`else`, closing another
  `null_paths`/`Empty_If_Body` scope gap.
- `Empty_Else_Body` check: flags an `else` part whose body has no effect
  (only `null;` and/or non-`Assert` pragmas). The else-branch counterpart
  of `Empty_If_Body`/`Empty_Elsif_Body`, closing the last open
  `null_paths`/`Empty_If_Body` scope gap.
- `--verify`'s loop-invariant-preservation VC now folds `elsif`/`else`
  continuations of the same `if` statement into the existing branch-merge
  machinery (previously a full `elsif` chain forced the invariant to
  `Unproved`, even where a plain `if`/`else` of the same shape would have
  discharged). Each additional arm is merged via its own
  `(ite <selector> ...)` SMT term, built from one `Join_On_Condition` call
  per chain link and right-folded to match Ada's own `elsif` desugaring, so
  soundness and precision match the existing two-arm case exactly. A
  lexically nested `if`/`case` inside any arm -- as opposed to that arm's
  own `elsif`/`else` continuation of the same statement -- remains outside
  the supported subset, distinguished by walking the branch condition's AST
  ancestry back to its owning `If_Stmt`.
- `--verify`'s loop-invariant-preservation VC now also folds a `case`
  statement into the branch-merge machinery, for the subset where every
  alternative but a trailing, explicit `others` has exactly one
  statically-known choice (a single value or a single `..` range -- never a
  `|`-separated or discontiguous set, which would unsoundly widen the
  alternative's own `ite` selector to cover values that belong to a
  different, or no, alternative). Each alternative is merged via a new
  `VC.Join_On_Range` entry point, using a range-membership predicate over
  the case selector's own translated term as the `ite` selector instead of
  a boolean condition, right-folded to mirror Ada's own alternative
  precedence. `Join_On_Condition`'s own branch-merge logic (roots/bindings
  reconciliation, the `ite`-building, the fresh-symbol fallback) was
  extracted into a shared `Join_On_Selector` helper so `Join_On_Range`
  reuses it verbatim rather than duplicating it. A multi-choice or
  discontiguous alternative, a missing or non-final `others`, or a
  lexically nested `if`/`case` inside any one alternative's own body all
  remain outside the supported subset and conservatively bail to
  `Unproved`, same as before.

### Fixed

- `Unclosed_File_Handle` (new this release) initially false-positived on
  the idiomatic "close a file that might already be closed" pattern --
  `if Ada.Text_IO.Is_Open (File) then Ada.Text_IO.Close (File); end if;`,
  and the more general "opened and closed behind the identical boolean
  guard" idiom -- both found via this project's own `--recommended`
  self-analysis gate before release. Both idioms are now recognized as
  safe (`FP-060`).
- `Duplicate_Subprogram`'s finding message embedded the earlier
  occurrence's file:line as literal text, so a finding's `--baseline`
  fingerprint (which hashes the message) could shift whenever unrelated
  code was inserted anywhere above that occurrence in its own file, even
  though the duplication itself hadn't changed — narrowly contradicting
  this project's own documented fingerprint-stability guarantee for this
  one check. The file:line now lives in the finding's `Evidence` field
  instead, which is displayed the same way but deliberately excluded from
  the fingerprint (`FP-058`).
- `Empty_If_Body`, `Empty_Elsif_Body`, `Empty_Then_Body`, `Empty_Else_Body`,
  and `Null_Case_Alternative` treated a branch or alternative containing
  only `pragma Assert (False);` as having no effect, the same as a bare
  `null;` — but a solitary `pragma Assert` is a deliberate "this must
  never happen" guard, not filler. Found via this analyzer's own GNATcheck
  oracle comparison against `AdaCore/Ada_Drivers_Library`. `pragma Assert`
  now counts as substantive; every other pragma is unaffected (`FP-059`).

## [1.1.0] - 2026-08-19

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
- `Empty_Elsif_Body` check: flags an `elsif` branch whose body has no
  effect (only `null;` and/or pragmas). The elsif-branch counterpart of
  `Empty_If_Body`, closing another `null_paths`/`Empty_If_Body` scope gap.

### Fixed

- `Has_Exception_Boundary` (`Exception_Propagation`'s boundary check)
  did not stop at a task body the same way it already stopped at a
  subprogram body, so a task body declared inside a nested `declare`
  block could incorrectly inherit an enclosing scope's exception
  handler as its own boundary, even though a task runs on its own
  thread of control (`FP-053`).
- `Address_Clause` missed the aspect-syntax form of an address
  specification (`with Address => ...;`), reporting only the legacy
  `for X'Address use ...;` clause form (`FP-054`).
- `Address_Clause` missed the obsolescent `for X use at ADDR;` clause
  form (`FP-055`).

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

[1.1.0]: https://github.com/mmartign/AdaLang_Analyzer/releases/tag/v1.1.0
[1.0.0]: https://github.com/mmartign/AdaLang_Analyzer/releases/tag/v1.0.0
