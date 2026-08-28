# Supported Verification Subset

This document is the behavioral contract for `--verify`. It defines the
source constructs and proof claims that AdaLang Analyzer currently supports.
The implementation and regression corpus take precedence over aspirational
examples elsewhere in the documentation.

## Meaning of a result

The unit of verification is one enumerated proof obligation at one source
location. A `Proved_Safe` result means only that the named obligation was
discharged for every state represented by the supported analysis at that
location. It is not a whole-program proof and says nothing about unenumerated
checks, target representation, unchecked conversion, concurrency, or code the
front end could not resolve.

`Definite_Error` means the represented state establishes failure.
`Unproved` means neither safety nor failure was established. `Unreachable`
means no represented path reaches the operation. `Unsupported` means the
subprogram or control-flow boundary is outside this contract. An unsupported
scalar translation within an otherwise supported boundary remains `Unproved`
and carries a reason code and blocking expression.

No missing, `Unproved`, `Unsupported`, or ordinary rule-finding result may be
interpreted as proof of safety.

## Enumerated obligations

| Obligation | Supported proof basis | Current boundary |
|---|---|---|
| Division by zero | Exact/range exclusion of zero; otherwise scalar `divisor /= 0` VC | Integer scalar divisor only |
| Integer overflow | Operation base-type range; otherwise scalar bounds VC | Integer `+`, `-`, `*`, `/`, and selected power checks |
| Range | Resolved scalar subtype bounds; otherwise scalar bounds VC | Integer scalar initialization, assignment, and conversion |
| Index | Resolved index subtype per dimension; otherwise scalar bounds VC | Statically modeled array types and scalar indices |
| Discriminant | Static and abstract discriminant checks | Selected resolved discriminated objects only |
| Initialization | Flow-sensitive definite-initialization state | Tracked scalar objects and documented composite write summaries |
| Assertion | Abstract Boolean evaluation; otherwise scalar Boolean VC | `Assert`, `Assert_And_Cut`, and `Check` conditions |
| Precondition | Formal-to-actual substitution and scalar Boolean VC | Resolved calls with supported scalar contracts |
| Postcondition | Joined normal-exit state and scalar Boolean VC | Supported scalar exits and contract expressions |
| Loop invariant initialization | Entry-edge abstract/symbolic state | Leading invariants on supported loops |
| Loop invariant preservation | Generic one-iteration abstract/symbolic VC | Straight-line scalar body, or a straight-line scalar body containing a non-nested `if`/`elsif`/`else` chain (the `else`, and any number of `elsif` parts, may be omitted) whose arms each independently reach the loop's back edge, joined with the same merge machinery used at ordinary CFG merge points -- one `Join_On_Condition` call per `Condition_Node` in the chain, right-folded so an N-arm chain yields N-1 nested `ite` terms, exactly matching Ada's own `elsif` desugaring; a scalar binding on which two arms disagree is represented at each fold as an SMT `(ite <selector> <true-term> <false-term>)` term, letting facts already established before the branch (such as the loop guard) carry through the disjunction regardless of which arm actually ran -- the selector is the branch's own condition when that condition translates to the scalar VC language (correlating it with any of the condition's own free variables appearing elsewhere in the obligation), or otherwise an anonymous, totally unconstrained boolean symbol standing in for it (sound for any selector value, but unable to correlate with anything else in the obligation); a fresh, unconstrained symbol is used instead of an `ite` only when a binding's own sort disagrees between arms, an unreachable defensive case; array-element and pointer-dereference writes are tolerated (never symbolically tracked, so skipping them leaves no stale binding), but a record-component write is not, since that *is* symbolically tracked and could otherwise resolve to a stale pre-write value; an `elsif`/`else` part is folded only when it continues the *same* `If_Stmt` as the branch that reached it, distinguished by walking the branch condition's AST ancestry back to its owning `If_Stmt` -- a lexically distinct, genuinely nested `If_Stmt`/`Case_Stmt` inside any arm's own body (as opposed to that arm's own `elsif`/`else` continuation), or an independent, sequential `if`/`elsif`/`else`/`case` construct reached after the first one's own arms rejoin, draws on the same per-path `Branch_Budget` (initially 2, spent once per independent chain or case statement entered, never for a chain's own `elsif`/`else` continuations or a case's own sibling alternatives) that the first, outermost conditional itself spent one unit of -- so exactly one such nested-or-sequential second conditional is folded the same way the first is, by the same one-level soundness argument applied recursively (each arm's own recursive walk must still independently reach the loop's back edge before anything is joined); a third independent conditional along any single path exhausts the budget and conservatively bails to `Unproved`, the same as every genuinely nested or sequential conditional did before this budget existed; or a straight-line scalar body containing a single non-nested `case` statement whose alternatives each independently reach the loop's back edge, joined via one `VC.Join_On_Range` call per alternative (bar a trailing, explicit `others`, the fold's base case needing no selector, exactly mirroring `elsif`'s own bare trailing `else`), right-folded the same way the `elsif` chain is -- every alternative but `others` must have exactly one choice in its `F_Choices` (a single expression or a single `..` range, never a `\|`-separated or discontiguous set: unioning multiple choices into one covering range would unsoundly admit selector values that belong to a different, or no, alternative, so a multi-choice alternative is rejected outright rather than range-unioned) and that choice's bounds must be statically known (`Choice_Interval.Known`); the selector for each alternative's `ite` is a range-membership predicate over the case selector's own translated term (`Integer_Term`) rather than a boolean condition, falling back to the same anonymous, totally unconstrained boolean symbol `Join_On_Condition` uses when a selector or bound doesn't translate; a lexically nested `If_Stmt`/`Case_Stmt` inside any one alternative's own body draws on the remaining `Branch_Budget` the same way as for `elsif`, up to the same two-independent-conditionals-per-path limit. A missing or non-final `others`, a multi-choice or discontiguous case alternative, a third independent conditional along any single path (nested or sequential), nested loops, calls, or unsupported transfers remain outside this subset |
| Loop variant progress | Strict two-state scalar progress VC plus static base-type bounds | One leading, single-component `Increases` or `Decreases` variant on the same iteration subset as invariant preservation (straight-line, or with a non-nested `if`/`elsif`/`else` chain or single-choice-per-alternative `case`); usable leading invariants must first discharge |

## Scalar VC language

The external prover portfolio operates on mathematical integers and Booleans.
The supported translation includes initialized scalar names, integer and
Boolean literals, unary negation and `not`, arithmetic `+`, `-`, and `*`,
comparisons, equality, Boolean connectives, supported integer conversions,
bounded quantifiers, and side-effect-free expression functions that can be
inlined within the depth limit. Integer `/`, `mod`, and `rem` are translated
only when the divisor is provably nonzero and their Ada sign semantics are
encoded.

Symbolic assignments resolve their scalar sort from Ada semantic type
identity: signed integers use mathematical-integer terms, `Standard.Boolean`
uses SMT Boolean terms, and enumeration values use their declaration-order
positions. Unsupported scalar types and inconsistent bindings stop translation
with explicit `sort-mismatch` provenance rather than being inferred from the
absence of interval facts.

`X'First`, `X'Last`, and `X'Length` (default dimension only, no explicit
dimension argument) translate to a literal constant when `X`'s bounds are
statically known. When `X` is an unconstrained array object (a formal
parameter, most commonly) and only `'Length` is referenced, translation
falls back to a fresh symbol lower-bounded at `0` -- the one fact the
language itself guarantees regardless of the actual (unknown) bounds --
rather than stopping translation outright. `'First`/`'Last` on an
unconstrained array object, and any attribute reference with an explicit
dimension argument, remain unsupported.

Machine-width safety is a separate overflow obligation. A solver refutation
of an assertion containing potentially overflowing arithmetic is not promoted
to `Definite_Error` merely from mathematical-integer semantics. The base
range an overflow check tests against is resolved to the full derivation
root, not one immediate-parent hop: a twice-derived type (RecordFlux's
`Index is new Length range 1 .. Length'Last`, itself `Length is new
Natural`, for instance) would otherwise be checked against an intermediate
ancestor's own narrower first-subtype constraint rather than the true
machine range every derivation ultimately inherits. The same base-range
fallback also applies when an ordinary (non-derived) subtype's own declared
constraint isn't statically known — e.g. `N : Natural range 0 ..
Arr'Length`, where `Arr` is an unconstrained array parameter — by widening
to the named type's own fully-unwound base subtype; Ada scalar subtyping
only ever narrows, so this is always a sound, if looser, envelope. This
resolves the *base-range gate* that loop-variant progress and overflow
checks require before attempting a proof; it does not by itself guarantee
the proof succeeds, and does not affect loop-variant obligations already
blocked upstream by an undischarged leading invariant.

The path context may contain entry preconditions, branch predicates,
straight-line scalar substitutions, sound relational postcondition transfer,
and identical symbolic facts preserved at every incoming join. Conflicting
join values, exceptional flow, and calls without sound relational summaries
drop facts rather than assuming them.

For a supported loop variant, the expression is translated in both the state
before the generic iteration and the state after its back edge. `Decreases`
requires a nonnegative entry value and a strictly smaller exit value;
`Increases` requires a strictly larger exit value. Both values must remain
within the expression base type's static bounds, which supplies the finite
lower or upper bound needed for the corresponding termination argument.

A leading `Loop_Invariant` or `Loop_Variant` pragma is one preceded, within
the loop body, only by other leading loop-invariant/loop-variant pragmas --
either may come first. `Loop_Variant (Increases => I); Loop_Invariant (I <=
N);` and the reverse order both leave the invariant leading, since Ada/SPARK
attaches no meaning to their relative order.

When a loop carries more than one leading invariant, each is assumed
independently before the loop body is walked: one invariant's condition
failing to translate to the scalar VC language contributes nothing on its
own (that invariant's own obligations stay `Unproved`), but never discards
the facts already assumed from the loop's *other*, independently
translatable leading invariants -- a loop guard or sibling invariant
outside the scalar subset does not, by itself, block preservation or
variant progress for an otherwise-provable one.

An external result is accepted only when both configured CVC5 and Z3 runs
agree by returning `unsat` for the negated goal. Solver absence or disagreement
cannot produce `Proved_Safe` or `Definite_Error`.

## Supported control flow

The verification CFG covers sequential statements and declaration
elaboration; `if`/`elsif`/`else`; `case`; `while`, `for`, and unconditional
loops; unnamed exits; returns; raises; nested blocks; and conservative
exception-handler dispatch. Fixed-point iteration widens growing loop ranges.
A subprogram with an incomplete or malformed CFG cannot yield a proof based on
that boundary.

Explicit access dereference, general alias/points-to reasoning, tasking,
protected operations, dispatching/class-wide calls, floating-point proof,
unchecked conversion, target-dependent representation, and unmodeled
exception semantics are outside the supported subset. Other unsupported
scalar forms must retain a stable provenance reason rather than silently
becoming proof evidence.

## Evidence and change control

The executable evidence consists of:

- `tests/run_verification.sh` for obligation outcomes and provenance;
- `tests/run_verification_mutations.sh` for seeded false-safe detection;
- `tests/run_proof_path_evidence.sh` for complete `Proved_Safe` producer and
  method-route coverage;
- `tests/run_gnatprove_differential.sh` for clean and deliberately broken
  oracle comparison; and
- `tests/run_all.sh` for the complete repository gate.

Any change that expands a `Proved_Safe` path must update this document, add a
positive case, add a boundary or seeded-defect case, register the producer in
`quality/proof_path_evidence.tsv`, and pass the complete gate. Confirmed
false-safe results follow [FALSE_SAFE_RESPONSE.md](FALSE_SAFE_RESPONSE.md).
