# Changelog

All notable changes to AdaLang Analyzer are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versioning follows [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Added

- `Unclosed_File_Handle` now also recognizes a `File_Type` object of a
  package instantiated from `Ada.Direct_IO`/`Ada.Sequential_IO` (generic,
  and instantiated per element type), the follow-up `quality/README.md`
  had documented as out of this check's v1 scope. Since Libadalang
  resolves an instantiated package's own nested entities (`Open`/
  `Create`/`Close`/`Is_Open`) against the instantiation's own name rather
  than the generic template, recognizing them required walking the
  callee's own `P_Generic_Instantiations` chain and reading the
  designated generic's `P_Defining_Name` source text directly (its own
  `P_Canonical_Fully_Qualified_Name` is itself instantiation-relative and
  unusable for this, confirmed empirically). A generic package
  instantiated via a bare name reached only through a `use` clause on
  the generic unit itself (rather than the fully qualified name) is also
  recognized, closing `FP-062` in `quality/known_analysis_issues.tsv`:
  this shape hits two independent Libadalang `Property_Error`s, not
  one -- resolving the call itself fails, and separately, resolving just
  the instantiation object's own name and asking its designated generic
  decl for its own defining name also raises "dereferencing a null
  access". Worked around by resolving the call's dotted prefix instead
  of the whole name when the first resolution fails, and by falling
  back to the generic name's own syntactic spelling at the instantiation
  site (accepting either the qualified or bare form) when even that
  fails -- an accepted precision tradeoff in that last fallback
  specifically, with no semantic confirmation possible there against an
  unrelated, identically-named generic also in scope. Adds five
  precision-corpus fixtures: the qualified-name Direct_IO/Sequential_IO
  cases, a fully qualified instantiation alongside an unrelated `use`
  clause, and the bare-generic-name shape itself (found and clean).
- `Unclosed_File_Handle` now reasons about loops instead of bailing out
  around them: an `Open`/`Create` call lexically inside a loop is no
  longer skipped entirely, and a loop appearing *after* the open is no
  longer credited with an unconditional pass merely because a matching
  `Close` appears somewhere in its text. `Interpret_Closure`'s loop case
  now interprets the body through the same structural interpreter used
  for straight-line code and `if`/`case`, then re-interprets it a second
  time starting from the first pass's own exit state to find a genuine
  two-state fixed point -- sound here because nothing besides the single
  "currently open" flag threads between statements, and the tracked
  `Open_At` call (the only thing that can force it back to unsafe) is
  reached the same way regardless of the incoming flag. That
  one-or-more-iterations outcome is merged with the unchanged
  zero-iterations outcome for `while`/`for` loops; a bare, unconditional
  `loop` has no such outcome to merge, since without an internal `exit`
  its own body completing normally just repeats it forever, making the
  code after it unreachable. An `exit` statement anywhere in the loop
  body still falls back to the older, purely textual heuristic rather
  than reasoning about where control actually goes. A numeric for-loop
  whose `Low .. High` range is statically known non-empty (via
  `Flow_Eval.Choice_Interval`, the same static-bounds proof
  `Spark_Readiness`'s own `Uninitialized_Output` for-loop coverage check
  already uses) is treated the same as a bare, unconditional loop,
  closing `FP-063`: a range bounded by a variable or an untracked
  subtype's own declared lower bound is not proven non-empty and still
  conservatively fires, matching `Choice_Interval`'s own established
  scope elsewhere in this codebase. Adds nine precision-corpus fixtures
  covering loop-scoped opens (found and clean), open-before-loop (found,
  clean via the exit fallback, the zero-iteration boundary, and a
  statically non-empty range), nested loops, and a bare loop with a
  conditional early return.
- `--verify`'s loop-invariant-preservation VC now supports one additional
  independent `if`/`elsif`/`else` chain or `case` statement per loop
  body, reached either by nesting inside an arm of the first one or
  sequentially after it rejoins -- both draw on the same per-path
  `Branch_Budget` (flow_interp.adb's `Advance`), replacing the previous
  hard `Allow_Branch` cutoff after exactly one conditional construct. The
  budget starts at 2 (`Max_Branch_Depth`), spent once per independent
  chain or case statement entered (never for a chain's own `elsif`/
  `else` continuations or a case's own sibling alternatives, which stay
  free as before), so a third independent conditional along any single
  path still conservatively bails to `Unproved`. Since `Join_On_Selector`
  already reconciled arms generically by `Symbol_Key`, with no special
  casing tied to nesting depth, composing the existing one-level
  fork-and-join recursively required no change there -- only the
  `Branch_Budget` threading through `Advance`'s recursive calls. Closes
  two of the three existing `..._nested_if_unsupported.adb` regression
  fixtures onto genuine proofs (renamed to `..._clean.adb`: their nested
  condition turned out to be dead code given the enclosing arm's own
  established fact, e.g. an `elsif X = 1` arm's nested `if X = 2`), while
  the third (an outer `Flag` condition uncorrelated with the inner
  `X = 0`) correctly remains `Unproved` on genuine disagreement, not
  syntax rejection. New fixtures cover the previously-unexercised
  sequential shape both safe and adversarial
  (`verification_loop_branch_sequential_clean/_vc_broken.adb`) and the
  budget boundary itself
  (`verification_loop_branch_third_conditional_unsupported.adb`).

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
