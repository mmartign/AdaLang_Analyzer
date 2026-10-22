# What separates `--verify` from GNATprove: a ledger

Recorded 2026-10-22 with AdaLang Analyzer 1.10.0, against the GNATprove
output saved by the 2026-10-02 runs of the five fully proved corpora
(`sparknacl`, `saatana`, `libkeccak`, `coap_spark`, `tokeneer`). The ledger
was started on 2026-10-05. What each release has added since is in
`CHANGELOG.md`, and earlier states of the ledger are in the Git history.

The per-corpus comparisons (`<corpus>/RESULTS_2026-10-22.md`) answer one
question: where both tools have exactly one obligation of a kind on a line,
do they ever disagree? This ledger asks the other one: of everything
GNATprove proves, how much does AdaLang prove, and what happens to the rest?
Every check GNATprove reports is a row; none is left out for being hard to
pair.

## Where it stands

Of the 15,043 checks GNATprove proves on the five corpora, AdaLang proves
7,939. It has an obligation that it does not decide for 4,994 more (4,968
unproved, 26 unsupported), finds 1 in code that is never reached, and
has no obligation for 2,109. In the other
direction it proves none of the 22 checks GNATprove leaves unproved, and
reports no definite error on a check GNATprove proves.

By kind, summed over the per-corpus tables below, AdaLang proves:

- 1,823 of GNATprove's 2,938 preconditions;
- 873 of its 2,372 range checks;
- 1,225 of its 1,703 initializations of an object;
- 990 of its 1,169 termination checks;
- 639 of its 696 data-dependency (`Global`) checks and 332 of its
  357 flow-dependency checks, every `Depends` aspect; those left
  are GNATprove's checks of `Initializes` aspects, for which AdaLang has
  no obligation;
- 67 of its 421 predicate checks, which AdaLang raises since
  1.10.0 at an assignment, a call, a declaration and a return; the
  predicates it leaves unproved read what it does not express (access
  values, quantified array elements) or need facts that do not survive a
  loop.

What is left:

- **Unproved (4,968).** AdaLang has the obligation and does not decide it.
  The per-corpus tables below give the reason it reports for each.
- **Unsupported (26).** The obligation is in a subprogram that
  `--verify` leaves outside the verified subset, almost all for a
  dispatching call; 24 of them are in `coap_spark`.
- **No obligation (2,109).** Pointer-dereference and discriminant
  checks and memory leaks, which AdaLang does not have; predicate checks
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
| proved-safe | 7939 | 52.8% |
| unproved | 4968 | 33.0% |
| unsupported | 26 | 0.2% |
| unreachable | 1 | 0.0% |
| no obligation here | 1214 | 8.1% |
| no such obligation kind | 686 | 4.6% |
| file without any obligation | 209 | 1.4% |

| Corpus | Proved by GNATprove | AdaLang proved | Unproved | Unsupported | No obligation here | No such kind | File without obligations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2446 | 1335 | 945 | 0 | 152 | 14 | 0 |
| saatana | 367 | 188 | 164 | 0 | 15 | 0 | 0 |
| libkeccak | 3321 | 1541 | 1346 | 2 | 365 | 67 | 0 |
| coap_spark | 6795 | 3493 | 2012 | 24 | 481 | 577 | 207 |
| tokeneer | 2114 | 1382 | 501 | 0 | 201 | 28 | 2 |

Disagreements: 0 checks AdaLang proved that GNATprove did not, 0 definite errors on checks GNATprove proved.

## With GNATprove's verdicts read in

Since 1.8.3 the analyzer does this pairing itself. Given the log of a
GNATprove run on the same sources (`--gnatprove-log`), `--verify` reports
what GNATprove said of each check beside the AdaLang obligation that stands
for it, and lists the checks that have none. Run on the five corpora with
the logs this ledger is made from, it accounts for every check GNATprove
proved, and gives the figures of the table above:

| Corpus | Proved by GNATprove | Proved by AdaLang too | GNATprove's verdict alone, on an AdaLang obligation | GNATprove's verdict alone, no AdaLang obligation | A definite error for AdaLang |
| --- | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2,446 | 1,335 | 945 | 166 | 0 |
| saatana | 367 | 188 | 164 | 15 | 0 |
| libkeccak | 3,321 | 1,541 | 1,348 | 432 | 0 |
| coap_spark | 6,795 | 3,493 | 2,037 | 1,265 | 0 |
| tokeneer | 2,114 | 1,382 | 501 | 231 | 0 |
| All five | 15,043 | 7,939 | 4,995 | 2,109 | 0 |

The second column is what AdaLang proves; it is 7,939 with the logs and
without them. The third and fourth are GNATprove's work, reported as
GNATprove's: 4,995 checks on an obligation AdaLang has and did not prove
(the 4,968 unproved, the 26 unsupported and the 1 unreachable above) and
2,109 for which it
has no obligation. Nothing is left over, which is all that "the gap is
zero" means here: with GNATprove's log beside it, an AdaLang report says
of each of the 15,043 checks who proved it. It does not mean AdaLang proves
them. The logs also hold 13 checks justified in Tokeneer and 22 GNATprove
did not prove (8 in SPARKNaCl, 14 in CoAP-SPARK), none of which AdaLang
proves.

That the analyzer and `gnatprove_gap_ledger.py` pair alike is tested on a
small case by `tests/run_gnatprove_import.sh`; that they give the same
totals on these corpora is what the table shows.

## Where the missing obligations are

2107 checks GNATprove proved have no AdaLang obligation at their place. By the construct they are in:

| Construct | Checks |
| --- | ---: |
| argument | 300 |
| slice | 281 |
| subprogram-body | 143 |
| in aspect global | 128 |
| in aspect pre | 126 |
| call-statement | 113 |
| in aspect post | 106 |
| object-declaration | 105 |
| attribute prefix or argument | 96 |
| assignment-value | 87 |
| expression-function | 78 |
| subprogram-declaration | 76 |
| in aspect contract_cases | 61 |
| condition | 50 |
| in pragma loop_invariant | 48 |
| loop-range | 36 |
| aggregate | 36 |
| component-declaration | 33 |
| in aspect refined_post | 30 |
| in pragma assert | 26 |
| in aspect initializes | 25 |
| conditional-expression | 17 |
| in aspect abstract_state | 16 |
| instantiation | 15 |
| assignment-target | 12 |

By GNATprove check, with the constructs it is most often in:

| GNATprove check | Checks | Where |
| --- | ---: | --- |
| range check | 440 | argument 117, object-declaration 52, expression-function 51, in pragma loop_invariant 44, in aspect pre 41 |
| pointer dereference check | 336 | attribute prefix or argument 94, slice 65, in aspect pre 63, in aspect post 63, argument 20 |
| precondition | 268 | call-statement 109, assignment-value 59, subprogram-declaration 21, in aspect pre 17, in aspect contract_cases 14 |
| index check | 212 | slice 194, aggregate 15, subtype-indication 2, argument 1 |
| resource or memory leak | 211 | subprogram-body 98, argument 51, object-declaration 45, condition 17 |
| discriminant check | 135 | subprogram-body 45, argument 41, condition 25, assignment-target 12, assignment-value 6 |
| initialization of | 115 | in aspect global 97, in aspect abstract_state 16, return 1, subprogram-declaration 1 |
| Always_Terminates | 67 | subprogram-declaration 50, expression-function 17 |
| predicate check | 49 | slice 13, argument 10, type-declaration 8, component-declaration 7, aggregate 6 |
| non-aliasing | 44 | argument 38, slice 6 |
| overflow check | 38 | argument 16, assignment-value 6, in aspect post 5, in aspect pre 3, expression-function 3 |
| contract case | 36 | in aspect contract_cases 36 |
| data dependencies | 31 | in aspect global 31 |
| flow dependencies | 25 | in aspect initializes 25 |
| postcondition | 24 | in aspect post 24 |
| refined post | 19 | in aspect refined_post 19 |
| unchecked conversion | 15 | instantiation 15 |
| default initial condition | 12 | component-declaration 6, object-declaration 6 |
| invariant check | 9 | call-statement 4, subprogram-declaration 4, type-declaration 1 |
| initialization check | 5 | argument 5 |
| assertion | 5 | condition 4, in pragma postcondition 1 |
| contract or exit cases | 4 | in aspect contract_cases 4 |
| Container_Aggregates annotation | 4 | in aspect annotate 4 |
| accessibility check | 2 | expression-function 2 |
| length check | 1 | conditional-expression 1 |

Produced by `benchmarks/gnatprove_gap_contexts.py` from the ledger's rows.
It has 2,481 of the 2,483 checks without an obligation: the script leaves
out a check whose source file it does not find under the corpus roots it is
given. The construct is read from the syntax alone, from the inside out. What is
left under a `Global` aspect is the initialization of state abstractions
and of globals in sources outside the analyzed project; under a subprogram
declaration, the termination and contract checks of the SPARK library
units, which the lanes do not analyze.

## sparknacl

GNATprove reports 2454 checks (2463 messages, a check of a generic unit being repeated for each instance): 2446 proved, 0 justified by the corpus, 8 not proved. AdaLang raises 10401 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1335 | 54.6% |
| unproved | 945 | 38.6% |
| no obligation here | 152 | 6.2% |
| no such obligation kind | 14 | 0.6% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 585 | 266 | 232 | 0 | 87 | 0 |
| initialization of | 356 | 297 | 57 | 0 | 2 | 0 |
| data dependencies | 198 | 198 | 0 | 0 | 0 | 0 |
| assertion | 187 | 22 | 165 | 0 | 0 | 0 |
| overflow check | 155 | 66 | 73 | 0 | 16 | 0 |
| division check | 153 | 153 | 0 | 0 | 0 | 0 |
| index check | 142 | 92 | 8 | 0 | 42 | 0 |
| precondition | 123 | 72 | 51 | 0 | 0 | 0 |
| initialization check | 105 | 29 | 74 | 0 | 2 | 0 |
| Always_Terminates | 103 | 79 | 24 | 0 | 0 | 0 |
| loop invariant initialization | 81 | 0 | 81 | 0 | 0 | 0 |
| loop invariant preservation | 79 | 0 | 79 | 0 | 0 | 0 |
| length check | 67 | 60 | 7 | 0 | 0 | 0 |
| predicate check | 58 | 0 | 55 | 0 | 3 | 0 |
| postcondition | 29 | 0 | 29 | 0 | 0 | 0 |
| loop variant | 10 | 0 | 10 | 0 | 0 | 0 |
| unchecked conversion | 6 | 0 | 0 | 0 | 6 | 0 |
| contract case | 6 | 0 | 0 | 0 | 6 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |
| flow dependencies | 1 | 1 | 0 | 0 | 0 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 74 |
| same kind within 3 lines | 64 |
| fewer obligations of this kind on the line | 7 |
| nothing on this line | 7 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the invariant is not at the loop-head cut point | 152 |
| unproved | incoming paths disagree or object is external | 101 |
| unproved | this expression form is outside the scalar VC subset | 81 |
| unproved | this call form cannot be inlined safely | 70 |
| unproved | the current range domain does not certify the result | 70 |
| unproved | the current non-relational range domain is inconclusive | 58 |
| unproved | the blocking object is not known to be initialized | 48 |
| unproved | the expression conflicts with its symbolic scalar sort | 42 |
| unproved | this quantified-expression form is not modeled | 42 |
| unproved | the scalar VC portfolio did not certify the predicate | 36 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 31 |
| unproved | some path to the exit does not assign the whole parameter | 30 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 81 | 3 | 78 | 0 |
| division-by-zero | 39 | 19 | 20 | 0 |
| index-check | 939 | 914 | 25 | 0 |
| initialization-check | 2720 | 2495 | 225 | 0 |
| integer-overflow | 1423 | 779 | 644 | 0 |
| postcondition | 1 | 0 | 1 | 0 |
| precondition | 119 | 72 | 47 | 0 |
| range-check | 1835 | 1366 | 469 | 0 |

## saatana

GNATprove reports 367 checks (376 messages, a check of a generic unit being repeated for each instance): 367 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 1647 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 188 | 51.2% |
| unproved | 164 | 44.7% |
| no obligation here | 15 | 4.1% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 103 | 40 | 60 | 0 | 3 | 0 |
| division check | 44 | 42 | 2 | 0 | 0 | 0 |
| overflow check | 31 | 11 | 20 | 0 | 0 | 0 |
| index check | 29 | 9 | 8 | 0 | 12 | 0 |
| precondition | 22 | 4 | 18 | 0 | 0 | 0 |
| length check | 20 | 10 | 10 | 0 | 0 | 0 |
| data dependencies | 20 | 20 | 0 | 0 | 0 | 0 |
| initialization of | 18 | 17 | 1 | 0 | 0 | 0 |
| flow dependencies | 14 | 14 | 0 | 0 | 0 | 0 |
| postcondition | 13 | 1 | 12 | 0 | 0 | 0 |
| assertion | 10 | 0 | 10 | 0 | 0 | 0 |
| Always_Terminates | 10 | 10 | 0 | 0 | 0 | 0 |
| loop invariant initialization | 9 | 0 | 9 | 0 | 0 | 0 |
| loop invariant preservation | 9 | 0 | 9 | 0 | 0 | 0 |
| initialization check | 6 | 5 | 1 | 0 | 0 | 0 |
| predicate check | 5 | 5 | 0 | 0 | 0 | 0 |
| loop variant | 4 | 0 | 4 | 0 | 0 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| same kind within 3 lines | 9 |
| another kind on this line | 6 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | this expression form is outside the scalar VC subset | 28 |
| unproved | the invariant is not at the loop-head cut point | 18 |
| unproved | the current range domain does not certify the result | 16 |
| unproved | slice bound and array bound ranges remain inconclusive | 14 |
| unproved | the current non-relational range domain is inconclusive | 12 |
| unproved | the callee is not a plain expression function | 10 |
| unproved | this operator is outside the scalar VC subset | 10 |
| unproved | current contract transfer does not certify safety | 8 |
| unproved | the required bounds are not statically known | 8 |
| unproved | the slice range is not written as two bounds | 7 |
| unproved | static evaluation is inconclusive | 6 |
| unproved | this call form cannot be inlined safely | 5 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 9 | 0 | 9 | 0 |
| division-by-zero | 15 | 14 | 1 | 0 |
| index-check | 164 | 147 | 17 | 0 |
| initialization-check | 573 | 492 | 81 | 0 |
| integer-overflow | 214 | 144 | 70 | 0 |
| length-check | 2 | 0 | 2 | 0 |
| precondition | 73 | 4 | 69 | 0 |
| range-check | 206 | 94 | 112 | 0 |

## libkeccak

GNATprove reports 3321 checks (20673 messages, a check of a generic unit being repeated for each instance): 3321 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 12533 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1541 | 46.4% |
| unproved | 1346 | 40.5% |
| unsupported | 2 | 0.1% |
| no obligation here | 365 | 11.0% |
| no such obligation kind | 67 | 2.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 631 | 271 | 271 | 0 | 89 | 0 |
| overflow check | 569 | 180 | 384 | 0 | 5 | 0 |
| initialization of | 344 | 190 | 73 | 0 | 81 | 0 |
| division check | 306 | 260 | 46 | 0 | 0 | 0 |
| precondition | 273 | 65 | 91 | 1 | 116 | 0 |
| index check | 199 | 46 | 80 | 0 | 73 | 0 |
| data dependencies | 155 | 150 | 5 | 0 | 0 | 0 |
| predicate check | 154 | 62 | 91 | 0 | 1 | 0 |
| loop invariant initialization | 114 | 54 | 60 | 0 | 0 | 0 |
| loop invariant preservation | 114 | 28 | 86 | 0 | 0 | 0 |
| assertion | 90 | 25 | 65 | 0 | 0 | 0 |
| flow dependencies | 81 | 81 | 0 | 0 | 0 | 0 |
| postcondition | 79 | 22 | 56 | 1 | 0 | 0 |
| length check | 74 | 60 | 14 | 0 | 0 | 0 |
| Always_Terminates | 46 | 45 | 1 | 0 | 0 | 0 |
| non-aliasing | 37 | 0 | 0 | 0 | 37 | 0 |
| contract case | 28 | 0 | 0 | 0 | 28 | 0 |
| loop variant | 21 | 0 | 21 | 0 | 0 | 0 |
| initialization check | 4 | 2 | 2 | 0 | 0 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 219 |
| same kind within 3 lines | 111 |
| nothing on this line | 29 |
| fewer obligations of this kind on the line | 6 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the current range domain does not certify the result | 378 |
| unproved | slice bound and array bound ranges remain inconclusive | 104 |
| unproved | the required bounds are not statically known | 103 |
| unproved | the current non-relational range domain is inconclusive | 93 |
| unproved | the scalar VC portfolio did not certify the predicate | 91 |
| unproved | current contract transfer does not certify safety | 84 |
| unproved | the scalar loop preservation VC was not discharged | 80 |
| unproved | incoming paths disagree or object is external | 59 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 44 |
| unproved | the scalar loop initialization VC was not discharged | 42 |
| unproved | Ada division semantics require a provably nonzero divisor | 35 |
| unproved | exit states do not imply the contract | 29 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 141 | 12 | 129 | 0 |
| data-dependencies | 36 | 15 | 21 | 0 |
| division-by-zero | 399 | 372 | 27 | 0 |
| flow-dependencies | 8 | 3 | 5 | 0 |
| index-check | 677 | 626 | 51 | 0 |
| initialization-check | 4702 | 4000 | 698 | 4 |
| integer-overflow | 1026 | 483 | 543 | 0 |
| length-check | 20 | 18 | 2 | 0 |
| loop-invariant-initialization | 17 | 6 | 11 | 0 |
| loop-invariant-preservation | 17 | 1 | 16 | 0 |
| loop-variant | 2 | 0 | 2 | 0 |
| postcondition | 3 | 0 | 3 | 0 |
| precondition | 195 | 69 | 125 | 1 |
| range-check | 1671 | 430 | 1241 | 0 |
| termination | 4 | 3 | 1 | 0 |

## coap_spark

GNATprove reports 6809 checks (7423 messages, a check of a generic unit being repeated for each instance): 6795 proved, 0 justified by the corpus, 14 not proved. AdaLang raises 22501 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 3493 | 51.4% |
| unproved | 2012 | 29.6% |
| unsupported | 24 | 0.4% |
| unreachable | 1 | 0.0% |
| no obligation here | 481 | 7.1% |
| no such obligation kind | 577 | 8.5% |
| file without any obligation | 207 | 3.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| precondition | 2294 | 1523 | 616 | 12 | 143 | 0 |
| Always_Terminates | 869 | 723 | 79 | 0 | 67 | 0 |
| range check | 845 | 268 | 417 | 2 | 158 | 0 |
| postcondition | 379 | 105 | 250 | 0 | 24 | 0 |
| pointer dereference check | 336 | 0 | 0 | 0 | 336 | 0 |
| assertion | 299 | 184 | 107 | 3 | 4 | 0 |
| overflow check | 278 | 99 | 163 | 0 | 16 | 0 |
| initialization of | 277 | 226 | 42 | 7 | 2 | 0 |
| division check | 265 | 233 | 32 | 0 | 0 | 0 |
| resource or memory leak | 211 | 0 | 0 | 0 | 211 | 0 |
| predicate check | 181 | 0 | 136 | 0 | 45 | 0 |
| discriminant check | 135 | 0 | 0 | 0 | 135 | 0 |
| length check | 108 | 81 | 24 | 0 | 3 | 0 |
| index check | 96 | 6 | 41 | 0 | 49 | 0 |
| loop invariant preservation | 47 | 2 | 45 | 0 | 0 | 0 |
| loop invariant initialization | 47 | 9 | 38 | 0 | 0 | 0 |
| data dependencies | 42 | 6 | 5 | 0 | 31 | 0 |
| flow dependencies | 28 | 26 | 0 | 0 | 2 | 0 |
| initialization check | 21 | 2 | 16 | 0 | 3 | 0 |
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
| another kind on this line | 261 |
| same kind within 3 lines | 153 |
| nothing on this line | 59 |
| fewer obligations of this kind on the line | 8 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | current contract transfer does not certify safety | 515 |
| unproved | the required bounds are not statically known | 217 |
| unproved | this attribute is outside the scalar VC subset | 186 |
| unproved | this call form cannot be inlined safely | 162 |
| unproved | the scalar VC portfolio did not certify the predicate | 101 |
| unproved | slice bound and array bound ranges remain inconclusive | 98 |
| unproved | exit states do not imply the contract | 87 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 83 |
| unproved | this expression form is outside the scalar VC subset | 82 |
| unproved | the current non-relational range domain is inconclusive | 64 |
| unproved | incoming paths disagree or object is external | 46 |
| unproved | the current range domain does not certify the result | 43 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 58 | 5 | 53 | 0 |
| division-by-zero | 13 | 5 | 8 | 0 |
| flow-dependencies | 3 | 3 | 0 | 0 |
| index-check | 841 | 5 | 836 | 0 |
| initialization-check | 10904 | 10238 | 649 | 17 |
| integer-overflow | 985 | 322 | 663 | 0 |
| length-check | 5 | 5 | 0 | 0 |
| postcondition | 23 | 2 | 21 | 0 |
| precondition | 2314 | 1615 | 687 | 12 |
| predicate-check | 32 | 0 | 32 | 0 |
| range-check | 1165 | 310 | 829 | 25 |
| termination | 48 | 13 | 35 | 0 |

GNATprove messages not counted as checks: function contract feasibility proved (Z3: 1 VC in max 0.0 se (2); function contract feasibility proved (CVC5: 1 VC in max 0.0  (2).

## tokeneer

GNATprove reports 2127 checks (2205 messages, a check of a generic unit being repeated for each instance): 2114 proved, 13 justified by the corpus, 0 not proved. AdaLang raises 8980 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1382 | 65.4% |
| unproved | 501 | 23.7% |
| no obligation here | 201 | 9.5% |
| no such obligation kind | 28 | 1.3% |
| file without any obligation | 2 | 0.1% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initialization of | 708 | 495 | 183 | 0 | 30 | 0 |
| data dependencies | 281 | 265 | 16 | 0 | 0 | 0 |
| flow dependencies | 233 | 210 | 0 | 0 | 23 | 0 |
| precondition | 226 | 159 | 58 | 0 | 9 | 0 |
| range check | 208 | 28 | 77 | 0 | 103 | 0 |
| Always_Terminates | 141 | 133 | 8 | 0 | 0 | 0 |
| postcondition | 57 | 2 | 55 | 0 | 0 | 0 |
| index check | 56 | 13 | 7 | 0 | 36 | 0 |
| length check | 42 | 15 | 27 | 0 | 0 | 0 |
| division check | 41 | 41 | 0 | 0 | 0 | 0 |
| overflow check | 29 | 20 | 8 | 0 | 1 | 0 |
| predicate check | 23 | 0 | 23 | 0 | 0 | 0 |
| refined post | 19 | 0 | 0 | 0 | 19 | 0 |
| loop invariant initialization | 19 | 1 | 18 | 0 | 0 | 0 |
| loop invariant preservation | 19 | 0 | 19 | 0 | 0 | 0 |
| invariant check | 9 | 0 | 0 | 0 | 9 | 0 |
| assertion | 3 | 0 | 2 | 0 | 1 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 80 |
| same kind within 3 lines | 69 |
| nothing on this line | 48 |
| fewer obligations of this kind on the line | 4 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | some path to the exit does not assign the whole object, or it is a state abstraction | 116 |
| unproved | the blocking object is not known to be initialized | 73 |
| unproved | incoming paths disagree or object is external | 45 |
| unproved | current contract transfer does not certify safety | 30 |
| unproved | this call form cannot be inlined safely | 23 |
| unproved | some path to the exit does not assign the whole parameter | 22 |
| unproved | a record formal requires a plain object-reference actual | 21 |
| unproved | the two lengths are not known to be equal | 20 |
| unproved | slice bound and array bound ranges remain inconclusive | 18 |
| unproved | this expression form is outside the scalar VC subset | 17 |
| unproved | State is used and is not listed | 16 |
| unproved | the scalar loop preservation VC was not discharged | 15 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 19 | 0 | 19 | 0 |
| division-by-zero | 10 | 8 | 2 | 0 |
| index-check | 248 | 76 | 162 | 10 |
| initialization-check | 3571 | 2419 | 1112 | 40 |
| integer-overflow | 230 | 89 | 139 | 2 |
| length-check | 56 | 16 | 40 | 0 |
| postcondition | 4 | 2 | 2 | 0 |
| precondition | 400 | 194 | 206 | 0 |
| predicate-check | 10 | 0 | 10 | 0 |
| range-check | 1892 | 384 | 1500 | 8 |

