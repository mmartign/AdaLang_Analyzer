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
| Range | Both bounds of the target subtype, resolved as of its elaboration; otherwise scalar bounds VC against those same two bounds | Integer scalar initialization, assignment, and conversion into a signed or modular subtype whose two bounds are both known; a subtype with a bound that is not (`range 1 .. N` for a variable or unconstrained `N`) is `Unproved`. Also the two bounds of a slice written `A (L .. H)`, against the bounds of `A` as an index check takes them: proved when both bounds are within them, or when the slice is known to be null, which Ada does not check. A slice given by a subtype name or a `'Range` is `Unproved`. Also an actual parameter against the subtype of its integer formal, and what an `out` or `in out` formal gives back against the subtype of the actual: raised only where the check is needed, that is not when the receiving subtype has every value of its type nor when the form of the actual alone says it fits (a name of that subtype or of one declared from it, a static value, arithmetic whose interval over the operands' subtypes fits). The way in is decided as an assignment is; the way back is `Unproved` whenever it is raised, nothing being known of the value the callee leaves beyond the formal's subtype |
| Index | The indexed object's own bounds per dimension -- the index constraint on its declaration, or its constrained array type or subtype -- otherwise scalar bounds VC against those bounds; or, with no bounds a declaration fixes, either the index is the parameter of a `for` loop over that same dimension of that same object (`for I in A'Range`, `A'Range (N)`, or `A'First .. A'Last`), or a scalar VC places it between the object's own `'First` and `'Last` taken as symbols, one pair per dimension | Array objects whose bounds a declaration fixes, and scalar indices. An object of an unconstrained array type that takes its bounds from a string literal, or from another object whose bounds are known, has those bounds. One with no bounds anything fixes (a formal parameter, or an object initialized from one, from a call or from an aggregate) proves only in the own-range loop form or against those symbols: its index subtype says what its bounds may be, not what they are |
| Discriminant | The prefix object's own static discriminant constraint (an integer expression or an enumeration literal) selects the variant declaring the component; a constrained object's discriminants never change | A component of a top-level variant part, selected directly from an object declared with an explicit discriminant constraint; a constant, variable, or subtype-name constraint or choice is never resolved by spelling and stays `Unproved` |
| Initialization | Flow-sensitive definite-initialization state | Tracked scalar objects and documented composite write summaries, at each read; and each `out` parameter at the subprogram's normal exit, proved when every path that returns has assigned the whole parameter or passed it to a callee that always writes it. An `out` parameter assigned component by component is `Unproved` |
| Assertion | Abstract Boolean evaluation; otherwise scalar Boolean VC | `Assert`, `Assert_And_Cut`, and `Check` conditions |
| Precondition | Formal-to-actual substitution and scalar Boolean VC | Resolved calls with supported scalar contracts |
| Postcondition | Joined normal-exit state and scalar Boolean VC | Supported scalar exits and contract expressions |
| Loop invariant initialization | Entry-edge abstract/symbolic state | Leading invariants on supported loops |
| Loop invariant preservation | Generic one-iteration abstract/symbolic VC | Straight-line scalar body, or a straight-line scalar body containing a non-nested `if`/`elsif`/`else` chain (the `else`, and any number of `elsif` parts, may be omitted) whose arms each independently reach the loop's back edge, joined with the same merge machinery used at ordinary CFG merge points -- one `Join_On_Condition` call per `Condition_Node` in the chain, right-folded so an N-arm chain yields N-1 nested `ite` terms, exactly matching Ada's own `elsif` desugaring; a scalar binding on which two arms disagree is represented at each fold as an SMT `(ite <selector> <true-term> <false-term>)` term, letting facts already established before the branch (such as the loop guard) carry through the disjunction regardless of which arm actually ran -- the selector is the branch's own condition when that condition translates to the scalar VC language (correlating it with any of the condition's own free variables appearing elsewhere in the obligation), or otherwise an anonymous, totally unconstrained boolean symbol standing in for it (sound for any selector value, but unable to correlate with anything else in the obligation); a fresh, unconstrained symbol is used instead of an `ite` only when a binding's own sort disagrees between arms, an unreachable defensive case; array-element and pointer-dereference writes are tolerated (never symbolically tracked, so skipping them leaves no stale binding), but a record-component write is not, since that *is* symbolically tracked and could otherwise resolve to a stale pre-write value; an `elsif`/`else` part is folded only when it continues the *same* `If_Stmt` as the branch that reached it, distinguished by walking the branch condition's AST ancestry back to its owning `If_Stmt` -- a lexically distinct, genuinely nested `If_Stmt`/`Case_Stmt` inside any arm's own body (as opposed to that arm's own `elsif`/`else` continuation), or an independent, sequential `if`/`elsif`/`else`/`case` construct reached after the first one's own arms rejoin, draws on the same per-path `Branch_Budget` (initially 2, spent once per independent chain or case statement entered, never for a chain's own `elsif`/`else` continuations or a case's own sibling alternatives) that the first, outermost conditional itself spent one unit of -- so exactly one such nested-or-sequential second conditional is folded the same way the first is, by the same one-level soundness argument applied recursively (each arm's own recursive walk must still independently reach the loop's back edge before anything is joined); a third independent conditional along any single path exhausts the budget and conservatively bails to `Unproved` with `branch-budget-exceeded` provenance naming the blocking condition, the same as every genuinely nested or sequential conditional did before this budget existed; or a straight-line scalar body containing a single non-nested `case` statement whose alternatives each independently reach the loop's back edge, joined via one `VC.Join_On_Range` call per alternative (bar a trailing, explicit `others`, the fold's base case needing no selector, exactly mirroring `elsif`'s own bare trailing `else`), right-folded the same way the `elsif` chain is -- every alternative but `others` must have exactly one choice in its `F_Choices` (a single expression or a single `..` range, never a `\|`-separated or discontiguous set: unioning multiple choices into one covering range would unsoundly admit selector values that belong to a different, or no, alternative, so a multi-choice alternative is rejected outright rather than range-unioned) and that choice's bounds must be statically known (`Choice_Interval.Known`); the selector for each alternative's `ite` is a range-membership predicate over the case selector's own translated term (`Integer_Term`) rather than a boolean condition, falling back to the same anonymous, totally unconstrained boolean symbol `Join_On_Condition` uses when a selector or bound doesn't translate; a lexically nested `If_Stmt`/`Case_Stmt` inside any one alternative's own body draws on the remaining `Branch_Budget` the same way as for `elsif`, up to the same two-independent-conditionals-per-path limit. A missing or non-final `others`, a multi-choice or discontiguous case alternative, a third independent conditional along any single path (nested or sequential), nested loops, calls, or unsupported transfers remain outside this subset |
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

`X'First`, `X'Last`, and `X'Length` (of the first dimension, or of the one
an integer literal names, as in `X'Last (2)`) translate to a literal constant
when a declaration fixes `X`'s bounds. Otherwise, when `X` names an array object -- a declared object
or a parameter, directly or by an expanded name -- each of the three is a
symbol of its own, one set per dimension: the bounds of such an object never
change while its name is visible. The three are tied by what the language guarantees, `'Length`
being `'Last - 'First + 1` when that is positive and `0` for an empty array,
and `X in A'Range` is `A'First <= X and X <= A'Last`, likewise for
`A'Range (2)`. Facts that mention
only such symbols are kept at the entry of a loop body, where every fact
about a variable is dropped; the parameter of a `for` loop over `A'Range`,
or over bounds that cannot change during the loop, is known to lie within
them. A component, a dereference or a call as the prefix, a dimension that
is not written as an integer literal, and a dimension other than the first
on a subtype mark, remain unsupported.

A bound written in a subtype, array type or object declaration is
resolved to the value it had when that declaration was elaborated. It is
used only when every name in it denotes something that cannot have changed
since -- a constant, a named number, an `in` parameter, a loop parameter, an
enumeration literal or another subtype -- so `subtype Window is Integer
range 1 .. Size` has no known upper bound when `Size` is a variable, whatever
`Size` holds at the point of use. A range or index check is decided only
against a target with both bounds known; one known bound alone proves
nothing.

`X in S` and `X not in S`, where `S` is a subtype mark, are range tests only
when neither `S` nor any subtype or type it is declared from carries a
`Predicate`, `Static_Predicate` or `Dynamic_Predicate`. For a predicated
subtype the scalar VC translation is unsupported, and interval narrowing
uses only the one-way fact that a member lies within the subtype's range.

A membership test on an identifier narrows that identifier's interval the
way a comparison does. When the test holds, the interval is intersected with
the hull of the alternatives (static values, `..` ranges, and integer
subtype marks). When it does not hold, an alternative is removed only where
it covers an end of the interval already known -- `X not in 0 .. 3` turns
`0 .. 10` into `4 .. 10`, but tells an interval nothing about `X not in 3 ..
5` -- and never when it is a predicated subtype.

Values of `Character`, `Wide_Character` and `Wide_Wide_Character` are not
given a position range, so nothing is proved about them from their type
alone.

Modular `+`, `-`, `*`, `**` and unary `-` are reduced by the modulus on both
proof paths. When the modulus is not known (a `mod 2 ** 64` type, a formal or
private type, a type that does not resolve), the result is unknown. In the
scalar VC language a modular sum, difference or product by a constant is the
term reduced with `mod`; the product of two unknown modular values is only
known to be some value of the type, the same one for the same two operands.

## Objects and effects the analysis does not follow

A fact about an object is kept only while nothing but the object's own name
can change it. An expanded name -- `Pkg.Obj`, or a local qualified by its
own subprogram -- is the object's own name: it denotes the same object as
the direct name, for reads and writes alike.

- A renaming, an object with an address clause or aspect, and an imported
  object hold no fact, and a write through one discards every value fact:
  the name may denote storage another name also denotes.
- A volatile, atomic, exported or aliased object holds no fact: it can
  change with no name at all.
- A function called in an expression may write whatever it can see, unless
  it is known not to: its effect summary has no global write, its `Global`
  contract names no output, its unit is declared `Pure`, it is under an
  explicit `SPARK_Mode` -- on the declaration, on an enclosing unit, in a
  pragma before the compilation unit, or in the configuration pragmas of
  the project it belongs to -- it is a predefined operator or attribute, or
  its body is available and only computes. Otherwise the expression is
  evaluated in a state that omits what the call may write: the outputs its
  summary or contract names, or every object declared outside the
  subprogram under analysis, or every object when the callee is nested in
  it. The symbolic state is dropped at such an expression.
- A subprogram that declares or assigns an object whose type may run user
  code implicitly -- anything other than a scalar, an access value, or an
  array or untagged record of those whose component defaults call nothing
  with side effects -- keeps no value fact about objects declared outside
  it, and none at all when that type is declared inside it. This is what
  covers `Initialize`, `Adjust` and `Finalize` of controlled types.

Tasking is outside this model: an object shared between tasks is expected
to be volatile, atomic or protected.

## Assertions as assumptions

An `Assert`, `Assert_And_Cut` or `Check` is an obligation at its own position
and an assumption for what follows it, whether or not the obligation was
proved, as in deductive verification generally. A `Proved_Safe` result after
an `Unproved` assertion therefore holds on the condition that the assertion
does; with assertion checks disabled at run time, nothing enforces that
condition. A leading loop invariant is carried past the loop only when it is
proved both initially and at the end of an arbitrary iteration, the last one
included.

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

A precondition or postcondition written on a separate spec applies to the
body only when the spec resolves precisely and conforms to the body
parameter by parameter (same names, modes, and type text, in order); each
spec parameter then denotes the same value as its body counterpart, at entry
and at the normal exit. Otherwise the spec contract contributes no facts.

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
that boundary. If the fixed-point run itself fails (for example on a
Libadalang property error), every obligation of that subprogram is
`Unsupported`: a node the run did not reach is not thereby `Unreachable`.

Within an expression, an operand that is evaluated only under a condition
is checked in the state that condition leaves: the right operand of
`and then` where the left one is true and of `or else` where it is false,
each dependent expression of an `if` expression where the conditions before
it came out as they must to reach it. In `Divisor > 0 and then Total /
Divisor > 1` the division is checked with a positive divisor. Where the
state says the operand is never evaluated its obligations are `Unreachable`;
so are those of a dependent expression of a `case` expression that no value
the selector may have selects, and of the predicate of a quantified
expression over a range known to be empty. The same holds for statements:
the body of a `for` loop over a range known to be empty and a `case`
alternative that the selector does not select are not reached.

`Definite_Error` is a statement about the operation when it executes. Under
a condition the analysis cannot evaluate, such as a call, the state does not
say whether the operation ever executes; a definite error reported there
holds if it does.

Code that is declared inside the subprogram and evaluated later is not
checked in the state at its declaration: a nested expression function, the
default expression of a record component or of a nested subprogram's
parameter, a task or entry body. What an enclosing object holds where such
code is declared says nothing about what it holds where the code runs, so
its obligations are decided with no state at all. A nested subprogram with
a body of its own is verified separately.

The range a stored value is checked against is the one the declaration of
the target gives: the constraint of `Held : Integer range 1 .. 5`, of a
record component or of an array type's components declared that way, of an
access type's designated subtype, and, through a renaming, that of the
renamed object. The check is `Unproved` when the two bounds of that range
are not both known as of its elaboration, and for a target of any other
form.

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
- `tests/run_seeded_defects.sh` for the seeded-defect probe programs;
- `tests/run_proof_path_evidence.sh` for complete `Proved_Safe` producer
  coverage, method-route coverage, and operator / type / join / exception
  sub-boundary routes;
- `tests/run_gnatprove_differential.sh` for clean and deliberately broken
  oracle comparison; and
- `tests/run_all.sh` for the complete repository gate.

Any change that expands a `Proved_Safe` path must update this document, add a
positive case, add a boundary or seeded-defect case, register the producer in
`quality/proof_path_evidence.tsv`, and pass the complete gate. Confirmed
false-safe results follow the [False-Safe Response and Release
Policy](false-safe-response.md).
