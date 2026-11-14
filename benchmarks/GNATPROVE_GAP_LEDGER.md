# What separates `--verify` from GNATprove: a ledger

Recorded 2026-11-14 with AdaLang Analyzer 1.15.2, against the GNATprove
output saved by the 2026-10-02 runs of the five fully proved corpora
(`sparknacl`, `saatana`, `libkeccak`, `coap_spark`, `tokeneer`). The ledger
was started on 2026-10-05. What each release has added since is in
`CHANGELOG.md`, and earlier states of the ledger are in the Git history.

The per-corpus comparisons (`<corpus>/RESULTS_2026-11-14.md`) answer one
question: where both tools have exactly one obligation of a kind on a line,
do they ever disagree? This ledger asks the other one: of everything
GNATprove proves, how much does AdaLang prove, and what happens to the rest?
Every check GNATprove reports is a row; none is left out for being hard to
pair.

## Where it stands

Of the 15,043 checks GNATprove proves on the five corpora, AdaLang proves
11,789. It has an obligation that it does not decide for 2,506 more (2,467
unproved, 39 unsupported), finds 1 in code that is never reached, and
has no obligation for 747. In the other
direction it proves 9 of the 22 checks GNATprove leaves unproved, each
of which holds, GNATprove's provers reaching their time or step limit on
it. Two are the preservation of two invariants of one loop in
`sparknacl-sign.adb`: `for all K in Index_64 range I .. 63 => XL (K) = 0`
(line 604) -- the loop's body writes no element above `I` and sets `XL
(I)` to 0 -- and `for all K in Index_64 range I - 11 .. I32'Min (50, I -
1) => XL (K) in PRL` (line 589) -- the loop goes down from 62, an
iteration writes `XL (I - 32 .. I - 12)` and `XL (I)` only, and the inner
loop's invariant at line 502 gives the range at its exit. Seven are the
precondition `Fits_Into (Val, Natural (Field_Size (Ctx, Fld)))` of
`Set_Scalar` in the setters of a 16-bit field that RecordFlux generates
for CoAP-SPARK (`Set_Message_ID`, `Set_Length` three times,
`Set_Option_Delta_Extended16`, `Set_Option_Length_Extended16`,
`Set_Options_And_Payload_Length`): `Val` is of a type `range 0 .. 2**16 -
1`, the field is 16 bits wide, and `Fits_Into (Val, 16)` is `Val < 2**16`.
It reports no definite error on a check GNATprove proves.

By kind, summed over the per-corpus tables below, AdaLang proves:

- 2,493 of GNATprove's 2,938 preconditions, those of the subprogram
  an instance gives a generic formal subprogram among them, which AdaLang
  raises since 1.12.2, those of an operator a generic unit hides behind an
  abstract function and of a renaming, since 1.12.3, and those that read a
  component of an element of an array of records (RecordFlux's
  `Ctx.Cursors (F)`), since 1.13.1, and, since 1.15.2, those the
  precondition of a generic subprogram gives in its body, those that need
  the predicate of a component of a parameter (the message contexts of a
  RecordFlux session) and those that read an expression function through
  a renaming, such as RecordFlux's `Fits_Into`;
- 1,595 of its 2,372 range checks, those on an element of an
  array read at an index whose value is not known among them, which
  AdaLang reads in the contents of the array's value since 1.13.0, and
  those on the value a function returns and on the bounds of the range
  constraint of a `for` loop or a quantified expression, which it raises
  since 1.15.0;
- 357 of its 522 index checks, those at each bound of a slice
  that is the target of an assignment among them, which AdaLang raises
  since 1.11.2;
- 1,670 of its 1,703 initializations of an object, in
  GNATprove's terms: since 1.12.0 an object a subprogram of SPARK code reads
  from outside is initialized on entry and checked at each call, a global
  of mode `Output` is given a value by the calls that list it so, and
  records and whole arrays are followed part by part;
- 102 of its 136 initialization checks, the reads of an object
  with relaxed initialization, which AdaLang follows as a whole since
  1.13.2 and, for an array, element by element since 1.13.3: an element
  or a slice has a value where it is given one, where an `out` parameter
  gives it one, and where a condition known to hold says so; what
  GNATprove knows of the components of a record, and of elements where
  two ways meet at the head of a loop, it does not yet follow;
- 1,056 of its 1,169 termination checks, those in SPARKlib's generic
  units among them: since 1.15.0 AdaLang verifies the generic units of
  imported projects that a corpus instantiates, as GNATprove does, and
  decides a call to a generic formal subprogram by the subprograms the
  instantiations give it;
- 668 of its 696 data-dependency (`Global`) checks, those in
  SPARKlib's generic units among them since 1.15.0, and 332 of its
  357 flow-dependency checks, every `Depends` aspect; those left
  are GNATprove's checks of `Initializes` aspects, for which AdaLang has
  no obligation;
- 183 of its 421 predicate checks, which AdaLang raises since
  1.10.0 at an assignment, a call, a declaration and a return; since
  1.13.4 it decides that of the contexts RecordFlux generates, which reads
  the bounds of the buffer an access component designates, at the writes
  of their parts. The predicates it leaves unproved read what it does not
  express (the object an access value designates, arrays of arrays,
  components of arrays of records that are not scalar), are those of a
  whole record given an aggregate, or need facts that do not survive a
  loop;
- 321 of its 336 pointer dereference checks, which AdaLang raises
  since 1.11.0 in SPARK code; of the 15 it leaves, 4 are unproved, in
  CoAP-SPARK's own code and in what RecordFlux generates, 9 in the predicate
  of a subtype or other code it does not analyze for its own checks, and 2
  in subprograms outside the verified subset;
- 129 of its 135 discriminant checks, all in CoAP-SPARK, which
  AdaLang raises since 1.13.5 in SPARK code: the selection of a component
  of a variant part, and the assignment to an object with discriminants,
  whose discriminants may not change if it is constrained. Of the
  6 left, 3 are in subprograms outside the verified subset, 2
  unproved, the guard being in a precondition AdaLang does not translate,
  and 1 at a component of an aggregate that a discriminant constrains,
  where AdaLang raises no check;
- 183 of its 211 resource leak checks, all in CoAP-SPARK, which
  AdaLang raises since 1.14.0 in SPARK code: at an assignment to an object
  with owning parts, at an `out` actual, and wherever the scope of an
  owning local ends, each owning part being null or moved. Of the
  28 left, 8 are in a subprogram outside the verified subset, 19
  unproved (what is known is dropped by a call of a generic instance
  declared in the subprogram, or does not survive a loop that writes the
  access value without an invariant saying it is null), and 1 at an
  `out` actual of a call of a generic formal subprogram, where AdaLang
  raises no check.

What is left:

- **Unproved (2,467).** AdaLang has the obligation and does not decide it.
  The per-corpus tables below give the reason it reports for each.
- **Unsupported (39).** The obligation is in a subprogram that
  `--verify` leaves outside the verified subset, almost all for a
  dispatching call; 37 of them are in `coap_spark`.
- **No obligation (747).** Checks AdaLang has no kind for
  (non-aliasing, contract cases, refined postconditions, unchecked
  conversions, default initial conditions, type invariants); the
  discriminant check of a component of an aggregate; predicate checks
  at the default value of a type, at an allocator and at a component of
  an aggregate, where it raises none yet; and range, index and
  precondition checks at places it does not yet look. "Where the missing
  obligations are", below, says where.

## How to read it

- A **check** is a GNATprove message about one thing it verified at one
  place. A check of a generic unit, which GNATprove repeats for every
  instance, counts once and is proved when every instance is.
- AdaLang's side of a check is the obligation of the corresponding kind on
  the same line, the one at the same column if there is one. Initialization
  is the exception: GNATprove reports "initialization of X proved" once per
  object, at its declaration, where AdaLang checks every read of X and, for
  an `out` parameter, its state at the subprogram's exit. The ledger takes
  all of AdaLang's obligations about that declaration together, and the
  object is as good as the worst of them.
  - **proved-safe**, **unproved**, **unsupported**: AdaLang has that
    obligation, with that verdict. **unreachable**: AdaLang has it and finds
    it in code that is never executed.
  - **no obligation here**: AdaLang knows the kind of check but raises none
    at this place. The tables say what it has instead: the same kind a few
    lines away (the two tools place the check differently), another kind on
    the line, or nothing.
  - **no such obligation kind**: AdaLang has no obligation of this kind at
    all (predicate and pointer-dereference checks, memory leaks, ...).
  - **file without any obligation**: AdaLang raises nothing in the file,
    usually a specification or a library unit outside the analyzed project.
- The corpora are called fully proved because their authors proved them;
  with the provers and limits of this benchmark's toolchain GNATprove
  leaves 22 checks unproved. AdaLang proves none of those.

Reproduce with the results of the `run.sh` lanes in `benchmark-results/`:

```sh
python3 benchmarks/gnatprove_gap_ledger.py \
  --corpus sparknacl=benchmark-results/sparknacl \
  --corpus saatana=benchmark-results/saatana \
  --corpus libkeccak=benchmark-results/libkeccak \
  --corpus coap_spark=benchmark-results/coap_spark \
  --corpus tokeneer=benchmark-results/tokeneer
```

## All corpora

GNATprove proves 15043 checks on these 5 corpora. What AdaLang does with each of them:

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 11789 | 78.4% |
| unproved | 2467 | 16.4% |
| unsupported | 39 | 0.3% |
| unreachable | 1 | 0.0% |
| no obligation here | 597 | 4.0% |
| no such obligation kind | 145 | 1.0% |
| file without any obligation | 5 | 0.0% |

| Corpus | Proved by GNATprove | AdaLang proved | Unproved | Unsupported | Unreachable | No obligation here | No such kind | File without obligations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2446 | 1944 | 427 | 0 | 0 | 61 | 14 | 0 |
| saatana | 367 | 256 | 102 | 0 | 0 | 9 | 0 | 0 |
| libkeccak | 3321 | 2491 | 679 | 2 | 0 | 82 | 67 | 0 |
| coap_spark | 6795 | 5412 | 1004 | 37 | 1 | 301 | 36 | 4 |
| tokeneer | 2114 | 1686 | 255 | 0 | 0 | 144 | 28 | 1 |

Disagreements: 9 checks AdaLang proved that GNATprove did not, 0 definite errors on checks GNATprove proved.

## With GNATprove's verdicts read in

Since 1.8.3 the analyzer does this pairing itself. Given the log of a
GNATprove run on the same sources (`--gnatprove-log`), `--verify` reports
what GNATprove said of each check beside the AdaLang obligation that stands
for it, and lists the checks that have none. Run on the five corpora with
the logs this ledger is made from, it accounts for every check GNATprove
proved, and gives the figures of the table above:

| Corpus | Proved by GNATprove | Proved by AdaLang too | GNATprove's verdict alone, on an AdaLang obligation | GNATprove's verdict alone, no AdaLang obligation | A definite error for AdaLang |
| --- | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2,446 | 1,944 | 427 | 75 | 0 |
| saatana | 367 | 256 | 102 | 9 | 0 |
| libkeccak | 3,321 | 2,491 | 681 | 149 | 0 |
| coap_spark | 6,795 | 5,412 | 1,042 | 341 | 0 |
| tokeneer | 2,114 | 1,686 | 255 | 173 | 0 |
| All five | 15,043 | 11,789 | 2,507 | 747 | 0 |

The second column is what AdaLang proves; it is 11,789 with the logs and
without them. The third and fourth are GNATprove's work, reported as
GNATprove's: 2,507 checks on an obligation AdaLang has and did not prove
(the 2,467 unproved, the 39 unsupported and the 1 unreachable above) and
747 for which it
has no obligation. Nothing is left over, which is all that "the gap is
zero" means here: with GNATprove's log beside it, an AdaLang report says
of each of the 15,043 checks who proved it. It does not mean AdaLang proves
them. The logs also hold 13 checks justified in Tokeneer and 22 GNATprove
did not prove (8 in SPARKNaCl, 14 in CoAP-SPARK), of which AdaLang proves
9, the checks said above.

That the analyzer and `gnatprove_gap_ledger.py` pair alike is tested on a
small case by `tests/run_gnatprove_import.sh`; that they give the same
totals on these corpora is what the table shows.

## Where the missing obligations are

745 checks GNATprove proved have no AdaLang obligation at their place. By the construct they are in:

| Construct | Checks |
| --- | ---: |
| argument | 212 |
| object-declaration | 80 |
| in aspect contract_cases | 61 |
| assignment-value | 39 |
| aggregate | 36 |
| component-declaration | 33 |
| in aspect refined_post | 30 |
| subprogram-declaration | 28 |
| in aspect initializes | 25 |
| slice | 24 |
| call-statement | 23 |
| expression-function | 21 |
| in aspect post | 19 |
| instantiation | 15 |
| conditional-expression | 14 |
| subtype-indication | 11 |
| in aspect pre | 11 |
| in aspect dynamic_predicate | 11 |
| qualified-expression | 10 |
| type-declaration | 9 |
| return | 8 |
| subtype-declaration | 4 |
| loop-range | 4 |
| in aspect annotate | 4 |
| condition | 3 |

By GNATprove check, with the constructs it is most often in:

| GNATprove check | Checks | Where |
| --- | ---: | --- |
| range check | 349 | argument 130, object-declaration 73, assignment-value 32, component-declaration 20, expression-function 13 |
| precondition | 92 | subprogram-declaration 21, call-statement 19, in aspect contract_cases 14, argument 11, conditional-expression 8 |
| predicate check | 49 | slice 13, argument 10, type-declaration 8, component-declaration 7, aggregate 6 |
| non-aliasing | 44 | argument 38, slice 6 |
| overflow check | 38 | argument 16, assignment-value 6, in aspect post 5, in aspect pre 3, expression-function 3 |
| contract case | 36 | in aspect contract_cases 36 |
| flow dependencies | 25 | in aspect initializes 25 |
| refined post | 19 | in aspect refined_post 19 |
| index check | 18 | aggregate 15, subtype-indication 2, argument 1 |
| unchecked conversion | 15 | instantiation 15 |
| default initial condition | 12 | component-declaration 6, object-declaration 6 |
| pointer dereference check | 9 | in aspect dynamic_predicate 9 |
| invariant check | 9 | call-statement 4, subprogram-declaration 4, type-declaration 1 |
| initialization check | 5 | argument 5 |
| initialization of | 5 | in aspect abstract_state 3, return 1, subprogram-declaration 1 |
| contract or exit cases | 4 | in aspect contract_cases 4 |
| Container_Aggregates annotation | 4 | in aspect annotate 4 |
| Always_Terminates | 2 | subprogram-declaration 2 |
| data dependencies | 2 | in aspect global 2 |
| postcondition | 2 | in aspect post 2 |
| accessibility check | 2 | expression-function 2 |
| resource or memory leak | 1 | argument 1 |
| discriminant check | 1 | aggregate 1 |
| length check | 1 | conditional-expression 1 |
| assertion | 1 | in pragma postcondition 1 |

Produced by `benchmarks/gnatprove_gap_contexts.py` from the ledger's rows.
It has 745 of the 747 checks without an obligation: the script leaves
out a check whose source file it does not find under the corpus roots it is
given. The construct is read from the syntax alone, from the inside out. What is
left under a `Global` aspect is the initialization of state abstractions
and of globals in sources outside the analyzed project; under a subprogram
declaration, the termination and contract checks of the SPARK library
units, which the lanes do not analyze.

## sparknacl

GNATprove reports 2454 checks (2463 messages, a check of a generic unit being repeated for each instance): 2446 proved, 0 justified by the corpus, 8 not proved. AdaLang raises 10195 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1944 | 79.5% |
| unproved | 427 | 17.5% |
| no obligation here | 61 | 2.5% |
| no such obligation kind | 14 | 0.6% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 585 | 466 | 79 | 0 | 40 | 0 |
| initialization of | 356 | 346 | 10 | 0 | 0 | 0 |
| data dependencies | 198 | 198 | 0 | 0 | 0 | 0 |
| assertion | 187 | 101 | 86 | 0 | 0 | 0 |
| overflow check | 155 | 90 | 49 | 0 | 16 | 0 |
| division check | 153 | 153 | 0 | 0 | 0 | 0 |
| index check | 142 | 130 | 12 | 0 | 0 | 0 |
| precondition | 123 | 101 | 22 | 0 | 0 | 0 |
| initialization check | 105 | 90 | 13 | 0 | 2 | 0 |
| Always_Terminates | 103 | 79 | 24 | 0 | 0 | 0 |
| loop invariant initialization | 81 | 44 | 37 | 0 | 0 | 0 |
| loop invariant preservation | 79 | 38 | 41 | 0 | 0 | 0 |
| length check | 67 | 60 | 7 | 0 | 0 | 0 |
| predicate check | 58 | 40 | 15 | 0 | 3 | 0 |
| postcondition | 29 | 7 | 22 | 0 | 0 | 0 |
| loop variant | 10 | 0 | 10 | 0 | 0 | 0 |
| unchecked conversion | 6 | 0 | 0 | 0 | 6 | 0 |
| contract case | 6 | 0 | 0 | 0 | 6 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |
| flow dependencies | 1 | 1 | 0 | 0 | 0 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| same kind within 3 lines | 35 |
| another kind on this line | 17 |
| fewer obligations of this kind on the line | 5 |
| nothing on this line | 4 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the invariant is not at the loop-head cut point | 71 |
| unproved | the current range domain does not certify the result | 46 |
| unproved | the expression conflicts with its symbolic scalar sort | 43 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 40 |
| unproved | the current non-relational range domain is inconclusive | 35 |
| unproved | slice bound and array bound ranges remain inconclusive | 21 |
| unproved | current contract transfer does not certify safety | 14 |
| unproved | the object has relaxed initialization and is not known to have a value in every part | 13 |
| unproved | the required bounds are not statically known | 13 |
| unproved | this operator is outside the scalar VC subset | 12 |
| unproved | the callee is not a plain expression function | 11 |
| unproved | this expression form is outside the scalar VC subset | 8 |

### Disagreements

- AdaLang proved, GNATprove did not: 2
  - `sparknacl-sign.adb:589:16` loop invariant
  - `sparknacl-sign.adb:604:55` loop invariant
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 81 | 15 | 66 | 0 |
| division-by-zero | 39 | 39 | 0 | 0 |
| index-check | 953 | 949 | 4 | 0 |
| initialization-check | 2596 | 2506 | 90 | 0 |
| integer-overflow | 1423 | 859 | 564 | 0 |
| postcondition | 1 | 0 | 1 | 0 |
| range-check | 1665 | 1553 | 112 | 0 |

## saatana

GNATprove reports 367 checks (376 messages, a check of a generic unit being repeated for each instance): 367 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 1512 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 256 | 69.8% |
| unproved | 102 | 27.8% |
| no obligation here | 9 | 2.5% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 103 | 69 | 27 | 0 | 7 | 0 |
| division check | 44 | 44 | 0 | 0 | 0 | 0 |
| overflow check | 31 | 15 | 16 | 0 | 0 | 0 |
| index check | 29 | 22 | 5 | 0 | 2 | 0 |
| precondition | 22 | 10 | 12 | 0 | 0 | 0 |
| length check | 20 | 11 | 9 | 0 | 0 | 0 |
| data dependencies | 20 | 20 | 0 | 0 | 0 | 0 |
| initialization of | 18 | 18 | 0 | 0 | 0 | 0 |
| flow dependencies | 14 | 14 | 0 | 0 | 0 | 0 |
| postcondition | 13 | 3 | 10 | 0 | 0 | 0 |
| assertion | 10 | 2 | 8 | 0 | 0 | 0 |
| Always_Terminates | 10 | 10 | 0 | 0 | 0 | 0 |
| loop invariant initialization | 9 | 4 | 5 | 0 | 0 | 0 |
| loop invariant preservation | 9 | 4 | 5 | 0 | 0 | 0 |
| initialization check | 6 | 5 | 1 | 0 | 0 | 0 |
| predicate check | 5 | 5 | 0 | 0 | 0 | 0 |
| loop variant | 4 | 0 | 4 | 0 | 0 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| same kind within 3 lines | 5 |
| another kind on this line | 2 |
| fewer obligations of this kind on the line | 2 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | current contract transfer does not certify safety | 12 |
| unproved | this expression form is outside the scalar VC subset | 12 |
| unproved | the current range domain does not certify the result | 12 |
| unproved | slice bound and array bound ranges remain inconclusive | 12 |
| unproved | the invariant is not at the loop-head cut point | 10 |
| unproved | the slice range is not written as two bounds | 9 |
| unproved | the current non-relational range domain is inconclusive | 9 |
| unproved | static evaluation is inconclusive | 6 |
| unproved | the required bounds are not statically known | 6 |
| unproved | the variant is not at the loop-head cut point | 4 |
| unproved | the blocking object is not known to be initialized | 2 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 2 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 9 | 0 | 9 | 0 |
| division-by-zero | 15 | 15 | 0 | 0 |
| index-check | 166 | 152 | 14 | 0 |
| initialization-check | 530 | 477 | 53 | 0 |
| integer-overflow | 214 | 147 | 67 | 0 |
| length-check | 2 | 0 | 2 | 0 |
| precondition | 26 | 0 | 26 | 0 |
| range-check | 153 | 105 | 48 | 0 |

## libkeccak

GNATprove reports 3321 checks (20673 messages, a check of a generic unit being repeated for each instance): 3321 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 12659 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 2491 | 75.0% |
| unproved | 679 | 20.4% |
| unsupported | 2 | 0.1% |
| no obligation here | 82 | 2.5% |
| no such obligation kind | 67 | 2.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 631 | 475 | 105 | 0 | 51 | 0 |
| overflow check | 569 | 423 | 141 | 0 | 5 | 0 |
| initialization of | 344 | 342 | 1 | 0 | 1 | 0 |
| division check | 306 | 295 | 11 | 0 | 0 | 0 |
| precondition | 273 | 208 | 55 | 1 | 9 | 0 |
| index check | 199 | 125 | 59 | 0 | 15 | 0 |
| data dependencies | 155 | 150 | 5 | 0 | 0 | 0 |
| predicate check | 154 | 81 | 72 | 0 | 1 | 0 |
| loop invariant initialization | 114 | 85 | 29 | 0 | 0 | 0 |
| loop invariant preservation | 114 | 43 | 71 | 0 | 0 | 0 |
| assertion | 90 | 31 | 59 | 0 | 0 | 0 |
| flow dependencies | 81 | 81 | 0 | 0 | 0 | 0 |
| postcondition | 79 | 38 | 40 | 1 | 0 | 0 |
| length check | 74 | 64 | 10 | 0 | 0 | 0 |
| Always_Terminates | 46 | 46 | 0 | 0 | 0 | 0 |
| non-aliasing | 37 | 0 | 0 | 0 | 37 | 0 |
| contract case | 28 | 0 | 0 | 0 | 28 | 0 |
| loop variant | 21 | 0 | 21 | 0 | 0 | 0 |
| initialization check | 4 | 4 | 0 | 0 | 0 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 44 |
| same kind within 3 lines | 21 |
| nothing on this line | 16 |
| fewer obligations of this kind on the line | 1 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the current range domain does not certify the result | 140 |
| unproved | the scalar VC portfolio did not certify the predicate | 72 |
| unproved | slice bound and array bound ranges remain inconclusive | 67 |
| unproved | the scalar loop preservation VC was not discharged | 66 |
| unproved | the required bounds are not statically known | 45 |
| unproved | the current non-relational range domain is inconclusive | 41 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 39 |
| unproved | current contract transfer does not certify safety | 37 |
| unproved | exit states do not imply the contract | 28 |
| unproved | the scalar loop initialization VC was not discharged | 24 |
| unproved | exactly one Increases or Decreases component is required | 19 |
| unproved | Ada division semantics require a provably nonzero divisor | 19 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 141 | 30 | 111 | 0 |
| data-dependencies | 36 | 15 | 21 | 0 |
| division-by-zero | 399 | 390 | 9 | 0 |
| flow-dependencies | 8 | 3 | 5 | 0 |
| index-check | 685 | 658 | 27 | 0 |
| initialization-check | 4680 | 4087 | 589 | 4 |
| integer-overflow | 1026 | 763 | 263 | 0 |
| length-check | 20 | 20 | 0 | 0 |
| loop-invariant-initialization | 17 | 6 | 11 | 0 |
| loop-invariant-preservation | 17 | 1 | 16 | 0 |
| loop-variant | 2 | 0 | 2 | 0 |
| postcondition | 3 | 0 | 3 | 0 |
| precondition | 19 | 4 | 15 | 0 |
| range-check | 1619 | 634 | 985 | 0 |
| termination | 4 | 3 | 1 | 0 |

## coap_spark

GNATprove reports 6809 checks (7423 messages, a check of a generic unit being repeated for each instance): 6795 proved, 0 justified by the corpus, 14 not proved. AdaLang raises 23191 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 5412 | 79.6% |
| unproved | 1004 | 14.8% |
| unsupported | 37 | 0.5% |
| unreachable | 1 | 0.0% |
| no obligation here | 301 | 4.4% |
| no such obligation kind | 36 | 0.5% |
| file without any obligation | 4 | 0.1% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| precondition | 2294 | 2006 | 202 | 12 | 74 | 0 |
| Always_Terminates | 869 | 788 | 79 | 0 | 2 | 0 |
| range check | 845 | 528 | 172 | 2 | 143 | 0 |
| postcondition | 379 | 183 | 194 | 0 | 2 | 0 |
| pointer dereference check | 336 | 321 | 4 | 2 | 9 | 0 |
| assertion | 299 | 248 | 47 | 3 | 0 | 0 |
| overflow check | 278 | 184 | 78 | 0 | 16 | 0 |
| initialization of | 277 | 263 | 6 | 7 | 1 | 0 |
| division check | 265 | 265 | 0 | 0 | 0 | 0 |
| resource or memory leak | 211 | 183 | 19 | 8 | 1 | 0 |
| predicate check | 181 | 57 | 79 | 0 | 45 | 0 |
| discriminant check | 135 | 129 | 2 | 3 | 1 | 0 |
| length check | 108 | 92 | 13 | 0 | 3 | 0 |
| index check | 96 | 37 | 58 | 0 | 1 | 0 |
| loop invariant preservation | 47 | 28 | 19 | 0 | 0 | 0 |
| loop invariant initialization | 47 | 36 | 11 | 0 | 0 | 0 |
| data dependencies | 42 | 35 | 5 | 0 | 2 | 0 |
| flow dependencies | 28 | 26 | 0 | 0 | 2 | 0 |
| initialization check | 21 | 3 | 15 | 0 | 3 | 0 |
| default initial condition | 12 | 0 | 0 | 0 | 12 | 0 |
| unchecked conversion | 9 | 0 | 0 | 0 | 9 | 0 |
| non-aliasing | 7 | 0 | 0 | 0 | 7 | 0 |
| Container_Aggregates annotation | 4 | 0 | 0 | 0 | 4 | 0 |
| contract case | 2 | 0 | 0 | 0 | 2 | 0 |
| accessibility check | 2 | 0 | 0 | 0 | 2 | 0 |
| loop variant | 1 | 0 | 1 | 0 | 0 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| same kind within 3 lines | 126 |
| nothing on this line | 97 |
| another kind on this line | 67 |
| fewer obligations of this kind on the line | 11 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | current contract transfer does not certify safety | 145 |
| unproved | slice bound and array bound ranges remain inconclusive | 107 |
| unproved | exit states do not imply the contract | 102 |
| unproved | the required bounds are not statically known | 99 |
| unproved | this expression form is outside the scalar VC subset | 64 |
| unproved | this attribute is outside the scalar VC subset | 46 |
| unproved | the scalar VC portfolio did not certify the predicate | 44 |
| unsupported | outside bounded verification subset | 37 |
| unproved | this operator is outside the scalar VC subset | 30 |
| unproved | the callee is not a plain expression function | 28 |
| unproved | calls Set_Scalar, not shown to return: calls Insert, not shown to return | 26 |
| unproved | the current range domain does not certify the result | 25 |

### Disagreements

- AdaLang proved, GNATprove did not: 7
  - `rflx-coap_server-options_and_payload_data.adb:323:7` precondition
  - `rflx-coap_client-options_and_payload_data.adb:323:7` precondition
  - `rflx-coap-option_type.adb:353:7` precondition
  - `rflx-coap-option_type.adb:363:7` precondition
  - `rflx-coap_server-definite_message.adb:323:7` precondition
  - `rflx-coap-coap_message.adb:408:7` precondition
  - `rflx-coap_server-application_response.adb:367:7` precondition
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 67 | 33 | 26 | 8 |
| data-dependencies | 17 | 3 | 14 | 0 |
| discriminant-check | 1 | 1 | 0 | 0 |
| division-by-zero | 15 | 15 | 0 | 0 |
| flow-dependencies | 3 | 3 | 0 | 0 |
| index-check | 882 | 837 | 25 | 20 |
| initialization-check | 12288 | 11625 | 290 | 373 |
| integer-overflow | 1119 | 559 | 475 | 85 |
| length-check | 19 | 11 | 2 | 6 |
| pointer-dereference | 77 | 76 | 1 | 0 |
| postcondition | 44 | 10 | 33 | 1 |
| precondition | 203 | 106 | 76 | 21 |
| predicate-check | 32 | 0 | 32 | 0 |
| range-check | 1327 | 509 | 706 | 111 |
| resource-leak | 9 | 6 | 3 | 0 |
| termination | 70 | 37 | 33 | 0 |

GNATprove messages not counted as checks: function contract feasibility proved (Z3: 1 VC in max 0.0 se (2); function contract feasibility proved (CVC5: 1 VC in max 0.0  (2).

## tokeneer

GNATprove reports 2127 checks (2205 messages, a check of a generic unit being repeated for each instance): 2114 proved, 13 justified by the corpus, 0 not proved. AdaLang raises 10044 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1686 | 79.8% |
| unproved | 255 | 12.1% |
| no obligation here | 144 | 6.8% |
| no such obligation kind | 28 | 1.3% |
| file without any obligation | 1 | 0.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initialization of | 708 | 701 | 4 | 0 | 3 | 0 |
| data dependencies | 281 | 265 | 16 | 0 | 0 | 0 |
| flow dependencies | 233 | 210 | 0 | 0 | 23 | 0 |
| precondition | 226 | 168 | 49 | 0 | 9 | 0 |
| range check | 208 | 57 | 43 | 0 | 108 | 0 |
| Always_Terminates | 141 | 133 | 8 | 0 | 0 | 0 |
| postcondition | 57 | 7 | 50 | 0 | 0 | 0 |
| index check | 56 | 43 | 13 | 0 | 0 | 0 |
| length check | 42 | 27 | 15 | 0 | 0 | 0 |
| division check | 41 | 41 | 0 | 0 | 0 | 0 |
| overflow check | 29 | 21 | 7 | 0 | 1 | 0 |
| predicate check | 23 | 0 | 23 | 0 | 0 | 0 |
| refined post | 19 | 0 | 0 | 0 | 19 | 0 |
| loop invariant initialization | 19 | 8 | 11 | 0 | 0 | 0 |
| loop invariant preservation | 19 | 5 | 14 | 0 | 0 | 0 |
| invariant check | 9 | 0 | 0 | 0 | 9 | 0 |
| assertion | 3 | 0 | 2 | 0 | 1 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 75 |
| nothing on this line | 39 |
| same kind within 3 lines | 30 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the blocking object is not known to be initialized | 49 |
| unproved | current contract transfer does not certify safety | 31 |
| unproved | slice bound and array bound ranges remain inconclusive | 27 |
| unproved | a record formal requires a plain object-reference actual | 22 |
| unproved | exit states do not imply the contract | 18 |
| unproved | State is used and is not listed | 16 |
| unproved | this expression form is outside the scalar VC subset | 15 |
| unproved | the current non-relational range domain is inconclusive | 14 |
| unproved | the required bounds are not statically known | 9 |
| unproved | the scalar loop preservation VC was not discharged | 9 |
| unproved | the two lengths are not known to be equal | 8 |
| unproved | the current range domain does not certify the result | 7 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 19 | 5 | 14 | 0 |
| division-by-zero | 10 | 10 | 0 | 0 |
| index-check | 270 | 194 | 66 | 10 |
| initialization-check | 5203 | 4457 | 706 | 40 |
| integer-overflow | 230 | 115 | 113 | 2 |
| length-check | 56 | 16 | 40 | 0 |
| postcondition | 4 | 2 | 2 | 0 |
| precondition | 96 | 18 | 78 | 0 |
| predicate-check | 10 | 0 | 10 | 0 |
| range-check | 1446 | 433 | 1004 | 9 |

