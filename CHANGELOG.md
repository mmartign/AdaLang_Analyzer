# Changelog

All notable changes to AdaLang Analyzer are documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versioning follows [Semantic Versioning](https://semver.org/).

## [1.8.2] - 2026-10-06

A `--verify` release that proves more of what GNATprove proves, with the
obligations of 1.8.1: what is known now carries across calls. Three
false-safes in the checks that were already there are fixed (`FP-109`,
`FP-110`, `FP-111`).

Of the 15,043 checks GNATprove proves on the five fully proved corpora,
`--verify` proves 3,536 (3,018 in 1.8.1), 479 of the 2,938 preconditions
among them (24 in 1.8.1), with no check it proves that GNATprove does not
and no definite error on a check GNATprove proves
(`benchmarks/GNATPROVE_GAP_LEDGER_2026-10-05.md`). No finding changed in
any of the ten corpora re-run.

What to expect when upgrading:

- More preconditions are `Proved_Safe`, most of them in code whose
  contracts call functions on a record or a private object (`Has_Buffer
  (Ctx)`).
- Some results that 1.8.1 reported `Proved_Safe` are `Unproved`: the
  division, index and range checks that depended on a test which a function
  call in the same condition can undo (`FP-109`), and the preservation of a
  loop invariant about an object that a call in the loop body may write
  (`FP-111`).

### Added

- A call the scalar VC language cannot look into is a term when the callee
  is a function of its arguments: under an explicit `SPARK_Mode`, without
  `Side_Effects` or `Volatile_Function`, with no `out` or `in out`
  parameter, and known to touch no object declared outside it. What is
  known of `Has_Buffer (Ctx)` then holds wherever it is asked of the same,
  unchanged `Ctx`: the precondition of the subprogram under analysis proves
  the precondition of what it calls, and inside a precondition the operand
  before a call proves the call's own. An argument that is not a scalar is
  the value of a whole object, of a component of one, or the result of
  another such call; a function of a generic unit is a different function
  in each instance. See "Calls as terms" in
  `docs/src/supported-verification-subset.md` for when an object's value
  is taken to have changed.
- A procedure call whose effects are known, from the summary of the
  callee's body or from its `Global` aspect, no longer drops every symbolic
  fact. What is known of a scalar declared in the subprogram under analysis
  that the call does not write still holds after it: `Offset + Remaining =
  Length` survives a call that names neither, in straight-line code and as
  a loop invariant.
- A condition that holds is assumed operand by operand. One operand the
  scalar VC language cannot express no longer costs the others.
- The postcondition of a callee is assumed after a procedure call, of the
  object the call wrote and of the scalars it was given that it cannot have
  changed: `Reset (Ctx)` with `Post => Has_Buffer (Ctx)` gives the next call
  its precondition, and a loop invariant is preserved by the call that
  re-establishes it. See "The postcondition of a callee" in
  `docs/src/supported-verification-subset.md` for the formals it is assumed
  of and for the calls after which nothing is assumed.

### Fixed

- What a condition establishes about an object no longer survives a
  function call in the same condition that may change the object
  (`FP-109`, a false-safe). In `Divisor > 0 and then Reset and then 10 /
  Divisor > 1`, where `Reset` sets `Divisor` to zero, the division was
  `Proved_Safe`; so was a division in the branch that such a condition
  guards, after an assertion of it, and in the body of a loop it controls.
- The symbols given to the solvers are named after the file of the object
  they stand for as well as its line and column (`FP-110`, a false-safe).
  An object of a body declared at the position where the specification
  declares another was the same symbol, and what a precondition says of
  one parameter was taken for the other.
- The proof that a loop invariant is preserved, and that a loop variant
  progresses, takes into account what the calls in the loop body change
  (`FP-111`, a false-safe). After `pragma Loop_Invariant (Kept > 0)`, a call
  `Lower (Kept)` in the body left the invariant `Proved_Safe`.

### Changed

- `tests/run_verification_mutations.sh` analyzes a package-body fixture
  together with its sibling specification, as
  `tests/run_proof_path_evidence.sh` does. The mutation manifest has 102
  seeded defects (61 in 1.8.1).

### Known limitations

- One loop invariant of the Tokeneer corpus that GNATprove proves and 1.8.1
  reported preserved is `Unproved`: the loop calls a procedure nested in the
  same subprogram, after which nothing is kept.
- Nothing is known of the result of a function term, not even its subtype,
  nor of how it is defined: a call is not related to the expression function
  body it stands for, and the predicate of an object's type is not assumed.
  Most of the preconditions still `Unproved` in the RecordFlux code of the
  CoAP-SPARK corpus need both.
- An operand of a postcondition with `'Old` is not assumed after a call.

## [1.8.1] - 2026-10-05

A `--verify` release that narrows the distance to GNATprove, measured check
by check. Three obligation kinds are new: termination, and the data and
flow dependencies of `Global` and `Depends` aspects. Expression functions
are verified as subprograms, and the checks inside preconditions and
postconditions, the range check on an actual parameter, the bounds of a
slice and the initialization of `out` parameters and `Output` globals are
obligations where GNATprove has a check. Three faults are fixed in the
checks that were already there; two of them, `FP-107` and `FP-108`, are
false-safes.

Of the 15,043 checks GNATprove proves on the five fully proved corpora,
`--verify` proves 3,018 (467 in 1.8.0) and has an obligation for 11,922
(6,903 in 1.8.0), with no check it proves that GNATprove does not and no
definite error on a check GNATprove proves
(`benchmarks/GNATPROVE_GAP_LEDGER_2026-10-05.md`). No finding changed in
any of the ten corpora re-run.

What to expect when upgrading:

- `--verify` reports more obligations in every code base, most of them
  `Unproved` or `Unsupported` where 1.8.0 raised nothing: its totals are not
  comparable with those of 1.8.0. The `kind` of an obligation in the JSON
  and SARIF reports has three new values, `termination`,
  `data-dependencies` and `flow-dependencies`.
- The termination obligation is raised for every function that is not
  under `SPARK_Mode => Off`, in SPARK code or not.
- A `flow-dependencies` obligation is always `Unproved`: no route proves a
  `Depends` aspect yet.
- Some range checks that 1.8.0 proved are `Unproved` (`FP-107`), and
  `Known_Range_Check_Failure` reports a value stored out of the range its
  target is declared with.

### Added

- `--verify` raises an initialization obligation for each `out` parameter
  at its subprogram's normal exit: proved when every path that returns has
  assigned the whole parameter or passed it to a callee that always writes
  it, `Unproved` otherwise. It is located at the parameter in the
  declaration the caller sees. GNATprove agrees on every parameter of the
  two fixtures added to the differential test for it.
- An initialization obligation carries a `subject` in JSON: the declaration
  of the object it is about.
- `--verify` raises a range-check obligation for the bounds of a slice
  `A (L .. H)`, located at `A` as GNATprove's is: proved when both bounds
  are within the bounds of `A`, by the same routes as an index check, or
  when the slice is known to be null; `Unproved` otherwise, and when the
  slice is given by a subtype name or a `'Range`. GNATprove agrees on every
  slice of the two fixtures added to the differential test for it.
- `--verify` raises a range-check obligation for an actual parameter,
  located at the actual as GNATprove's is: its value must fit the subtype
  of an integer formal on the way in, and what an `out` or `in out` formal
  gives back must fit the subtype of the actual. It is raised only where
  the check is needed: not when the receiving subtype has every value of
  its type (a modular type, a predefined integer type), nor when the form
  of the actual alone says it fits, as a compiler works it out. The way in
  is proved, refuted or left `Unproved` as an assignment is; the way back
  is `Unproved`. GNATprove agrees on every actual of the two fixtures added
  to the differential test for it; six mutations, and the three seeded
  parameter-passing defects that raised no obligation now raise one.
- `--verify` has a `termination` obligation: that a subprogram returns. It
  is raised where SPARK requires it, for each function and for each
  procedure that has the aspect `Always_Terminates` or is declared in a
  package that has it, at the name in its first declaration, which is where
  GNATprove reports its check. It is proved when the body is seen to return:
  no loop but a `for` loop over a range or an array, no recursion, direct or
  through what it calls, and nothing called but subprograms seen to return
  in the same way from their own bodies. Everything else is `Unproved`; the
  analysis never says a subprogram does not terminate. It is stricter than
  GNATprove in one respect: a caller of a subprogram that is not shown to
  return is not proved, where GNATprove assumes the callee returns.
  GNATprove agrees on every subprogram of the two fixtures added to the
  differential test for it; six mutations.
- `--verify` has a `data-dependencies` obligation for a `Global` aspect:
  that the subprogram reads and writes no object declared outside it that
  the aspect does not allow. It is raised at the aspect, where GNATprove
  reports its check, and it is the same check: what is read must be listed,
  with a mode other than `Proof_In` unless it is read in assertions only;
  what may be written must be listed as `Output` or `In_Out`; an entry the
  body does not use does not fail it. It is proved from an
  over-approximation of what the body touches, including the effects of
  what it calls, by their own aspect or, when they have none, by their
  body, and is `Unproved` as soon as the effects of a callee are not known.
  A constituent is accepted under the state abstraction it belongs to.
- A global of mode `Output` has an initialization obligation at its name in
  the `Global` or `Refined_Global` aspect, decided as that of an `out`
  parameter is.
- `--verify` has a `flow-dependencies` obligation for a `Depends` aspect,
  at the aspect. No route proves it yet: it is `Unproved` wherever it is
  raised, and `Depends_Contract_Mismatch` reports a wrong one as before.
- GNATprove agrees on every aspect of the two flow-contract fixtures added
  to the differential test, which now also runs GNATprove's flow analysis
  on them; seven mutations.
- `--verify` verifies an expression function as a subprogram, wherever it
  is declared: its expression is checked from the subtypes of its
  parameters and what its precondition says, and its postcondition at the
  exit. Until now only a subprogram body was verified; an expression
  function at package level raised no obligation at all, and one nested in
  a subprogram was checked with no state.
- The checks inside a precondition and a postcondition are obligations of
  their own, with a final verdict: the precondition is evaluated on entry,
  before anything is known beyond the subtypes of the parameters, the
  postcondition at the normal exit. A call there has its precondition
  checked, under the guard that stands before it. Where the subprogram is
  outside the verified subset these obligations are `Unsupported`, as those
  of its body are, and no longer missing.
- GNATprove agrees on every check of the two fixtures added to the
  differential test for both; four mutations.
- The gap ledger (`benchmarks/gnatprove_gap_ledger.py`) pairs GNATprove's
  one "initialization of X" check per object with AdaLang's obligations
  about that object. Of the 15,043 checks GNATprove proves on the five fully
  proved corpora AdaLang now proves 3,018 (467 before) and has an obligation
  for 11,922 (6,903 before), still with no disagreement in either direction.

### Fixed

- A check on an operation that is never evaluated is no longer made as if
  it were (`FP-106`). With `Count` known to be zero, `Count > 0 and then
  Total / Count > 1` was reported as a division by zero, by
  `Division_By_Zero` and as a definite error under `--verify`; so were an
  indexing or a conversion behind such a guard (`Known_Index_Check_Failure`,
  `Known_Range_Check_Failure`). The right operand of `and then` and of
  `or else` and the dependent expressions of an `if` expression are now
  checked in the state their condition leaves, and not at all where that
  state says they are never evaluated; the same goes for a dependent
  expression of a `case` expression and a `case` statement alternative that
  the selector does not select, and for the predicate of a quantified
  expression and the body of a `for` loop over a range known to be empty.
  `=` and `/=` are decided between two objects known to have one and the
  same value. Under `--verify` such operations are `Unreachable`, and a
  check that a guard protects is now proved: the division in `Divisor > 0
  and then Total / Divisor > 1`, the indexing in `(if Position in 1 .. 4
  then Table (Position) else 0)`. Found by probing the existing checks
  before adding a new one; GNATprove proves every check of the fixture that
  the analyzer called a certain failure.
- A range check is made against the constraint the declaration of the
  target adds to its type (`FP-107`, a false-safe). After `Held : Integer
  range 1 .. 5`, the assignment `Held := Wide` of any `Integer` was proved
  under `--verify` and `Held := 9` was not reported by
  `Known_Range_Check_Failure`: the check looked at `Integer` alone. The same
  held for a record component and for the components of an array declared
  with a range, for `Kept : Small range 2 .. 3` (where `Kept := Small
  (Cast)` was proved), and for an assignment through a renaming, checked
  against the subtype mark of the renaming instead of the subtype of the
  renamed object. The check now uses the range the declaration gives and is
  `Unproved` when its two bounds are not both known. Expect checks that
  were proved to become `Unproved`, and new `Known_Range_Check_Failure`
  findings where a value known to be out of that range is stored.
- Under `--verify`, a nested expression function, the default expression of
  a record component or of a nested subprogram's parameter and a task or
  entry body are no longer checked in the state at their declaration
  (`FP-108`, a false-safe and a false positive). A division by an enclosing
  object was proved when the object was non-zero where the function is
  declared and zero where it is called, and reported as a certain failure
  the other way round. Such code is evaluated later, in a state the pass
  over the enclosing subprogram does not know; its checks are now decided
  with no state, as GNATprove decides them.

## [1.8.0] - 2026-10-05

A coding-standard release: 175 opt-in checks take the catalogue from 127
to 302 and give every one of GNATcheck's 212 general-purpose rules a
counterpart, checks can take parameters, names of imported projects
resolve, and a project's preprocessing switches are applied. The checks
answer to GNATcheck's rule names as well as their own. The presets enable
the checks they did; on code split across projects the existing checks and
`--verify` see more than before (`FP-102`), and an empty `when others`
handler is reported once where two checks used to report it. All GNATcheck
corpus comparisons were re-run, and the analyzer side of the GNATprove
comparisons: zero possible
unsoundness and zero false positives wherever GNATprove is an oracle.

### Added

- 175 opt-in coding-standard checks, taking the catalogue from 127 to 302:
  naming conventions (`Identifier_Casing`, `Identifier_Prefixes`,
  `Identifier_Suffixes`), layout and comments, restricted constructs,
  positional associations, object-oriented design, representation items
  and address overlays, complexity and size limits, and "this can be
  written more directly" suggestions. No preset enables them, so
  `--recommended`, `--spark`, `--verify`, `--automotive` and `--do178c`
  report exactly what they did; a project selects the ones its coding
  standard requires with `-checks=`.
- `-rule-param=<check>.<name>=<value>` sets a named parameter of one check:
  a limit (`Maximum_Subprogram_Lines.n`), a scheme
  (`Identifier_Casing.type`), or a comma-separated list
  (`Forbidden_Attribute.forbidden`). Checks that state a project convention
  report nothing until their parameters are set.
- Each new check is paired with a GNATcheck rule and follows its behaviour.
  With them, every one of GNATcheck's 212 general-purpose rules has an
  AdaLang counterpart (its 123 `kp_*` compiler known-problem detectors are
  out of scope). Every pairing was compared with GNATcheck by file and
  line on the check's fixtures, on this repository's other test fixtures
  and on the analyzer's own sources. `docs/src/gnatcheck-rule-comparison.md`
  lists them, including the one deliberate difference
  (`Declaration_In_Block` follows GNATcheck's manual where GNATcheck's
  implementation does not).
- Four of the new checks look beyond the unit being walked.
  `Unavailable_Body_Call` reports calls to a subprogram whose body is not
  among the sources, and `Deeply_Nested_Inlining` chains of inlined calls
  deeper than `n`. `Integer_Type_As_Enumeration` and `Same_Instantiation`
  compare every analyzed source with every other, in a pass after the
  per-file walk, and take uses in the sources of imported projects into
  account.
- Three of the new checks report what GNAT detects: `Compiler_Warning`,
  `Compiler_Style_Check` and `Compiler_Restriction`, selected by the
  `options` (`-gnatw` or `-gnaty` letters) and `restrictions` parameters.
  The sources are compiled for semantic checks only, in a temporary
  directory; these checks need GNAT on the path, and gprbuild when a
  project file is given.
- A check can be named by the GNATcheck rule it is paired with, wherever a
  check name is accepted and without regard to case:
  `-checks=positional_parameters`, `+RPositional_Parameters`,
  `-rule-param=maximum_parameters.n=6`. All 212 general-purpose GNATcheck
  rule names are known; a rule that is several checks here
  (`null_paths`) selects them all. `-list-checks` shows the rule names each
  check answers to. Findings keep the check's own name.
- `benchmarks/gnatprove_gap_ledger.py` accounts for every check GNATprove
  proves on a corpus and what `--verify` does at that place; the first
  ledger is `benchmarks/GNATPROVE_GAP_LEDGER_2026-10-05.md`. On the five
  fully proved corpora GNATprove proves 15,043 checks: AdaLang proves 467
  of them, has an undecided obligation for 6,436 and none for 8,140.

### Changed

- The precision corpus grows from 345 to 609 cases: a finding and a clean
  fixture for every new check that runs without parameters, and one
  regression case from the corpus runs.
- An empty `when others` handler is reported once when both
  `Empty_Exception_Handler` and `Exception_Swallowed` are enabled, by
  `Exception_Swallowed`. Both used to report it, with `--recommended` among
  others. `Empty_Exception_Handler` alone still reports every empty handler.

### Fixed

- With a project file (`-P`), names that denote entities of an imported
  project now resolve (`FP-102`). The analyzer looked up units only among
  the root project's own sources, so on a code base split across projects
  every check that needs a type or a declaration went quiet, and
  `skippedChecks` grew large (10,823 on gnatcoll-core, now 55). The sources
  of imported projects are added to the name lookup; they are still not
  analyzed. Found by running the coding-standard checks against GNATcheck
  on the benchmark corpora, where gnatcoll-core went from 13,007 to 19,903
  of GNATcheck's 19,916 findings.

  This changes results on multi-project code for the existing checks too:
  more calls resolve, so `Dead_Store`, `Exception_Propagation`,
  `Missing_Global_Contract` and others report findings they could not see
  before. `--verify` results on such code change for the same reason:
  re-running the analyzer side of the GNATprove comparisons in
  `benchmarks/` keeps zero possible unsoundness and zero false positives,
  with nine more matched pairs on coap_spark and one more on CubedOS,
  where the `Unsupported` obligations drop from 667 to 32.

- With a project file, sources that use the GNAT preprocessor are now
  analyzed (`FP-103`). The preprocessing the project asks for with
  `-gnateD` and `-gnatep` switches is applied when the sources are read;
  before, such a file failed to parse and no check ran on it. Lines that
  preprocessing leaves out are blanked, so findings keep their positions.
  On Tokeneer this adds 294 findings that GNATcheck reports too. The units
  of such files are also found from other units: Libadalang's provider
  over a list of files leaves out the files that do not parse as they
  stand.
- `Constant_Condition` no longer reports a condition on an object that a
  call in the initial value of a later declaration writes through an `out`
  or `in out` parameter (`FP-105`).
- A proof obligation or finding is reported in the file its node is written
  in (`FP-104`). An obligation of a contract, which is written in the
  specification and evaluated while the body is verified, used to carry the
  body's file name with the specification's line. The stable identifiers of
  those obligations change. With the fix 949 more obligations pair with a
  GNATprove check on the benchmark corpora, and the matched pairs go from
  2,392 to 2,871, still with no possible unsoundness and no false positive.

### Known limitations

- On the ten external benchmark corpora, GNATcheck confirms 99.7% of the
  new checks' 93,771 findings in the files both tools analysed, and the new
  checks report 99.8% of GNATcheck's 93,631 (`benchmarks/README.md`).
- A source with preprocessor directives that is given without a project
  file does not parse and is not analyzed.
- GNATcheck also reports inside the instances of generic units; the new
  checks do not follow instantiations.
- `Integer_Type_As_Enumeration` and GNATcheck's rule both depend on which
  sources are loaded, and GNATcheck loads more: 15 findings on three
  corpora have no GNATcheck counterpart for that reason.
- `Missing_Header` and `Actual_Parameter` were not compared with GNATcheck:
  the local GNATcheck build did not accept their parameters on the command
  line.
- `quality/corpus_exercise_coverage.tsv` covers the preset runs only, so it
  lists the new checks as not exercised although the GNATcheck lane ran
  them.

## [1.7.0] - 2026-10-03

A `--verify` precision release: one false `Definite_Error` fixed and two
additions to what array bounds are known. All eleven benchmark corpora were
re-run: zero possible unsoundness and zero false positives wherever
GNATprove is an oracle, and nothing that was `Proved_Safe` stopped being so
(`quality/external_corpus_findings.md`).

### Fixed

- `--verify` no longer loses what it knows about related objects after an
  `if` whose branch holds two or more statements (`FP-101`). The fixed
  point visited the statements after such an `if` before its branches had
  been joined, and the second visit joined its state with the first instead
  of replacing it, which gave every object the two disagreed on a value of
  its own. After `Y := X + 1; X := X + 1;` the condition `Y = X` was then
  not known to hold: its `else` branch looked reachable and a division by
  `N - N` there was a `Definite_Error`, although it can never run. A node
  that only one edge leads to now takes exactly the state that edge
  carries. Found by the seeded-defect probe `h07`; five of its marked safe
  divisions that were `Unproved` are now `Proved_Safe`.

### Added

- Symbolic array bounds for every dimension. `A'First (2)`, `A'Last (2)`,
  `A'Length (2)` and `A'Range (2)` of an object whose bounds no declaration
  fixes are symbols of their own, so an index into the second dimension of
  an unconstrained formal proves from a precondition, a guard or a loop
  over that dimension, as one into the first already did. The dimension
  must be written as an integer literal.
- An object of an unconstrained array subtype has the bounds of its initial
  value when that is a string literal or another array object whose bounds
  are known: `Word : constant String := "abcd";` is `1 .. 4`, and an index
  outside it is a `Definite_Error`.

### Changed

- `tests/run_performance_smoke.sh` takes its default limit from the size of
  the analyzer's own source, which is its workload: 0.55 ms for each line,
  and at least 15 s. `ADALANG_MAX_SMOKE_SECONDS` still overrides it.
- The proof-path evidence has 63 routes over 20 producers.

## [1.6.2] - 2026-10-02

Corrective release for 1.6.1. Running 1.6.1 on all eleven benchmark corpora
found a severe `--verify` slowdown on large projects and two false
`Definite_Error` results, all introduced by 1.6.1. No false-safe result is
involved: every `Proved_Safe` result of 1.6.1 stands.

### Fixed

- `--verify` run time on large projects, which 1.6.1 made much worse. To
  decide whether a function called in an expression may change state
  (`FP-093`), 1.6.1 reads the callee's body and the bodies it calls, four
  levels deep, and did so again at every call site. The work grew with the
  fourth power of the number of calls in a body: the AWS verify lane (348
  files) took 159 s with 1.6.0 and 39 minutes with 1.6.1; it now takes
  69 s. The answer is worked out once for each callee and depth in a unit,
  and the walk of a callee body stops at the first such call.
- `--verify` starts far fewer solver processes. A query whose text was
  already answered in the same run is not sent again (the fixed point
  evaluates a node several times, and 65% of libkeccak's solver runs
  repeated an earlier one), and Z3 no longer runs when CVC5 has already
  given an answer other than UNSAT, since only an UNSAT answer from both is
  ever used. libkeccak: 18,670 solver processes with 1.6.1, 3,418 now.

  Neither change alters a result: the reports for AWS, libkeccak and
  gnatcoll-core are byte-identical to 1.6.1's.
- The actual of a function's `out` parameter is no longer reported as
  read uninitialized after the call (`FP-099`, a false positive introduced
  in 1.6.1). In `if Decode (Input, C) then Result := C;` the read of `C`
  was a `Definite_Error`: the call's effect on the actual's value was
  modelled, but not that the call may initialize it. The read is now
  `Unproved`. Found by the corpus refresh, on AWS.
- An initial value whose computation always overflows no longer gets a
  second `Definite_Error` for the range check that would follow
  (`FP-100`, also introduced in 1.6.1): the check is never reached.
  `X : constant Natural := Ident (Integer'Last) + 1;` reports the overflow
  only. Found by the corpus refresh, on the SPARK testsuite.

### Added

- `tests/run_seeded_defects.sh`, part of `tests/run_all.sh`: the fifteen
  seeded-defect probe programs that found the 1.6.1 false-safes, now under
  `tests/seeded_defects/`. A marked defect reported `Proved_Safe` or
  `Unreachable` fails the gate, and `quality/seeded_defect_outcomes.tsv`
  pins the outcome of all 406 marked lines.

### Changed

- Re-ran all eleven benchmark corpora, including both lanes of the seven
  GNATprove-oracle SPARK corpora; results are in each
  `benchmarks/<corpus>/RESULTS_2026-10-02.md`. Zero possible unsoundness
  and zero false positives on every corpus with an oracle. The five
  fully-proved corpora now give 2,366 matched obligations (2,277 before):
  coap_spark gains 89 pairs from the precondition obligations `FP-096`
  added.

## [1.6.1] - 2026-10-02

Corrective release. Eleven false-safe results in `--verify` are fixed. Each
reported an obligation `Proved_Safe` that a legal execution can violate.

**Affected versions.** Every release up to and including 1.6.0 that offers
`--verify`. In those versions a `Proved_Safe` result is not trustworthy for
the obligations listed under Fixed below: index and range checks on arrays
or subtypes whose bounds are not statically known, any obligation in a
subprogram that contains a loop (in particular one over an empty range) or
modular arithmetic, and any obligation that depends on an object that is
renamed, overlaid, volatile, atomic, aliased, written through an expanded
name, or changed by a function, a controlled operation or a default
initializer. Re-run `--verify` with 1.6.1 before relying on such results.
Rule findings without `--verify` are not affected.

The defects were found by seeded-defect probing: small programs in which a
marked check really fails. Proved-safe counts change as a result:
index checks on unconstrained array parameters, range checks against a
subtype with a bound that is not known, and facts about globals across calls
to functions with side effects no longer prove unless one of the sound paths
below applies.

### Fixed

- `X not in S`, where `S` is a subtype with a `Static_Predicate`,
  `Dynamic_Predicate` or `Predicate`, is no longer treated as "outside the
  range of `S`" (`FP-086`). A value inside the range but excluded by the
  predicate was assumed impossible.
- A subtype or array bound that reads a variable keeps its elaboration-time
  meaning (`FP-087`). Previously the bound was re-evaluated with the
  variable's current value, so assigning the variable later widened the
  subtype.
- Index and range checks are decided only against bounds that a declaration
  fixes (`FP-088`). Previously an array with no statically known bounds --
  a `String` parameter, an `array (1 .. N)`, even an object declared
  `String (1 .. 10)` -- was checked against its index subtype, a target
  range with one unknown bound was proved from the other bound alone, and
  `X'First` of an unconstrained array was taken to be its index subtype's
  first value.
- Two `Character` values are no longer provably equal (`FP-089`).
- A variable changed on some iterations of a loop is no longer confined to
  its pre-loop value after the loop (`FP-090`). The solver path kept the
  bounds of the first visit of a merge point.
- Modular arithmetic wraps (`FP-091`). `N + 1` for a `mod 256` value was
  taken to be nonzero; it is zero for `N = 255`.
- No fact is kept about an object that can change without being named:
  one written or read through a renaming or an address overlay, or one that
  is volatile, atomic, imported, exported or aliased (`FP-092`).
- A function called inside an expression is no longer assumed to change
  nothing (`FP-093`). Unless it is known to be free of side effects, what
  it may write is forgotten before the expression is evaluated.
- Controlled types and record defaults that call functions are accounted
  for (`FP-094`): a subprogram that declares or assigns such an object
  keeps no fact about objects declared outside it.

- An expanded name (`Pkg.Obj`, `Subp.Local`) is the object it denotes
  (`FP-097`). A write through one no longer leaves the fact held under the
  direct name in place.
- A loop over an empty range, or any other path the interval analysis
  finds infeasible, no longer makes every later obligation provable
  (`FP-098`).
- Under `--verify`, rule findings are reported only from converged states
  (`FP-095`). A division after a loop was reported as a division by a known
  zero, and `while` conditions as constant, from the values before the
  loop.
- Calls to a subprogram completed by a null procedure or an expression
  function are checked against the precondition on its declaration
  (`FP-096`); they had no precondition obligation.

### Added

- `--verify` proves an index check when the index is the parameter of a
  `for` loop over the indexed object's own range (`for I in A'Range`,
  `A'Range (N)` or `A'First .. A'Last`), whatever the object's bounds are
  (new `index-own-range` proof path).
- `--verify` proves an index into an array whose bounds no declaration
  fixes when the index is shown to lie between the object's own `'First`
  and `'Last` (new `index-symbolic-bounds` proof path): from a precondition
  such as `I in A'Range`, a guard, `A'Length`, or a loop over
  `A'First .. A'Last - 1`. `A'First`, `A'Last` and `A'Length` of such an
  object are now terms the provers can reason about.
- Package-qualified globals are tracked like directly visible ones.
- A precondition is evaluated in the caller's state, so one that reads a
  global can be decided.
- The symbolic state survives an assignment whose value cannot be
  translated (only the destination becomes unknown), a write to an array
  element, and calls to predefined attribute functions such as `T'Pos`;
  each of these used to discard everything known.
- Membership tests narrow intervals: `Pre => X in 1 .. 5`, `if X in Small`,
  and `if X not in 0 .. 3` now give `X` a range on the abstract path, as
  comparisons already did. Obligations that needed the external provers for
  this now prove without them.
- Range and index targets resolve `T'First`/`T'Last`, named numbers,
  constants declared outside the subprogram, modular types, 64-bit integer
  types, and index constraints on objects and array subtypes. `for` loop
  parameters over a subtype, `T'Range` or `A'Range` of an object with
  declared bounds get that range.

- A function's `SPARK_Mode` is also taken from a `pragma SPARK_Mode` written
  before its compilation unit, and from the configuration pragmas of the
  project it belongs to (`Compiler'Local_Configuration_Pragmas`,
  `Builder'Global_Configuration_Pragmas`). A function in SPARK, or in a
  unit declared `Pure`, is treated as free of side effects, so a call to it
  no longer discards what is known about other objects.

### Changed

- An index outside an object's own static index constraint (`Buffer (20)`
  for `Buffer : String (1 .. 10)`) is now a `Definite_Error`, and reported
  by `Known_Index_Check_Failure`; it was previously `Proved_Safe`.
- The proof-path evidence has 62 routes over 20 producers.
- SPARKNaCl and libkeccak were re-run with this release: zero possible
  unsoundness and zero false positives against the GNATprove oracle. The
  `benchmarks/<corpus>/RESULTS_2026-09-30.md` files still describe 1.6.0;
  the other nine corpora have not been re-run yet.

## [1.6.0] - 2026-09-30

Minor release. `--verify` now applies contracts written on a separate spec
to the subprogram body, and proves discriminant checks; the proof-path
evidence gains a second tranche covering the remaining discriminant, join,
exception, composite/access and spec-contract sub-boundaries (48 routes
over 18 producers in `quality/proof_path_evidence.tsv`). Obligations of a
subprogram whose analysis fails partway are now `Unsupported` rather than
`Unreachable`.

### Added

- `--verify` proves a discriminant check when the prefix object's own
  static discriminant constraint selects the variant that declares the
  component (new `discriminant-static-constraint` proof path). Without
  `--verify` such accesses stay `Unproved`.
- Loop-invariant preservation and loop-variant obligations that exceed the
  branch budget (a third independent conditional on one path) now carry
  `branch-budget-exceeded` provenance naming the blocking condition.

### Fixed

- `Known_Discriminant_Check_Failure` no longer reports a valid component
  access when the discriminant constraint is a named constant or a variant
  choice is a subtype name (`FP-083`).
- `--verify` no longer reports obligations as `Unreachable` when a
  subprogram's fixed-point run fails partway; they are `Unsupported`
  (`FP-084`).
- `--verify` now applies preconditions and postconditions written on a
  separate spec to the subprogram body. Previously they never narrowed the
  body's parameters, leaving provable checks in every package-level
  subprogram `Unproved` (`FP-085`). A contract is carried across only when
  the spec conforms to the body parameter by parameter, so a same-name
  overload's contract is never applied.

### Changed

- Re-ran all eleven benchmark corpora from fresh checkouts, including both
  lanes of the seven GNATprove-oracle SPARK corpora; results are in each
  `benchmarks/<corpus>/RESULTS_2026-09-30.md`. Zero possible unsoundness
  and zero false positives on every corpus with an oracle.

## [1.5.3] - 2026-09-24

Patch release. Sixteen precision and robustness fixes, found by extending
the GNATcheck oracle comparison to GNAT's own compiler warnings and style
checks (`benchmarks/README.md`, "Compiler-warning and style-check pairs")
and by correcting two comparison-harness defects that had hidden results.

### Fixed

- `Unused_With_Clause` no longer flags withs of package renamings (such as
  `GNAT.OS_Lib`) or generic instances used through a `use` clause, nor ones
  whose use-visible names Libadalang cannot resolve (`FP-069`); and enabling
  it no longer abandons a whole file on a Libadalang property error, which
  silently dropped every other check's findings there (`FP-078`).
- `Dead_Store` no longer treats a write through an access-typed local as a
  write to the local (`FP-070`), flags calls whose callee applies
  `pragma Inspection_Point` (key-wiping `Sanitize` calls, `FP-072`), or
  ignores a later read through a variable index after a slice write
  (`FP-073`).
- `Dead_Store` and `Overwritten_Assignment` now see reads by nested
  subprograms (`FP-071`) and skip deliberately named sinks such as `Dummy`,
  `Ignored` or `Unused`, following GNAT's convention (`FP-075`).
  `Overwritten_Assignment` no longer counts an unreachable later write, or
  one past an early `return` through which an `out` value reaches the
  caller, as an overwrite (`FP-067`).
- `Unreachable_Code` is no longer reported when disabled but
  `Overwritten_Assignment` or `Repeated_Statement` is enabled (`FP-068`).
- `Missing_Overriding_Indicator` no longer flags a body whose separate
  declaration already carries `overriding` (`FP-074`).
- `Wrong_Parameter_Mode` now sees writes through a `for ... of` loop element
  (`FP-076`) and no longer advises changing modes fixed by overriding or by
  an `'Access` or generic-actual binding (`FP-077`).
- `Identical_Case_Alternative` now also checks case expressions, not only
  case statements, matching `Identical_Branches`' coverage of if-expressions
  (`FP-079`).
- A Libadalang resolution failure in a helper's declarations escaped its
  exception handler: with `Non_Short_Circuit_Condition` enabled, an
  unresolvable operand type in an `if` condition dropped every other check
  on that `if` statement (`Identical_Branches`, `Duplicate_Condition`,
  `Empty_If_Body`, `Unreachable_Branch`). Twelve helpers with the same
  shape are fixed (`FP-080`).
- Any call with a positional argument made `Non_Short_Circuit_Condition`
  and `No_Dispatching_Call` raise internally, silently skipping every later
  check on the enclosing `if`/`elsif`/`while` statement or call
  (`FP-081`).
- A resolution failure in one check no longer skips the other checks on
  the same node: each check now has its own handler. With all checks
  enabled this recovers 114 findings on gnatcoll-core alone (`FP-082`).

### Changed

- The GNATcheck oracle comparison pairs fourteen more checks, twelve of them
  through GNATcheck's `Warnings` and `Style_Checks` rules; 56 checks now
  carry an independent-tool cross-check (was 44).
  `tests/run_tool_function_evidence.sh` now also requires every claimed
  GNATcheck pairing to be in `benchmarks/gnatcheck_rule_map.tsv`.
- GNATcheck oracle comparison harness: the Ada_Drivers_Library runner split
  each extra GNATcheck pass at spaces (an indented `IFS` value), so none of
  the fourteen new pairs was ever checked there; GNATcheck's
  `Duplicate_Branches` now runs with `min_stmt=1,min_size=1` (its defaults
  hid every pair on all ten corpora), and it and `Same_Tests` are matched on
  the line they name as the duplicate, the one AdaLang reports.

## [1.5.2] - 2026-09-22

Patch release. `Null_Statement` flagged every `null;` statement
unconditionally, including the sole-statement idiom Ada requires for a
deliberate no-op (`exception when X => null;`, a single-choice
`when K => null;` case branch, an empty `if`/loop body) and a labeled null
used as a `goto` target -- both cases GNATcheck's own
`Redundant_Null_Statements` rule explicitly exempts. Found while triaging
the AWS corpus's GNATcheck oracle comparison (`benchmarks/README.md`):
despite being a "Direct" rule pair, the two tools' findings never landed on
the same line, and every sampled AdaLang-only finding was exactly that
idiom -- already judged, on its own more specific terms, by
`Empty_Exception_Handler`, `Null_Case_Alternative`, and `Empty_Then_Body`.

### Fixed

- `Null_Statement` no longer flags a `null;` that is the sole statement in
  its enclosing sequence, or immediately preceded by a label; a `null;`
  sitting alongside other, real statements is still flagged as genuine
  redundant padding (`FP-066`).

## [1.5.1] - 2026-09-21

Patch release. The 1.5.0 release as indexed by Alire (commit `f3fb5da`)
still had `Analyzer_Version` hardcoded to `1.0.0`, so `--version`, the JSON
`toolVersion` and the SARIF `tool.driver.version` under-reported the
release. 1.5.1 is the first indexed release that reports its own version.

### Fixed

- `Analyzer_Version` now matches `alire.toml`, so `--version`, JSON
  `toolVersion` and SARIF `tool.driver.version` report the real release.

### Added

- SARIF results carry `properties.severity` and `properties.quality`,
  mirroring the JSON report, so consumers can tell a Blocker from a High
  finding (SARIF `level` only has error/warning/note).

## [1.5.0] - 2026-09-10

Tool-qualification-support evidence. Three new machine-checked bodies of
validation evidence -- a per-check tool-function and tool-error register, a
corpus exercise-coverage table, and operator/type/join/exception
sub-boundary routes for the `--verify` proof engine -- plus a stale-path fix
in the two profile evidence gates. No analyzer behaviour change; the bump is
for the new user-facing evidence artifacts and documentation.

### Added

- Tool-function validation evidence: `quality/tool_function_evidence.tsv`
  maps every one of the 127 `Rule_Kind` checks to its documented function,
  an assurance `class` (which fixes the effect direction of a tool
  malfunction), an `independent oracle` value (`gnatcheck-comparison`,
  `gnatprove-differential`, or `none`), and a positive + negative
  validation invocation. `tests/run_tool_function_evidence.sh` keeps the
  manifest exactly aligned with the catalogue, re-runs every invocation one
  check at a time, and regenerates the new
  [tool-function validation evidence](https://mmartign.github.io/AdaLang_Analyzer/tool-qualification-support.html)
  page from it. This is validation evidence and the per-class tool-error
  analysis a project would build a qualification argument on; it is not a
  qualification argument and supports no EN 50128 §6.7 tool-classification
  claim.
- `--verify` proof-path sub-boundary evidence: 14 new routes in
  `quality/proof_path_evidence.tsv` (23 -> 37), each with new
  `tests/verification_pp_*.adb` fixtures verified against real analyzer
  output, covering the scalar VC sub-boundaries within the existing
  producers -- individual operators (`*`, unary/Boolean connectives,
  relational comparison, non-zero `/`/`mod`/`rem`, unsupported `**`), scalar
  types (bounded subtype, enumeration, modular, `'Length` fallback with its
  unsupported `'First`/`'Last` edge), branch and case joins (fact survival
  vs. dropped conflicting binding), and the exception-handler edge (before a
  `raise`, and on the non-exceptional path through a handler-bearing block).
  No analyzer source change: every route cites a producer tag that already
  exists in `flow_interp.adb`. Partly discharges assurance-model
  remaining-work item 1.
- Corpus exercise coverage: `quality/corpus_exercise_coverage.tsv`, derived
  from `benchmark-results/*/adalang-*.json` by
  `tests/gen_corpus_exercise_coverage.py`, records per check whether a
  benchmark preset run enabled it over one of the 10 external corpora, how
  many corpora did, and how many findings across how many files it produced
  there. 99 of 127 checks are exercised against independently-authored code
  this way; 78 produce at least one finding. `benchmark-results/` is
  gitignored, so the file is a release snapshot refreshed with the benchmark
  run; `run_corpus_exercise_coverage.sh` always checks its structure and
  regenerates-and-diffs it only when the benchmark JSON is present locally.
  The summary feeds the tool-function evidence page.

### Fixed

- `tests/run_automotive_evidence.sh` and `tests/run_do178c_evidence.sh`
  pointed at the compliance-matrix files at their old repository-root paths;
  updated to `docs/src/automotive-compliance-matrix.md` and
  `docs/src/do178c-compliance-matrix.md` after the mdBook move, so
  `tests/run_all.sh` passes those gates again.

## [1.4.1] - 2026-09-06

### Fixed

- `--verify` no longer proves an index into an array *slice*
  (`A (Lo .. Hi) (I)`) safe against the array type's declared index
  subtype. A slice's own bounds `Lo .. Hi` may be empty (e.g. `A (1 .. 0)`)
  or narrower than the type's, so the index check is now reported
  conservatively as `unproved` rather than `proved-safe` (`FP-064`, a
  possible unsoundness).
- `--verify` no longer reports `pragma Assert (False)` (and other
  statically-false assertions) as a `Known_Assertion_Failure` definite
  error when the pragma sits inside a conditional whose guard could not be
  evaluated and is in fact unreachable. The definite-error verdict is now
  kept only where every enclosing branch guard is provably taken
  (`FP-065`); straight-line assertions are unaffected.

Both were found by a new benchmark corpus, `benchmarks/spark_testsuite/`,
comparing `--verify` against GNATprove over 124 curated units of the
AdaCore SPARK testsuite.

## [1.4.0] - 2026-09-04

### Added

- `--compliance-report=en50128`, a third verification-support standard
  alongside `do178c` and `iso26262`, reporting the CENELEC EN 50128:2011
  (rail signaling) angle on the existing `--automotive` preset. It rides
  the same `--automotive` flag `iso26262` already uses -- ISO 26262 and
  EN 50128 converge on the same restricted, strongly-typed Ada subset and
  the same static-analysis techniques, so no new preset flag or rule
  selection was needed, only a new, EN-50128-flavored ten-category
  objective labeling (`EN_50128_Objectives` in
  `adalang_analyzer-compliance_mapping.adb`) reusing the identical
  `Rule_List` partitions already declared for `iso26262`. See the new
  [EN 50128 Rail Compliance Matrix](https://mmartign.github.io/AdaLang_Analyzer/en50128-rail-compliance-matrix.html)
  for the non-normative rule-by-rule mapping, mirroring the
  Automotive Ada compliance matrix's structure. Like the other two
  standards, this report cites no EN 50128 clause, table, or technique
  number and is verification-support evidence, not a compliance
  determination.
- `Double_Free`, a new `--recommended` check and `Use_After_Free`'s direct
  sibling: reports a local access object passed to
  `Ada.Unchecked_Deallocation` a second time, with no intervening
  assignment. Reuses `Analyze_Deallocation_Call`'s existing
  `Data_Flow.First_Access` walk rather than a second traversal; since
  `Ada.Unchecked_Deallocation`'s formal is `in out`, a second free is
  found as a read of the object, the same `Access_Kind` an ordinary
  use-after-free produces, so the two are told apart by whether the read
  site is itself a recognized deallocation call.

## [1.3.0] - 2026-08-29

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
  checks. See the [Checks catalogue](https://mmartign.github.io/AdaLang_Analyzer/checks.html)
  for the full list.
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
