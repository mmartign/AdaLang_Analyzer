# What separates `--verify` from GNATprove: a ledger

Recorded 2026-10-29 with AdaLang Analyzer 1.11.2, against the GNATprove
output saved by the 2026-10-02 runs of the five fully proved corpora
(`sparknacl`, `saatana`, `libkeccak`, `coap_spark`, `tokeneer`). The ledger
was started on 2026-10-05. What each release has added since is in
`CHANGELOG.md`, and earlier states of the ledger are in the Git history.

The per-corpus comparisons (`<corpus>/RESULTS_2026-10-29.md`) answer one
question: where both tools have exactly one obligation of a kind on a line,
do they ever disagree? This ledger asks the other one: of everything
GNATprove proves, how much does AdaLang prove, and what happens to the rest?
Every check GNATprove reports is a row; none is left out for being hard to
pair.

## Where it stands

Of the 15,043 checks GNATprove proves on the five corpora, AdaLang proves
9,229. It has an obligation that it does not decide for 4,225 more (4,197
unproved, 28 unsupported), finds 1 in code that is never reached, and
has no obligation for 1,588. In the other
direction it proves none of the 22 checks GNATprove leaves unproved, and
reports no definite error on a check GNATprove proves.

By kind, summed over the per-corpus tables below, AdaLang proves:

- 1,909 of GNATprove's 2,938 preconditions;
- 1,181 of its 2,372 range checks;
- 320 of its 522 index checks, those at each bound of a slice
  that is the target of an assignment among them, which AdaLang raises
  since 1.11.2;
- 1,225 of its 1,703 initializations of an object;
- 990 of its 1,169 termination checks;
- 639 of its 696 data-dependency (`Global`) checks and 332 of its
  357 flow-dependency checks, every `Depends` aspect; those left
  are GNATprove's checks of `Initializes` aspects, for which AdaLang has
  no obligation;
- 78 of its 421 predicate checks, which AdaLang raises since
  1.10.0 at an assignment, a call, a declaration and a return; the
  predicates it leaves unproved read what it does not express (access
  values, quantified array elements) or need facts that do not survive a
  loop;
- 302 of its 336 pointer dereference checks, which AdaLang raises
  since 1.11.0 in SPARK code; of the 34 it leaves, 16 are in CoAP-SPARK's
  own code, 9 in the predicate of a subtype or other code it does not
  analyze for its own checks, 7 in RecordFlux's generic subprograms and
  the postcondition of its `Take_Buffer`, and 2 in subprograms outside the
  verified subset.

What is left:

- **Unproved (4,197).** AdaLang has the obligation and does not decide it.
  The per-corpus tables below give the reason it reports for each.
- **Unsupported (28).** The obligation is in a subprogram that
  `--verify` leaves outside the verified subset, almost all for a
  dispatching call; 26 of them are in `coap_spark`.
- **No obligation (1,588).** Discriminant checks and memory leaks,
  which AdaLang does not have; predicate checks
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
| proved-safe | 9229 | 61.4% |
| unproved | 4197 | 27.9% |
| unsupported | 28 | 0.2% |
| unreachable | 1 | 0.0% |
| no obligation here | 1029 | 6.8% |
| no such obligation kind | 350 | 2.3% |
| file without any obligation | 209 | 1.4% |

| Corpus | Proved by GNATprove | AdaLang proved | Unproved | Unsupported | No obligation here | No such kind | File without obligations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2446 | 1488 | 834 | 0 | 110 | 14 | 0 |
| saatana | 367 | 213 | 149 | 0 | 5 | 0 | 0 |
| libkeccak | 3321 | 2033 | 912 | 2 | 307 | 67 | 0 |
| coap_spark | 6795 | 4069 | 1809 | 26 | 442 | 241 | 207 |
| tokeneer | 2114 | 1426 | 493 | 0 | 165 | 28 | 2 |

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
| sparknacl | 2,446 | 1,488 | 834 | 124 | 0 |
| saatana | 367 | 213 | 149 | 5 | 0 |
| libkeccak | 3,321 | 2,033 | 914 | 374 | 0 |
| coap_spark | 6,795 | 4,069 | 1,836 | 890 | 0 |
| tokeneer | 2,114 | 1,426 | 493 | 195 | 0 |
| All five | 15,043 | 9,229 | 4,226 | 1,588 | 0 |

The second column is what AdaLang proves; it is 9,229 with the logs and
without them. The third and fourth are GNATprove's work, reported as
GNATprove's: 4,226 checks on an obligation AdaLang has and did not prove
(the 4,197 unproved, the 28 unsupported and the 1 unreachable above) and
1,588 for which it
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

1586 checks GNATprove proved have no AdaLang obligation at their place. By the construct they are in:

| Construct | Checks |
| --- | ---: |
| argument | 280 |
| subprogram-body | 143 |
| in aspect global | 128 |
| call-statement | 113 |
| object-declaration | 105 |
| assignment-value | 86 |
| expression-function | 76 |
| subprogram-declaration | 76 |
| in aspect pre | 63 |
| in aspect contract_cases | 61 |
| condition | 49 |
| in pragma loop_invariant | 48 |
| in aspect post | 43 |
| loop-range | 36 |
| aggregate | 36 |
| component-declaration | 33 |
| in aspect refined_post | 30 |
| in aspect initializes | 25 |
| slice | 22 |
| in pragma assert | 17 |
| conditional-expression | 16 |
| in aspect abstract_state | 16 |
| instantiation | 15 |
| assignment-target | 12 |
| subtype-indication | 11 |

By GNATprove check, with the constructs it is most often in:

| GNATprove check | Checks | Where |
| --- | ---: | --- |
| range check | 440 | argument 117, object-declaration 52, expression-function 51, in pragma loop_invariant 44, in aspect pre 41 |
| precondition | 268 | call-statement 109, assignment-value 59, subprogram-declaration 21, in aspect pre 17, in aspect contract_cases 14 |
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
| index check | 18 | aggregate 15, subtype-indication 2, argument 1 |
| unchecked conversion | 15 | instantiation 15 |
| default initial condition | 12 | component-declaration 6, object-declaration 6 |
| pointer dereference check | 9 | in aspect dynamic_predicate 9 |
| invariant check | 9 | call-statement 4, subprogram-declaration 4, type-declaration 1 |
| initialization check | 5 | argument 5 |
| assertion | 5 | condition 4, in pragma postcondition 1 |
| contract or exit cases | 4 | in aspect contract_cases 4 |
| Container_Aggregates annotation | 4 | in aspect annotate 4 |
| accessibility check | 2 | expression-function 2 |
| length check | 1 | conditional-expression 1 |

Produced by `benchmarks/gnatprove_gap_contexts.py` from the ledger's rows.
It has 1,586 of the 1,588 checks without an obligation: the script leaves
out a check whose source file it does not find under the corpus roots it is
given. The construct is read from the syntax alone, from the inside out. What is
left under a `Global` aspect is the initialization of state abstractions
and of globals in sources outside the analyzed project; under a subprogram
declaration, the termination and contract checks of the SPARK library
units, which the lanes do not analyze.

## sparknacl

GNATprove reports 2454 checks (2463 messages, a check of a generic unit being repeated for each instance): 2446 proved, 0 justified by the corpus, 8 not proved. AdaLang raises 10457 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1488 | 60.8% |
| unproved | 834 | 34.1% |
| no obligation here | 110 | 4.5% |
| no such obligation kind | 14 | 0.6% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 585 | 352 | 146 | 0 | 87 | 0 |
| initialization of | 356 | 297 | 57 | 0 | 2 | 0 |
| data dependencies | 198 | 198 | 0 | 0 | 0 | 0 |
| assertion | 187 | 31 | 156 | 0 | 0 | 0 |
| overflow check | 155 | 87 | 52 | 0 | 16 | 0 |
| division check | 153 | 153 | 0 | 0 | 0 | 0 |
| index check | 142 | 125 | 17 | 0 | 0 | 0 |
| precondition | 123 | 75 | 48 | 0 | 0 | 0 |
| initialization check | 105 | 29 | 74 | 0 | 2 | 0 |
| Always_Terminates | 103 | 79 | 24 | 0 | 0 | 0 |
| loop invariant initialization | 81 | 0 | 81 | 0 | 0 | 0 |
| loop invariant preservation | 79 | 1 | 78 | 0 | 0 | 0 |
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
| same kind within 3 lines | 56 |
| another kind on this line | 42 |
| nothing on this line | 7 |
| fewer obligations of this kind on the line | 5 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the invariant is not at the loop-head cut point | 152 |
| unproved | incoming paths disagree or object is external | 101 |
| unproved | this expression form is outside the scalar VC subset | 83 |
| unproved | this call form cannot be inlined safely | 70 |
| unproved | the current range domain does not certify the result | 49 |
| unproved | the blocking object is not known to be initialized | 48 |
| unproved | the expression conflicts with its symbolic scalar sort | 42 |
| unproved | this quantified-expression form is not modeled | 42 |
| unproved | the scalar VC portfolio did not certify the predicate | 36 |
| unproved | some path to the exit does not assign the whole parameter | 30 |
| unproved | current contract transfer does not certify safety | 26 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 25 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 81 | 5 | 76 | 0 |
| division-by-zero | 39 | 21 | 18 | 0 |
| index-check | 953 | 948 | 5 | 0 |
| initialization-check | 2720 | 2495 | 225 | 0 |
| integer-overflow | 1423 | 817 | 606 | 0 |
| postcondition | 1 | 0 | 1 | 0 |
| precondition | 119 | 75 | 44 | 0 |
| range-check | 1835 | 1475 | 360 | 0 |

## saatana

GNATprove reports 367 checks (376 messages, a check of a generic unit being repeated for each instance): 367 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 1659 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 213 | 58.0% |
| unproved | 149 | 40.6% |
| no obligation here | 5 | 1.4% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 103 | 59 | 41 | 0 | 3 | 0 |
| division check | 44 | 42 | 2 | 0 | 0 | 0 |
| overflow check | 31 | 11 | 20 | 0 | 0 | 0 |
| index check | 29 | 15 | 12 | 0 | 2 | 0 |
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
| same kind within 3 lines | 3 |
| another kind on this line | 2 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | this expression form is outside the scalar VC subset | 26 |
| unproved | the invariant is not at the loop-head cut point | 18 |
| unproved | the current range domain does not certify the result | 16 |
| unproved | slice bound and array bound ranges remain inconclusive | 13 |
| unproved | the current non-relational range domain is inconclusive | 12 |
| unproved | current contract transfer does not certify safety | 8 |
| unproved | the required bounds are not statically known | 8 |
| unproved | the slice range is not written as two bounds | 7 |
| unproved | static evaluation is inconclusive | 6 |
| unproved | this call form cannot be inlined safely | 5 |
| unproved | the callee is not a plain expression function | 5 |
| unproved | index and bound ranges remain inconclusive | 5 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 9 | 0 | 9 | 0 |
| division-by-zero | 15 | 14 | 1 | 0 |
| index-check | 166 | 151 | 15 | 0 |
| initialization-check | 573 | 492 | 81 | 0 |
| integer-overflow | 214 | 145 | 69 | 0 |
| length-check | 2 | 0 | 2 | 0 |
| precondition | 73 | 4 | 69 | 0 |
| range-check | 206 | 99 | 107 | 0 |

## libkeccak

GNATprove reports 3321 checks (20673 messages, a check of a generic unit being repeated for each instance): 3321 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 12599 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 2033 | 61.2% |
| unproved | 912 | 27.5% |
| unsupported | 2 | 0.1% |
| no obligation here | 307 | 9.2% |
| no such obligation kind | 67 | 2.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 631 | 405 | 137 | 0 | 89 | 0 |
| overflow check | 569 | 383 | 181 | 0 | 5 | 0 |
| initialization of | 344 | 190 | 73 | 0 | 81 | 0 |
| division check | 306 | 280 | 26 | 0 | 0 | 0 |
| precondition | 273 | 75 | 81 | 1 | 116 | 0 |
| index check | 199 | 113 | 71 | 0 | 15 | 0 |
| data dependencies | 155 | 150 | 5 | 0 | 0 | 0 |
| predicate check | 154 | 73 | 80 | 0 | 1 | 0 |
| loop invariant initialization | 114 | 77 | 37 | 0 | 0 | 0 |
| loop invariant preservation | 114 | 40 | 74 | 0 | 0 | 0 |
| assertion | 90 | 29 | 61 | 0 | 0 | 0 |
| flow dependencies | 81 | 81 | 0 | 0 | 0 | 0 |
| postcondition | 79 | 26 | 52 | 1 | 0 | 0 |
| length check | 74 | 64 | 10 | 0 | 0 | 0 |
| Always_Terminates | 46 | 45 | 1 | 0 | 0 | 0 |
| non-aliasing | 37 | 0 | 0 | 0 | 37 | 0 |
| contract case | 28 | 0 | 0 | 0 | 28 | 0 |
| loop variant | 21 | 0 | 21 | 0 | 0 | 0 |
| initialization check | 4 | 2 | 2 | 0 | 0 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 169 |
| same kind within 3 lines | 103 |
| nothing on this line | 29 |
| fewer obligations of this kind on the line | 6 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the current range domain does not certify the result | 177 |
| unproved | the scalar VC portfolio did not certify the predicate | 80 |
| unproved | current contract transfer does not certify safety | 74 |
| unproved | the scalar loop preservation VC was not discharged | 68 |
| unproved | slice bound and array bound ranges remain inconclusive | 64 |
| unproved | incoming paths disagree or object is external | 59 |
| unproved | the required bounds are not statically known | 58 |
| unproved | the current non-relational range domain is inconclusive | 43 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 40 |
| unproved | exit states do not imply the contract | 39 |
| unproved | the scalar loop initialization VC was not discharged | 31 |
| unproved | this call form cannot be inlined safely | 26 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 141 | 30 | 111 | 0 |
| data-dependencies | 36 | 15 | 21 | 0 |
| division-by-zero | 399 | 372 | 27 | 0 |
| flow-dependencies | 8 | 3 | 5 | 0 |
| index-check | 685 | 658 | 27 | 0 |
| initialization-check | 4702 | 4000 | 698 | 4 |
| integer-overflow | 1026 | 744 | 282 | 0 |
| length-check | 20 | 20 | 0 | 0 |
| loop-invariant-initialization | 17 | 6 | 11 | 0 |
| loop-invariant-preservation | 17 | 1 | 16 | 0 |
| loop-variant | 2 | 0 | 2 | 0 |
| postcondition | 3 | 0 | 3 | 0 |
| precondition | 195 | 79 | 115 | 1 |
| range-check | 1671 | 586 | 1085 | 0 |
| termination | 4 | 3 | 1 | 0 |

## coap_spark

GNATprove reports 6809 checks (7423 messages, a check of a generic unit being repeated for each instance): 6795 proved, 0 justified by the corpus, 14 not proved. AdaLang raises 22951 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 4069 | 59.9% |
| unproved | 1809 | 26.6% |
| unsupported | 26 | 0.4% |
| unreachable | 1 | 0.0% |
| no obligation here | 442 | 6.5% |
| no such obligation kind | 241 | 3.5% |
| file without any obligation | 207 | 3.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| precondition | 2294 | 1595 | 544 | 12 | 143 | 0 |
| Always_Terminates | 869 | 723 | 79 | 0 | 67 | 0 |
| range check | 845 | 325 | 360 | 2 | 158 | 0 |
| postcondition | 379 | 142 | 213 | 0 | 24 | 0 |
| pointer dereference check | 336 | 302 | 23 | 2 | 9 | 0 |
| assertion | 299 | 212 | 79 | 3 | 4 | 0 |
| overflow check | 278 | 127 | 135 | 0 | 16 | 0 |
| initialization of | 277 | 226 | 42 | 7 | 2 | 0 |
| division check | 265 | 252 | 13 | 0 | 0 | 0 |
| resource or memory leak | 211 | 0 | 0 | 0 | 211 | 0 |
| predicate check | 181 | 0 | 136 | 0 | 45 | 0 |
| discriminant check | 135 | 0 | 0 | 0 | 135 | 0 |
| length check | 108 | 92 | 13 | 0 | 3 | 0 |
| index check | 96 | 28 | 67 | 0 | 1 | 0 |
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
| another kind on this line | 231 |
| same kind within 3 lines | 135 |
| nothing on this line | 68 |
| fewer obligations of this kind on the line | 8 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | current contract transfer does not certify safety | 497 |
| unproved | the required bounds are not statically known | 227 |
| unproved | this attribute is outside the scalar VC subset | 117 |
| unproved | the scalar VC portfolio did not certify the predicate | 101 |
| unproved | exit states do not imply the contract | 97 |
| unproved | slice bound and array bound ranges remain inconclusive | 92 |
| unproved | the current non-relational range domain is inconclusive | 76 |
| unproved | this expression form is outside the scalar VC subset | 75 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 56 |
| unproved | this call form cannot be inlined safely | 49 |
| unproved | incoming paths disagree or object is external | 46 |
| unproved | the current range domain does not certify the result | 40 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 58 | 6 | 52 | 0 |
| division-by-zero | 13 | 5 | 8 | 0 |
| flow-dependencies | 3 | 3 | 0 | 0 |
| index-check | 841 | 5 | 836 | 0 |
| initialization-check | 10904 | 10238 | 649 | 17 |
| integer-overflow | 985 | 390 | 595 | 0 |
| length-check | 5 | 5 | 0 | 0 |
| pointer-dereference | 75 | 48 | 27 | 0 |
| postcondition | 23 | 2 | 21 | 0 |
| precondition | 2314 | 1706 | 596 | 12 |
| predicate-check | 32 | 0 | 32 | 0 |
| range-check | 1165 | 381 | 758 | 25 |
| termination | 48 | 13 | 35 | 0 |

GNATprove messages not counted as checks: function contract feasibility proved (Z3: 1 VC in max 0.0 se (2); function contract feasibility proved (CVC5: 1 VC in max 0.0  (2).

## tokeneer

GNATprove reports 2127 checks (2205 messages, a check of a generic unit being repeated for each instance): 2114 proved, 13 justified by the corpus, 0 not proved. AdaLang raises 9038 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1426 | 67.5% |
| unproved | 493 | 23.3% |
| no obligation here | 165 | 7.8% |
| no such obligation kind | 28 | 1.3% |
| file without any obligation | 2 | 0.1% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initialization of | 708 | 495 | 183 | 0 | 30 | 0 |
| data dependencies | 281 | 265 | 16 | 0 | 0 | 0 |
| flow dependencies | 233 | 210 | 0 | 0 | 23 | 0 |
| precondition | 226 | 160 | 57 | 0 | 9 | 0 |
| range check | 208 | 40 | 65 | 0 | 103 | 0 |
| Always_Terminates | 141 | 133 | 8 | 0 | 0 | 0 |
| postcondition | 57 | 2 | 55 | 0 | 0 | 0 |
| index check | 56 | 39 | 17 | 0 | 0 | 0 |
| length check | 42 | 17 | 25 | 0 | 0 | 0 |
| division check | 41 | 41 | 0 | 0 | 0 | 0 |
| overflow check | 29 | 21 | 7 | 0 | 1 | 0 |
| predicate check | 23 | 0 | 23 | 0 | 0 | 0 |
| refined post | 19 | 0 | 0 | 0 | 19 | 0 |
| loop invariant initialization | 19 | 1 | 18 | 0 | 0 | 0 |
| loop invariant preservation | 19 | 2 | 17 | 0 | 0 | 0 |
| invariant check | 9 | 0 | 0 | 0 | 9 | 0 |
| assertion | 3 | 0 | 2 | 0 | 1 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| same kind within 3 lines | 69 |
| nothing on this line | 48 |
| another kind on this line | 44 |
| fewer obligations of this kind on the line | 4 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | some path to the exit does not assign the whole object, or it is a state abstraction | 116 |
| unproved | the blocking object is not known to be initialized | 74 |
| unproved | incoming paths disagree or object is external | 45 |
| unproved | current contract transfer does not certify safety | 29 |
| unproved | some path to the exit does not assign the whole parameter | 22 |
| unproved | this call form cannot be inlined safely | 22 |
| unproved | slice bound and array bound ranges remain inconclusive | 22 |
| unproved | a record formal requires a plain object-reference actual | 21 |
| unproved | this expression form is outside the scalar VC subset | 20 |
| unproved | the two lengths are not known to be equal | 18 |
| unproved | State is used and is not listed | 16 |
| unproved | the required bounds are not statically known | 12 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 19 | 1 | 18 | 0 |
| division-by-zero | 10 | 8 | 2 | 0 |
| index-check | 270 | 99 | 161 | 10 |
| initialization-check | 3571 | 2419 | 1112 | 40 |
| integer-overflow | 230 | 106 | 122 | 2 |
| length-check | 56 | 16 | 40 | 0 |
| postcondition | 4 | 2 | 2 | 0 |
| precondition | 400 | 195 | 205 | 0 |
| predicate-check | 10 | 0 | 10 | 0 |
| range-check | 1892 | 407 | 1477 | 8 |

