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
| Range | Both bounds of the target subtype, resolved as of its elaboration; otherwise scalar bounds VC against those same two bounds | Integer scalar initialization, assignment, and conversion into a signed or modular subtype whose two bounds are both known; a subtype with a bound that is not (`range 1 .. N` for a variable or unconstrained `N`) is `Unproved`. Also the two bounds of a slice written `A (L .. H)`, against the bounds of `A` as an index check takes them: proved when both bounds are within them, or when the slice is known to be null, which Ada does not check. A slice given by a subtype name or a `'Range` is `Unproved`. Also an actual parameter against the subtype of its integer formal, and what an `out` or `in out` formal gives back against the subtype of the actual: raised only where the check is needed, that is not when the receiving subtype has every value of its type nor when the form of the actual alone says it fits (a name of that subtype or of one declared from it, a static value, arithmetic whose interval over the operands' subtypes fits). The way in is decided as an assignment is; the way back is `Unproved` whenever it is raised, nothing being known of the value the callee leaves beyond the formal's subtype. Also the conversion of `X'Length`, a universal integer, to the integer type its context expects, at the attribute: against the base range of the type where the length is an operand of one of the type's own operators, a comparison, a membership test or a range among them, and against the subtype anywhere else -- a qualified expression, or the operand of an operator that a declaration defines, whose formal gives the subtype. None where nothing is converted (both operands universal, or a length that is a static value), and none beside the check of an assignment, an actual parameter or a conversion, which is the one raised there. Where the type is declared with a range of its own its base range is the implementation's to choose: the check is proved when the length is within the declared range and its opposites, which every base range has (RM 3.5.4 (9)), and is `Unproved` otherwise |
| Index | The indexed object's own bounds per dimension -- the index constraint on its declaration, or its constrained array type or subtype -- otherwise scalar bounds VC against those bounds; or, with no bounds a declaration fixes, either the index is the parameter of a `for` loop over that same dimension of that same object (`for I in A'Range`, `A'Range (N)`, or `A'First .. A'Last`), or a scalar VC places it between the object's own `'First` and `'Last` taken as symbols, one pair per dimension | Array objects whose bounds a declaration fixes, and scalar indices. An object of an unconstrained array type that takes its bounds from a string literal, or from another object whose bounds are known, has those bounds. One with no bounds anything fixes (a formal parameter, or an object initialized from one, from a call or from an aggregate) proves only in the own-range loop form or against those symbols: its index subtype says what its bounds may be, not what they are |
| Discriminant | The prefix object's own static discriminant constraint (an integer expression or an enumeration literal) selects the variant declaring the component; a constrained object's discriminants never change | A component of a top-level variant part, selected directly from an object declared with an explicit discriminant constraint; a constant, variable, or subtype-name constraint or choice is never resolved by spelling and stays `Unproved` |
| Initialization | Flow-sensitive definite-initialization state | Tracked scalar objects and documented composite write summaries, at each read; and each `out` parameter at the subprogram's normal exit, proved when every path that returns has assigned the whole parameter or passed it to a callee that always writes it. An `out` parameter assigned component by component is `Unproved`. A global of mode `Output` in a `Global` or `Refined_Global` aspect has the same obligation as an `out` parameter, at its name in the aspect: proved when the state at the normal exit has the whole object initialized, `Unproved` for a state abstraction and when the object is written by a callee only |
| Assertion | Abstract Boolean evaluation; otherwise scalar Boolean VC | `Assert`, `Assert_And_Cut`, and `Check` conditions |
| Precondition | Formal-to-actual substitution and scalar Boolean VC | Resolved calls with supported scalar contracts. An operation whose operator a declaration defines is such a call, and its obligation is at the operator: decided where the precondition says nothing of the operands, `Unproved` where it does, the operands not being substituted for the formals yet |
| Postcondition | Joined normal-exit state and scalar Boolean VC | Supported scalar exits and contract expressions |
| Loop invariant initialization | Entry-edge abstract/symbolic state | Leading invariants on supported loops |
| Loop invariant preservation | Generic one-iteration abstract/symbolic VC | Straight-line scalar body, or a straight-line scalar body containing a non-nested `if`/`elsif`/`else` chain (the `else`, and any number of `elsif` parts, may be omitted) whose arms each independently reach the loop's back edge, joined with the same merge machinery used at ordinary CFG merge points -- one `Join_On_Condition` call per `Condition_Node` in the chain, right-folded so an N-arm chain yields N-1 nested `ite` terms, exactly matching Ada's own `elsif` desugaring; a scalar binding on which two arms disagree is represented at each fold as an SMT `(ite <selector> <true-term> <false-term>)` term, letting facts already established before the branch (such as the loop guard) carry through the disjunction regardless of which arm actually ran -- the selector is the branch's own condition when that condition translates to the scalar VC language (correlating it with any of the condition's own free variables appearing elsewhere in the obligation), or otherwise an anonymous, totally unconstrained boolean symbol standing in for it (sound for any selector value, but unable to correlate with anything else in the obligation); a fresh, unconstrained symbol is used instead of an `ite` only when a binding's own sort disagrees between arms, an unreachable defensive case; array-element and pointer-dereference writes are tolerated (never symbolically tracked, so skipping them leaves no stale binding), but a record-component write is not, since that *is* symbolically tracked and could otherwise resolve to a stale pre-write value; an `elsif`/`else` part is folded only when it continues the *same* `If_Stmt` as the branch that reached it, distinguished by walking the branch condition's AST ancestry back to its owning `If_Stmt` -- a lexically distinct, genuinely nested `If_Stmt`/`Case_Stmt` inside any arm's own body (as opposed to that arm's own `elsif`/`else` continuation), or an independent, sequential `if`/`elsif`/`else`/`case` construct reached after the first one's own arms rejoin, draws on the same per-path `Branch_Budget` (initially 2, spent once per independent chain or case statement entered, never for a chain's own `elsif`/`else` continuations or a case's own sibling alternatives) that the first, outermost conditional itself spent one unit of -- so exactly one such nested-or-sequential second conditional is folded the same way the first is, by the same one-level soundness argument applied recursively (each arm's own recursive walk must still independently reach the loop's back edge before anything is joined); a third independent conditional along any single path exhausts the budget and conservatively bails to `Unproved` with `branch-budget-exceeded` provenance naming the blocking condition, the same as every genuinely nested or sequential conditional did before this budget existed; or a straight-line scalar body containing a single non-nested `case` statement whose alternatives each independently reach the loop's back edge, joined via one `VC.Join_On_Range` call per alternative (bar a trailing, explicit `others`, the fold's base case needing no selector, exactly mirroring `elsif`'s own bare trailing `else`), right-folded the same way the `elsif` chain is -- every alternative but `others` must have exactly one choice in its `F_Choices` (a single expression or a single `..` range, never a `\|`-separated or discontiguous set: unioning multiple choices into one covering range would unsoundly admit selector values that belong to a different, or no, alternative, so a multi-choice alternative is rejected outright rather than range-unioned) and that choice's bounds must be statically known (`Choice_Interval.Known`); the selector for each alternative's `ite` is a range-membership predicate over the case selector's own translated term (`Integer_Term`) rather than a boolean condition, falling back to the same anonymous, totally unconstrained boolean symbol `Join_On_Condition` uses when a selector or bound doesn't translate; a lexically nested `If_Stmt`/`Case_Stmt` inside any one alternative's own body draws on the remaining `Branch_Budget` the same way as for `elsif`, up to the same two-independent-conditionals-per-path limit. A missing or non-final `others`, a multi-choice or discontiguous case alternative, a third independent conditional along any single path (nested or sequential), nested loops, calls, or unsupported transfers remain outside this subset |
| Loop variant progress | Strict two-state scalar progress VC plus static base-type bounds | One leading, single-component `Increases` or `Decreases` variant on the same iteration subset as invariant preservation (straight-line, or with a non-nested `if`/`elsif`/`else` chain or single-choice-per-alternative `case`); usable leading invariants must first discharge |
| Termination | The body is seen to return: no loop but a `for` loop over a discrete range or an array (the same for a quantified expression), no `goto`, tasking or `delay`, no call through an access value or by dispatching, no recursion, direct or through what it calls, and every subprogram it calls seen to return in the same way from its own body. A predefined operation, an intrinsic, an instance of `Unchecked_Conversion` or `Unchecked_Deallocation` and a function of a language-defined or GNAT library unit are taken to return | Raised for each function, and for each procedure that has the aspect `Always_Terminates` or is declared in a package that has it, at the name in its first declaration, unless `SPARK_Mode` is `Off` there. `Unproved` for a `while` or plain loop, even one with a loop variant; for iteration through a user-defined iterator; for a call to a generic formal subprogram, a library procedure, an imported subprogram or one whose body is not among the sources; and for a caller of any subprogram that is not itself shown to return, which GNATprove proves on the assumption that the callee does. Calls the source does not show (a subtype predicate, a default initialization, a finalization) are not followed. Never a `Definite_Error` |
| Data dependencies | An over-approximation of what the body touches is within what its `Global` aspect allows: every name in the body that denotes an object declared outside it, through renamings and dereferences, and the effects of every subprogram it calls, taken from that subprogram's `Global` aspect (its `Refined_Global` where the body is visible) or, when it has none, worked out from its body in the same way. An object that is read must be listed with a mode other than `Proof_In`, unless it is read in assertions only; one that may be written, or whose `'Access` or `'Address` is taken, must be listed as `Output` or `In_Out`. A constituent is accepted under the state abstraction that the `Refined_State` of an enclosing package body, or its own `Part_Of`, puts it in. A constant whose value depends on no variable is not a global | Raised for each subprogram body and expression function that has a `Global` aspect, at the aspect, unless `SPARK_Mode` is `Off` there. It is GNATprove's check: an entry of the aspect that the body does not use, or uses less than its mode allows, does not fail it. `Unproved` when something the body touches is not allowed, and whenever the effects of a callee are not known: no aspect and no body among the sources, a generic formal or imported or library subprogram without an aspect, an instance of a generic subprogram, a call that dispatches or goes through an access value, recursion without an aspect, tasking. Aliasing through access values and reads the source does not show (a default initialization) are not followed. Never a `Definite_Error`: `Global_Contract_Mismatch` reports a violation |
| Flow dependencies | None yet | Raised for each subprogram body and expression function that has a `Depends` aspect, at the aspect, and `Unproved` wherever it is raised. `Depends_Contract_Mismatch` and `Incomplete_Depends_Contract` report what the dependency analysis finds wrong |

## Scalar VC language

The external prover portfolio operates on mathematical integers and Booleans.
The supported translation includes initialized scalar names, integer and
Boolean literals, unary negation and `not`, arithmetic `+`, `-`, and `*`,
comparisons, equality, Boolean connectives, supported integer conversions,
bounded quantifiers, and side-effect-free expression functions that can be
inlined within the depth limit. Integer `/`, `mod`, and `rem` are translated
only when the divisor is provably nonzero and their Ada sign semantics are
encoded.

An operator is the operation its symbol stands for only where it denotes
that operation. Where a declaration defines a function for it -- for a type
of the program, in the place of a predefined operator of `Integer` or
`Boolean`, inherited by a derived type, or as a renaming of another
function -- the operation is a call of that function: it has no value the
analysis knows, a condition written with it says nothing of its operands,
and it has no division or overflow check of its own, its precondition
being the obligation. What it returns is within the subtype of its result.
An operator that does not resolve has no known value either, and keeps the
checks of the predefined operation. The short-circuit forms, ranges and
membership tests are always what they read as, no declaration being able
to define them.

A name written with its package in front of it -- an expanded name -- is
the entity it names: an object, an enumeration literal or a named number.
A named number is its value, where its declaration is written with integer
literals, other named numbers, constants, `T'First` and `T'Last`, qualified
expressions and the arithmetic operators; each operator is taken in the
type its operands give it, so that one of a modular type wraps. A real
named number, and one declared with any other attribute, a conversion, a
call or a conditional expression, has no value the analysis knows.

`T'Size` is a number where `T` is a static integer or enumeration subtype
named outright. It is the `Size` the first subtype is given by an aspect or
an attribute definition clause, for that subtype and for a subtype or a
derived type that adds no constraint to it; otherwise it is the number of
bits the values of the subtype take, with a sign bit only if one of them is
negative and no bit at all for a range without a value, as RM 13.3(55)
recommends and GNAT does: 8 for `mod 2 ** 8`, 7 for `range 0 .. 100`, 31
for `Natural`, 2 for a constrained subtype `range 0 .. 3` of a type given
`Size => 16`. For the predefined integer types the ranges are those the
analysis takes them to have throughout. `T'Size` stays unknown for a
generic formal type, a private type, a character type, an enumeration type
with a representation clause, a range of an enumeration type, bounds that
are not static, `T'Base` and `T'Class`, a type that is not discrete, and
for an object: the size of an object is the target's affair.

Symbolic assignments resolve their scalar sort from Ada semantic type
identity: signed integers use mathematical-integer terms, `Standard.Boolean`
uses SMT Boolean terms, and enumeration values use their declaration-order
positions. Unsupported scalar types and inconsistent bindings stop translation
with explicit `sort-mismatch` provenance rather than being inferred from the
absence of interval facts.

Whatever the state, `X'Length` is from zero to the number of values of the
index subtype of that dimension, where that subtype is an integer one with
static bounds: the bounds of an array that is not empty are within it. An
array over `Positive` has no more than `Integer'Last` components, one over
`Natural` may have one more than that, and the difference decides whether
the conversion of its length to `Integer` is proved.

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

- A condition that evaluates a function call which may change state --
  the same test as above -- establishes nothing about what the call may
  write, even about what it tested first: the call may come after the
  test. In `Count > 0 and then Reset and then Total / Count > 1`, where
  `Reset` may write `Count`, the division is not checked with a positive
  divisor. What such a call may write is every object when the callee is
  declared inside the subprogram under analysis or writes an actual, and
  otherwise every object declared outside that subprogram. The symbolic
  state is dropped as well. A call that evaluates a default expression
  which changes state is such a call.
- A procedure call drops every fact when what the callee does is not
  known: no effect summary of its body, no `Global` aspect, a callee
  declared inside the subprogram under analysis, a dispatching call.
  When it is known, the *call frame* stands: what the symbolic state says
  of a scalar object declared in the subprogram under analysis that the
  call does not have as an `out` or `in out` actual still holds after the
  call. Everything else gets a value of which nothing is known: each
  object declared outside the subprogram, each actual the call may write
  (every name in it), every record component of whatever object, and the
  value of every object that is not a scalar.

Tasking is outside this model: an object shared between tasks is expected
to be volatile, atomic or protected.

## Calls as terms

A call that the scalar VC language cannot look into -- the callee is not an
expression function, or an argument is not a scalar -- is still a term when
the callee is a *function of its arguments*: two calls with the same
arguments have the same result. That is all the term says. `Has_Buffer
(Ctx)` in the precondition of the subprogram under analysis proves the
`Has_Buffer (Ctx)` that a callee's precondition asks, as long as `Ctx` has
not changed in between; inside a precondition, `Valid (Ctx) and then Size
(Ctx) > 0` proves the precondition `Valid (Ctx)` of `Size`. Nothing is known
of the result beyond that, not even its subtype.

A function of its arguments is one that

- is under an explicit `SPARK_Mode`, on the declaration, an enclosing unit
  or the project, and has neither the `Side_Effects` nor the
  `Volatile_Function` aspect;
- has no `out` or `in out` parameter; and
- is known to read and write no object declared outside it: its `Global`
  aspect is `null`, or it has none and its body, with everything it calls,
  was followed to the end and touches none. A constant whose value depends
  on no variable is not such an object. A library subprogram without a
  `Global` aspect, an imported one that is not intrinsic, a generic formal
  subprogram, a dispatching call and a call through an access value are
  never such functions.

A function of a generic unit is a different function in each instance.
A call that leaves a formal to its default is a different term from one
that gives it.

An argument that is not a scalar is the value of a whole object (a
variable, a constant or a parameter that is not volatile, not a task and not
a protected object), of a record component of one reached without a
dereference, or the result of another such call whose type is not an access
type. An object keeps its value until something may have changed it, and
then no fact about the old value says anything of the new one:

- an assignment to the object, to a component of it, or through a
  dereference drops the symbolic state;
- an assignment to an element or a slice of *any* array, and a call in an
  expression to a function that is not a literal, a predefined operation or
  under an explicit `SPARK_Mode`, give every object that is not a scalar a
  new value. Which objects an element belongs to, or is reached from
  through an access value, is not worked out, and two parameters passed by
  reference may be one object;
- a procedure call does the same where it does not drop everything (see the
  call frame above);
- a loop, a join of paths that disagree and an exception handler keep what
  they keep of any other symbolic fact.

A function that is not a function of its arguments is no term: the check
that depends on it is `Unproved`, with the reason the callee could not be
inlined.

When the callee of a call under proof has a formal that is not a scalar,
the formal stands for the actual's value. On a recursive call, where the
caller's state already speaks of that very formal, the symbolic state is
dropped instead.

The symbols handed to the solvers are named after the file, the line and
the column of the object they stand for.

## The postcondition of a callee

After a procedure call returns, what the callee's postcondition says is
assumed, as an assertion is: whether it holds is the obligation of the
callee's own verification. It is assumed operand by operand, of the caller's
own objects, each formal standing for what the caller sees after the call:

- a formal the call writes stands for the object that is its actual, when
  that is a whole object declared in the subprogram under analysis;
- any other formal stands for its actual as it is after the call, when the
  call cannot have changed what the actual reads: a literal, a constant, a
  loop parameter, an object of the subprogram under analysis that the call
  does not write, and predefined operations on those.

An operand that names a formal with neither is not assumed -- one left to
its default, one whose actual is a call or a component, one whose actual
is declared outside the subprogram under analysis -- and so is an operand
with `'Old`, which the scalar VC language does not express. The first of
two calls on an object thus gives the second its precondition where the
postcondition states it outright, not where it states that something is
unchanged.

Nothing is assumed where a fact could be about another value than the one
the caller sees: the callee is declared inside the subprogram under
analysis, which lets it name the caller's objects; an actual the call
writes is declared outside it, where the callee can name it too; two
actuals name one object and one of them is written; an actual takes an
access or an address; the call dispatches; the callee is under `SPARK_Mode
=> Off`; or the postcondition calls a function that may change state or is
not taken to leave everything as it is. The postcondition is the one on
the declaration the call resolves to or, for a body, on the declaration it
completes when that is resolved exactly.

What a callee of unknown effects leaves is nothing but this: its
postcondition is assumed in a state that knows nothing else.

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

A condition that holds is taken operand by operand: each operand of `and`
and `and then` where it is true, of `or` and `or else` where it is false,
through `not` and parentheses. An operand the scalar VC language cannot
express contributes nothing and does not cost the others: of `Ready (Ctx)
and then Count > 0` with `Ready` outside the language, `Count > 0` is still
known.

The walk that proves a leading loop invariant preserved goes through the
loop body with the same effects as the analysis of the subprogram: a
procedure call, and a function call that may change state, change what they
may change (see above) before the invariant is checked again.

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
loops, with or without a name; exits, including one that names the loop it
leaves; a `goto` to a label further down; returns; raises; nested blocks,
with or without a name; and conservative exception-handler dispatch. An
exit that names a loop goes to the end of the innermost enclosing loop of
that name. A `goto` to a label further down is one more way into that
label, so what holds there is what holds on every way in; a `goto` back up
to a label makes a cycle that no loop statement heads, and puts the
subprogram outside the subset, as SPARK itself excludes it. A loop
invariant is not proved preserved by a body that has a `goto` on the way to
its end. Fixed-point iteration widens growing loop ranges.
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

A `Definite_Error` is reported on the showing of a converged state only.
While a loop is iterated to its fixed point a state is one that some path
reaches, not yet the join of all of them, and what fails in it need not
fail in the end.

`Definite_Error` is a statement about the operation when it executes. Under
a condition the analysis cannot evaluate, such as a call, the state does not
say whether the operation ever executes; a definite error reported there
holds if it does.

An expression function is verified as a subprogram, wherever it is
declared: its graph is the one evaluation of its expression, entered with
the subtypes of its parameters and what its precondition says. A nested
subprogram body or expression function is verified on its own, from its own
entry state, and what it reads of the enclosing subprogram's objects is
unknown to it.

The checks inside the precondition and the postcondition of a verified
subprogram are obligations too. The precondition is evaluated on entry,
before it is assumed: nothing is known there but the subtypes of the
parameters, and what the precondition itself establishes operand by
operand. The postcondition is evaluated in the state at the normal exit.
Where the subprogram is outside the verified subset these obligations are
`Unsupported`.

The prefix of `'Old` and that of `'Loop_Entry` are evaluated earlier than
where the attribute is written, and their checks are decided in the state
of that earlier place. For an `'Old` of the postcondition it is the state
on entry, once the precondition holds. For a `'Loop_Entry` that names no
loop it is the state of the header of the innermost loop, which holds each
time the header is reached, the first time included. The checks of any
other such prefix -- a `'Loop_Entry` that names a loop, an `'Old` in a
`Contract_Cases` -- are decided with no state at all. The
prefix is evaluated whether or not the place where the attribute is
written is reached, so none of its obligations is `Unreachable` because
that place is.

A quantified expression is decided where it is evaluated as a condition:
in a `Pre` or a `Post`, and in an `Assert`, an `Assert_And_Cut` or a
`Loop_Invariant`. One that is used as a value anywhere else in a body --
the condition of an `if`, the right side of an assignment -- puts the
subprogram outside the verified subset.

Other code that is declared inside the subprogram and evaluated later is
not checked in the state at its declaration: the default expression of a
record component or of a nested subprogram's parameter, a task or entry
body. What an enclosing object holds where such code is declared says
nothing about what it holds where the code runs, so its obligations are
decided with no state at all.

The range a stored value is checked against is the one the declaration of
the target gives: the constraint of `Held : Integer range 1 .. 5`, of a
record component or of an array type's components declared that way, of an
access type's designated subtype, and, through a renaming, that of the
renamed object. The check is `Unproved` when the two bounds of that range
are not both known as of its elaboration, and for a target of any other
form.

Explicit access dereference, general alias/points-to reasoning, tasking,
protected operations, dispatching/class-wide calls, floating-point proof,
unchecked conversion, target-dependent representation other than the
`Size` of a static discrete subtype, and unmodeled exception semantics are
outside the supported subset. Other unsupported
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
