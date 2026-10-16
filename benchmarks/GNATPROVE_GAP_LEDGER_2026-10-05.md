# What separates `--verify` from GNATprove: a ledger

Recorded 2026-10-16 with AdaLang Analyzer 1.8.9, against the GNATprove
output saved by the 2026-10-02 runs of the five fully proved corpora
(`sparknacl`, `saatana`, `libkeccak`, `coap_spark`, `tokeneer`). The file
keeps the name it was given when the ledger was started, on 2026-10-05.
What each release has added since is in `CHANGELOG.md`, and earlier states
of the ledger are in the Git history.

The per-corpus comparisons (`<corpus>/RESULTS_2026-10-16.md`) answer one
question: where both tools have exactly one obligation of a kind on a line,
do they ever disagree? This ledger asks the other one: of everything
GNATprove proves, how much does AdaLang prove, and what happens to the rest?
Every check GNATprove reports is a row; none is left out for being hard to
pair.

## Where it stands

Of the 15,043 checks GNATprove proves on the five corpora, AdaLang proves
6,690. It has an obligation that it does not decide for 5,870 more (5,241
unproved, 629 unsupported) and no obligation for 2,483. In the other
direction it proves none of the 22 checks GNATprove leaves unproved, and
reports no definite error on a check GNATprove proves.

By kind, summed over the per-corpus tables below, AdaLang proves:

- 1,436 of GNATprove's 2,938 preconditions;
- 827 of its 2,372 range checks;
- 1,207 of its 1,703 initializations of an object;
- 990 of its 1,169 termination checks;
- 595 of its 696 data-dependency (`Global`) checks, and none of its 357
  flow-dependency (`Depends`) checks, for which `--verify` has an
  obligation and no route to prove it yet.

What is left:

- **Unproved (5,241).** AdaLang has the obligation and does not decide it.
  The per-corpus tables below give the reason it reports for each.
- **Unsupported (629).** The obligation is in a subprogram that
  `--verify` leaves outside the verified subset, mostly for an instance of
  a generic subprogram declared in it or a quantified expression used as a
  value, or at an expression it does not model; 505 of them are in
  `coap_spark`.
- **No obligation (2,483).** Predicate, pointer-dereference and
  discriminant checks and memory leaks, which AdaLang does not have; and
  range, index and precondition checks at places it does not yet look.
  "Where the missing obligations are", below, says where.

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
    obligation, with that verdict.
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
| proved-safe | 6690 | 44.5% |
| unproved | 5241 | 34.8% |
| unsupported | 629 | 4.2% |
| no obligation here | 1169 | 7.8% |
| no such obligation kind | 1105 | 7.3% |
| file without any obligation | 209 | 1.4% |

| Corpus | Proved by GNATprove | AdaLang proved | Unproved | Unsupported | No obligation here | No such kind | File without obligations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2446 | 1307 | 798 | 120 | 149 | 72 | 0 |
| saatana | 367 | 164 | 183 | 0 | 15 | 5 | 0 |
| libkeccak | 3321 | 1225 | 1509 | 2 | 364 | 221 | 0 |
| coap_spark | 6795 | 2834 | 2053 | 505 | 440 | 756 | 207 |
| tokeneer | 2114 | 1160 | 698 | 2 | 201 | 51 | 2 |

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
| sparknacl | 2,446 | 1,307 | 918 | 221 | 0 |
| saatana | 367 | 164 | 183 | 20 | 0 |
| libkeccak | 3,321 | 1,225 | 1,511 | 585 | 0 |
| coap_spark | 6,795 | 2,834 | 2,558 | 1,403 | 0 |
| tokeneer | 2,114 | 1,160 | 700 | 254 | 0 |
| All five | 15,043 | 6,690 | 5,870 | 2,483 | 0 |

The second column is what AdaLang proves; it is 6,690 with the logs and
without them. The third and fourth are GNATprove's work, reported as
GNATprove's: 5,870 checks on an obligation AdaLang has and did not decide
(the 5,241 unproved and the 629 unsupported above) and 2,483 for which it
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

2481 checks GNATprove proved have no AdaLang obligation at their place. By the construct they are in:

| Construct | Checks |
| --- | ---: |
| argument | 421 |
| slice | 301 |
| assignment-target | 185 |
| subprogram-body | 143 |
| assignment-value | 139 |
| in aspect global | 128 |
| in aspect pre | 126 |
| call-statement | 113 |
| object-declaration | 107 |
| in aspect post | 106 |
| attribute prefix or argument | 96 |
| expression-function | 83 |
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

By GNATprove check, with the constructs it is most often in:

| GNATprove check | Checks | Where |
| --- | ---: | --- |
| range check | 442 | argument 117, object-declaration 52, expression-function 51, in pragma loop_invariant 44, in aspect pre 41 |
| predicate check | 421 | assignment-target 173, argument 131, assignment-value 50, slice 33, type-declaration 8 |
| pointer dereference check | 336 | attribute prefix or argument 94, slice 65, in aspect pre 63, in aspect post 63, argument 20 |
| precondition | 268 | call-statement 109, assignment-value 59, subprogram-declaration 21, in aspect pre 17, in aspect contract_cases 14 |
| index check | 212 | slice 194, aggregate 15, subtype-indication 2, argument 1 |
| resource or memory leak | 211 | subprogram-body 98, argument 51, object-declaration 45, condition 17 |
| discriminant check | 135 | subprogram-body 45, argument 41, condition 25, assignment-target 12, assignment-value 6 |
| initialization of | 115 | in aspect global 97, in aspect abstract_state 16, return 1, subprogram-declaration 1 |
| Always_Terminates | 67 | subprogram-declaration 50, expression-function 17 |
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

GNATprove reports 2454 checks (2463 messages, a check of a generic unit being repeated for each instance): 2446 proved, 0 justified by the corpus, 8 not proved. AdaLang raises 10344 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1307 | 53.4% |
| unproved | 798 | 32.6% |
| unsupported | 120 | 4.9% |
| no obligation here | 149 | 6.1% |
| no such obligation kind | 72 | 2.9% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 585 | 265 | 211 | 22 | 87 | 0 |
| initialization of | 356 | 291 | 57 | 6 | 2 | 0 |
| data dependencies | 198 | 197 | 1 | 0 | 0 | 0 |
| assertion | 187 | 22 | 147 | 18 | 0 | 0 |
| overflow check | 155 | 66 | 73 | 0 | 16 | 0 |
| division check | 153 | 147 | 0 | 6 | 0 | 0 |
| index check | 142 | 85 | 9 | 6 | 42 | 0 |
| precondition | 123 | 72 | 41 | 10 | 0 | 0 |
| initialization check | 105 | 23 | 42 | 38 | 2 | 0 |
| Always_Terminates | 103 | 79 | 24 | 0 | 0 | 0 |
| loop invariant initialization | 81 | 0 | 74 | 7 | 0 | 0 |
| loop invariant preservation | 79 | 0 | 72 | 7 | 0 | 0 |
| length check | 67 | 60 | 7 | 0 | 0 | 0 |
| predicate check | 58 | 0 | 0 | 0 | 58 | 0 |
| postcondition | 29 | 0 | 29 | 0 | 0 | 0 |
| loop variant | 10 | 0 | 10 | 0 | 0 | 0 |
| unchecked conversion | 6 | 0 | 0 | 0 | 6 | 0 |
| contract case | 6 | 0 | 0 | 0 | 6 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |
| flow dependencies | 1 | 0 | 1 | 0 | 0 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 74 |
| same kind within 3 lines | 64 |
| nothing on this line | 6 |
| fewer obligations of this kind on the line | 5 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the invariant is not at the loop-head cut point | 138 |
| unsupported | outside bounded verification subset | 120 |
| unproved | this expression form is outside the scalar VC subset | 70 |
| unproved | the current range domain does not certify the result | 70 |
| unproved | incoming paths disagree or object is external | 69 |
| unproved | this call form cannot be inlined safely | 68 |
| unproved | the current non-relational range domain is inconclusive | 56 |
| unproved | the expression conflicts with its symbolic scalar sort | 42 |
| unproved | some path to the exit does not assign the whole parameter | 30 |
| unproved | slice bound and array bound ranges remain inconclusive | 29 |
| unproved | this quantified-expression form is not modeled | 28 |
| unproved | current contract transfer does not certify safety | 27 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 81 | 3 | 71 | 7 |
| division-by-zero | 39 | 19 | 20 | 0 |
| index-check | 939 | 857 | 25 | 57 |
| initialization-check | 2720 | 2469 | 212 | 39 |
| integer-overflow | 1423 | 769 | 638 | 16 |
| postcondition | 1 | 0 | 1 | 0 |
| precondition | 119 | 72 | 37 | 10 |
| range-check | 1833 | 1365 | 465 | 3 |

## saatana

GNATprove reports 367 checks (376 messages, a check of a generic unit being repeated for each instance): 367 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 1642 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 164 | 44.7% |
| unproved | 183 | 49.9% |
| no obligation here | 15 | 4.1% |
| no such obligation kind | 5 | 1.4% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 103 | 38 | 62 | 0 | 3 | 0 |
| division check | 44 | 42 | 2 | 0 | 0 | 0 |
| overflow check | 31 | 11 | 20 | 0 | 0 | 0 |
| index check | 29 | 9 | 8 | 0 | 12 | 0 |
| precondition | 22 | 2 | 20 | 0 | 0 | 0 |
| length check | 20 | 10 | 10 | 0 | 0 | 0 |
| data dependencies | 20 | 20 | 0 | 0 | 0 | 0 |
| initialization of | 18 | 17 | 1 | 0 | 0 | 0 |
| flow dependencies | 14 | 0 | 14 | 0 | 0 | 0 |
| postcondition | 13 | 0 | 13 | 0 | 0 | 0 |
| assertion | 10 | 0 | 10 | 0 | 0 | 0 |
| Always_Terminates | 10 | 10 | 0 | 0 | 0 | 0 |
| loop invariant initialization | 9 | 0 | 9 | 0 | 0 | 0 |
| loop invariant preservation | 9 | 0 | 9 | 0 | 0 | 0 |
| initialization check | 6 | 5 | 1 | 0 | 0 | 0 |
| predicate check | 5 | 0 | 0 | 0 | 5 | 0 |
| loop variant | 4 | 0 | 4 | 0 | 0 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| same kind within 3 lines | 9 |
| another kind on this line | 6 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | this expression form is outside the scalar VC subset | 29 |
| unproved | the invariant is not at the loop-head cut point | 18 |
| unproved | the current range domain does not certify the result | 16 |
| unproved | information flow is not yet analyzed to the point of proof | 14 |
| unproved | the current non-relational range domain is inconclusive | 14 |
| unproved | slice bound and array bound ranges remain inconclusive | 14 |
| unproved | current contract transfer does not certify safety | 10 |
| unproved | this operator is outside the scalar VC subset | 10 |
| unproved | the callee is not a plain expression function | 9 |
| unproved | the required bounds are not statically known | 8 |
| unproved | the slice range is not written as two bounds | 7 |
| unproved | static evaluation is inconclusive | 6 |

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
| integer-overflow | 214 | 142 | 72 | 0 |
| length-check | 2 | 0 | 2 | 0 |
| precondition | 73 | 2 | 71 | 0 |
| range-check | 206 | 94 | 112 | 0 |

## libkeccak

GNATprove reports 3321 checks (20673 messages, a check of a generic unit being repeated for each instance): 3321 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 12380 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1225 | 36.9% |
| unproved | 1509 | 45.4% |
| unsupported | 2 | 0.1% |
| no obligation here | 364 | 11.0% |
| no such obligation kind | 221 | 6.7% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 631 | 256 | 286 | 0 | 89 | 0 |
| overflow check | 569 | 155 | 409 | 0 | 5 | 0 |
| initialization of | 344 | 190 | 73 | 0 | 81 | 0 |
| division check | 306 | 260 | 46 | 0 | 0 | 0 |
| precondition | 273 | 34 | 122 | 1 | 116 | 0 |
| index check | 199 | 45 | 81 | 0 | 73 | 0 |
| data dependencies | 155 | 113 | 42 | 0 | 0 | 0 |
| predicate check | 154 | 0 | 0 | 0 | 154 | 0 |
| loop invariant initialization | 114 | 45 | 69 | 0 | 0 | 0 |
| loop invariant preservation | 114 | 4 | 110 | 0 | 0 | 0 |
| assertion | 90 | 14 | 76 | 0 | 0 | 0 |
| flow dependencies | 81 | 0 | 81 | 0 | 0 | 0 |
| postcondition | 79 | 3 | 75 | 1 | 0 | 0 |
| length check | 74 | 59 | 15 | 0 | 0 | 0 |
| Always_Terminates | 46 | 45 | 1 | 0 | 0 | 0 |
| non-aliasing | 37 | 0 | 0 | 0 | 37 | 0 |
| contract case | 28 | 0 | 0 | 0 | 28 | 0 |
| loop variant | 21 | 0 | 21 | 0 | 0 | 0 |
| initialization check | 4 | 2 | 2 | 0 | 0 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 218 |
| same kind within 3 lines | 111 |
| nothing on this line | 29 |
| fewer obligations of this kind on the line | 6 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the current range domain does not certify the result | 400 |
| unproved | current contract transfer does not certify safety | 111 |
| unproved | the current non-relational range domain is inconclusive | 105 |
| unproved | slice bound and array bound ranges remain inconclusive | 105 |
| unproved | the scalar loop preservation VC was not discharged | 104 |
| unproved | the required bounds are not statically known | 104 |
| unproved | information flow is not yet analyzed to the point of proof | 81 |
| unproved | incoming paths disagree or object is external | 59 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 50 |
| unproved | the scalar loop initialization VC was not discharged | 48 |
| unproved | Ada division semantics require a provably nonzero divisor | 35 |
| unproved | the blocking object is not known to be initialized | 31 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 141 | 1 | 140 | 0 |
| data-dependencies | 36 | 15 | 21 | 0 |
| division-by-zero | 399 | 372 | 27 | 0 |
| flow-dependencies | 8 | 0 | 8 | 0 |
| index-check | 677 | 626 | 51 | 0 |
| initialization-check | 4702 | 4000 | 698 | 4 |
| integer-overflow | 1026 | 465 | 561 | 0 |
| length-check | 20 | 18 | 2 | 0 |
| loop-invariant-initialization | 17 | 4 | 13 | 0 |
| loop-invariant-preservation | 17 | 1 | 16 | 0 |
| loop-variant | 2 | 0 | 2 | 0 |
| postcondition | 3 | 0 | 3 | 0 |
| precondition | 195 | 38 | 156 | 1 |
| range-check | 1671 | 412 | 1259 | 0 |
| termination | 4 | 3 | 1 | 0 |

## coap_spark

GNATprove reports 6809 checks (7423 messages, a check of a generic unit being repeated for each instance): 6795 proved, 0 justified by the corpus, 14 not proved. AdaLang raises 22331 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 2834 | 41.7% |
| unproved | 2053 | 30.2% |
| unsupported | 505 | 7.4% |
| no obligation here | 440 | 6.5% |
| no such obligation kind | 756 | 11.1% |
| file without any obligation | 207 | 3.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| precondition | 2294 | 1172 | 718 | 261 | 143 | 0 |
| Always_Terminates | 869 | 723 | 79 | 0 | 67 | 0 |
| range check | 845 | 241 | 431 | 13 | 160 | 0 |
| postcondition | 379 | 63 | 260 | 32 | 24 | 0 |
| pointer dereference check | 336 | 0 | 0 | 0 | 336 | 0 |
| assertion | 299 | 38 | 125 | 132 | 4 | 0 |
| overflow check | 278 | 76 | 163 | 23 | 16 | 0 |
| initialization of | 277 | 214 | 43 | 18 | 2 | 0 |
| division check | 265 | 225 | 32 | 8 | 0 | 0 |
| resource or memory leak | 211 | 0 | 0 | 0 | 211 | 0 |
| predicate check | 181 | 0 | 0 | 0 | 181 | 0 |
| discriminant check | 135 | 0 | 0 | 0 | 135 | 0 |
| length check | 108 | 61 | 42 | 2 | 3 | 0 |
| index check | 96 | 5 | 26 | 16 | 49 | 0 |
| loop invariant preservation | 47 | 2 | 45 | 0 | 0 | 0 |
| loop invariant initialization | 47 | 7 | 40 | 0 | 0 | 0 |
| data dependencies | 42 | 5 | 6 | 0 | 31 | 0 |
| flow dependencies | 28 | 0 | 26 | 0 | 2 | 0 |
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
| another kind on this line | 243 |
| same kind within 3 lines | 145 |
| nothing on this line | 44 |
| fewer obligations of this kind on the line | 8 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | current contract transfer does not certify safety | 653 |
| unsupported | outside bounded verification subset | 505 |
| unproved | this attribute is outside the scalar VC subset | 227 |
| unproved | the required bounds are not statically known | 192 |
| unproved | this call form cannot be inlined safely | 162 |
| unproved | slice bound and array bound ranges remain inconclusive | 96 |
| unproved | the current non-relational range domain is inconclusive | 82 |
| unproved | this expression form is outside the scalar VC subset | 66 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 64 |
| unproved | the blocking object is not known to be initialized | 61 |
| unproved | incoming paths disagree or object is external | 49 |
| unproved | exit states do not imply the contract | 49 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 58 | 4 | 54 | 0 |
| division-by-zero | 13 | 5 | 8 | 0 |
| flow-dependencies | 3 | 0 | 3 | 0 |
| index-check | 841 | 5 | 794 | 42 |
| initialization-check | 10904 | 9718 | 630 | 556 |
| integer-overflow | 985 | 285 | 656 | 44 |
| length-check | 5 | 3 | 2 | 0 |
| postcondition | 23 | 0 | 23 | 0 |
| precondition | 2314 | 1270 | 803 | 241 |
| range-check | 1165 | 283 | 679 | 203 |
| termination | 48 | 13 | 35 | 0 |

GNATprove messages not counted as checks: function contract feasibility proved (Z3: 1 VC in max 0.0 se (2); function contract feasibility proved (CVC5: 1 VC in max 0.0  (2).

## tokeneer

GNATprove reports 2127 checks (2205 messages, a check of a generic unit being repeated for each instance): 2114 proved, 13 justified by the corpus, 0 not proved. AdaLang raises 8937 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1160 | 54.9% |
| unproved | 698 | 33.0% |
| unsupported | 2 | 0.1% |
| no obligation here | 201 | 9.5% |
| no such obligation kind | 51 | 2.4% |
| file without any obligation | 2 | 0.1% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initialization of | 708 | 495 | 183 | 0 | 30 | 0 |
| data dependencies | 281 | 260 | 21 | 0 | 0 | 0 |
| flow dependencies | 233 | 0 | 210 | 0 | 23 | 0 |
| precondition | 226 | 156 | 61 | 0 | 9 | 0 |
| range check | 208 | 27 | 78 | 0 | 103 | 0 |
| Always_Terminates | 141 | 133 | 8 | 0 | 0 | 0 |
| postcondition | 57 | 2 | 55 | 0 | 0 | 0 |
| index check | 56 | 10 | 8 | 2 | 36 | 0 |
| length check | 42 | 15 | 27 | 0 | 0 | 0 |
| division check | 41 | 41 | 0 | 0 | 0 | 0 |
| overflow check | 29 | 20 | 8 | 0 | 1 | 0 |
| predicate check | 23 | 0 | 0 | 0 | 23 | 0 |
| refined post | 19 | 0 | 0 | 0 | 19 | 0 |
| loop invariant initialization | 19 | 1 | 18 | 0 | 0 | 0 |
| loop invariant preservation | 19 | 0 | 19 | 0 | 0 | 0 |
| invariant check | 9 | 0 | 0 | 0 | 9 | 0 |
| assertion | 3 | 0 | 2 | 0 | 1 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 77 |
| same kind within 3 lines | 69 |
| nothing on this line | 51 |
| fewer obligations of this kind on the line | 4 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | information flow is not yet analyzed to the point of proof | 210 |
| unproved | some path to the exit does not assign the whole object, or it is a state abstraction | 116 |
| unproved | the blocking object is not known to be initialized | 52 |
| unproved | incoming paths disagree or object is external | 45 |
| unproved | this expression form is outside the scalar VC subset | 40 |
| unproved | current contract transfer does not certify safety | 33 |
| unproved | this call form cannot be inlined safely | 23 |
| unproved | some path to the exit does not assign the whole parameter | 22 |
| unproved | the two lengths are not known to be equal | 20 |
| unproved | slice bound and array bound ranges remain inconclusive | 18 |
| unproved | State is used and is not listed | 16 |
| unproved | the current non-relational range domain is inconclusive | 15 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 19 | 0 | 19 | 0 |
| division-by-zero | 10 | 8 | 2 | 0 |
| index-check | 248 | 76 | 159 | 13 |
| initialization-check | 3571 | 2411 | 1109 | 51 |
| integer-overflow | 230 | 89 | 139 | 2 |
| length-check | 56 | 16 | 40 | 0 |
| postcondition | 4 | 0 | 4 | 0 |
| precondition | 400 | 192 | 208 | 0 |
| range-check | 1892 | 383 | 1501 | 8 |

