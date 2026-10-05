# What separates `--verify` from GNATprove: a ledger

Recorded 2026-10-05 with AdaLang Analyzer 1.8.0 plus the `FP-104` fix
(obligations reported in the file they are written in), against the GNATprove
output saved by the 2026-10-02 runs of the five fully proved corpora
(`sparknacl`, `saatana`, `libkeccak`, `coap_spark`, `tokeneer`).

The per-corpus comparisons (`<corpus>/RESULTS_2026-10-02.md`) answer one
question: where both tools have exactly one obligation of a kind on a line,
do they ever disagree? This ledger asks the other one: of everything
GNATprove proves, how much does AdaLang prove, and what happens to the rest?
Every check GNATprove reports is a row; none is left out for being hard to
pair.

How to read it:

- A **check** is a GNATprove message about one thing it verified at one
  place. A check of a generic unit, which GNATprove repeats for every
  instance, counts once and is proved when every instance is.
- AdaLang's side of a check is the obligation of the corresponding kind on
  the same line, the one at the same column if there is one.
  - **proved-safe**, **unproved**, **unsupported**: AdaLang has that
    obligation, with that verdict.
  - **no obligation here**: AdaLang knows the kind of check but raises none
    at this place. The tables say what it has instead: the same kind a few
    lines away (the two tools place the check differently), another kind on
    the line, or nothing.
  - **no such obligation kind**: AdaLang has no obligation of this kind at
    all (termination, data dependencies, predicate and length checks, ...).
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
| proved-safe | 467 | 3.1% |
| unproved | 4657 | 31.0% |
| unsupported | 1779 | 11.8% |
| no obligation here | 4233 | 28.1% |
| no such obligation kind | 3219 | 21.4% |
| file without any obligation | 688 | 4.6% |

| Corpus | Proved by GNATprove | AdaLang proved | Unproved | Unsupported | No obligation here | No such kind | File without obligations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2446 | 116 | 747 | 437 | 700 | 421 | 25 |
| saatana | 367 | 10 | 44 | 155 | 89 | 69 | 0 |
| libkeccak | 3321 | 270 | 1305 | 280 | 877 | 558 | 31 |
| coap_spark | 6795 | 20 | 2126 | 907 | 1796 | 1631 | 315 |
| tokeneer | 2114 | 51 | 435 | 0 | 771 | 540 | 317 |

Disagreements: 0 checks AdaLang proved that GNATprove did not, 0 definite errors on checks GNATprove proved.

## Where the missing obligations are

8138 checks GNATprove proved have no AdaLang obligation at their place. By the construct they are in:

| Construct | Checks |
| --- | ---: |
| object-declaration | 1098 |
| in aspect global | 908 |
| subprogram-declaration | 797 |
| argument | 668 |
| slice | 659 |
| expression-function | 592 |
| in aspect post | 464 |
| parameter-declaration | 410 |
| in aspect pre | 386 |
| in aspect depends | 332 |
| subprogram-body | 288 |
| assignment-value | 200 |
| assignment-target | 186 |
| condition | 147 |
| in pragma loop_invariant | 118 |
| call-statement | 113 |
| conditional-expression | 108 |
| in aspect refined_global | 104 |
| attribute prefix or argument | 99 |
| in pragma assert | 90 |
| in aspect contract_cases | 61 |
| aggregate | 57 |
| loop-range | 39 |
| component-declaration | 33 |
| in aspect refined_post | 30 |

By GNATprove check, with the constructs it is most often in:

| GNATprove check | Checks | Where |
| --- | ---: | --- |
| initialization of | 1693 | object-declaration 945, parameter-declaration 410, in aspect global 212, in aspect refined_global 104, in aspect abstract_state 20 |
| range check | 1325 | argument 287, slice 279, in aspect pre 168, in pragma loop_invariant 114, object-declaration 78 |
| Always_Terminates | 1169 | subprogram-declaration 771, expression-function 331, subprogram-body 67 |
| precondition | 862 | in aspect post 180, expression-function 170, in aspect pre 145, call-statement 109, conditional-expression 74 |
| data dependencies | 696 | in aspect global 696 |
| predicate check | 421 | assignment-target 173, argument 131, assignment-value 50, slice 33, type-declaration 8 |
| flow dependencies | 357 | in aspect depends 332, in aspect initializes 25 |
| pointer dereference check | 336 | attribute prefix or argument 94, slice 65, in aspect pre 63, in aspect post 63, argument 20 |
| length check | 309 | condition 80, subprogram-body 78, slice 72, assignment-value 49, object-declaration 18 |
| index check | 241 | slice 194, argument 22, aggregate 15, in aspect post 6, in aspect pre 2 |
| resource or memory leak | 211 | subprogram-body 98, argument 51, object-declaration 45, condition 17 |
| postcondition | 139 | in aspect post 139 |
| discriminant check | 135 | subprogram-body 45, argument 41, condition 25, assignment-target 12, assignment-value 6 |
| overflow check | 89 | argument 37, conditional-expression 16, in aspect post 12, expression-function 7, assignment-value 6 |
| non-aliasing | 44 | argument 38, slice 6 |
| contract case | 36 | in aspect contract_cases 36 |
| refined post | 19 | in aspect refined_post 19 |
| unchecked conversion | 15 | instantiation 15 |
| default initial condition | 12 | component-declaration 6, object-declaration 6 |
| invariant check | 9 | call-statement 4, subprogram-declaration 4, type-declaration 1 |
| initialization check | 5 | argument 5 |
| assertion | 5 | condition 4, in pragma postcondition 1 |
| contract or exit cases | 4 | in aspect contract_cases 4 |
| Container_Aggregates annotation | 4 | in aspect annotate 4 |
| accessibility check | 2 | expression-function 2 |

Produced by `benchmarks/gnatprove_gap_contexts.py` from the ledger's rows.
The construct is read from the syntax alone, from the inside out, so
"object-declaration" covers both a check in an initial value and GNATprove's
"initialization of X proved", which it places on the declaration of X while
AdaLang raises an initialization check at each read.

## sparknacl

GNATprove reports 2454 checks (2463 messages, a check of a generic unit being repeated for each instance): 2446 proved, 0 justified by the corpus, 8 not proved. AdaLang raises 9482 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 116 | 4.7% |
| unproved | 747 | 30.5% |
| unsupported | 437 | 17.9% |
| no obligation here | 700 | 28.6% |
| no such obligation kind | 421 | 17.2% |
| file without any obligation | 25 | 1.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 585 | 41 | 188 | 75 | 281 | 0 |
| initialization of | 356 | 0 | 0 | 0 | 356 | 0 |
| data dependencies | 198 | 0 | 0 | 0 | 198 | 0 |
| assertion | 187 | 9 | 100 | 78 | 0 | 0 |
| overflow check | 155 | 0 | 123 | 12 | 20 | 0 |
| division check | 153 | 29 | 106 | 18 | 0 | 0 |
| index check | 142 | 16 | 10 | 70 | 46 | 0 |
| precondition | 123 | 7 | 103 | 13 | 0 | 0 |
| initialization check | 105 | 14 | 33 | 56 | 2 | 0 |
| Always_Terminates | 103 | 0 | 0 | 0 | 103 | 0 |
| loop invariant initialization | 81 | 0 | 26 | 55 | 0 | 0 |
| loop invariant preservation | 79 | 0 | 26 | 53 | 0 | 0 |
| length check | 67 | 0 | 0 | 0 | 67 | 0 |
| predicate check | 58 | 0 | 0 | 0 | 58 | 0 |
| postcondition | 29 | 0 | 22 | 7 | 0 | 0 |
| loop variant | 10 | 0 | 10 | 0 | 0 | 0 |
| unchecked conversion | 6 | 0 | 0 | 0 | 6 | 0 |
| contract case | 6 | 0 | 0 | 0 | 6 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |
| flow dependencies | 1 | 0 | 0 | 0 | 1 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| same kind within 3 lines | 283 |
| nothing on this line | 213 |
| another kind on this line | 200 |
| fewer obligations of this kind on the line | 4 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unsupported | outside bounded verification subset | 437 |
| unproved | the blocking object is not known to be initialized | 145 |
| unproved | the required bounds are not statically known | 106 |
| unproved | this call form cannot be inlined safely | 83 |
| unproved | current contract transfer does not certify safety | 81 |
| unproved | this expression form is outside the scalar VC subset | 74 |
| unproved | the current non-relational range domain is inconclusive | 48 |
| unproved | the invariant is not at the loop-head cut point | 44 |
| unproved | the expression conflicts with its symbolic scalar sort | 40 |
| unproved | incoming paths disagree or object is external | 33 |
| unproved | the callee is not a plain expression function | 25 |
| unproved | the current range domain does not certify the result | 13 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 81 | 1 | 25 | 55 |
| division-by-zero | 39 | 13 | 21 | 5 |
| index-check | 920 | 605 | 52 | 263 |
| initialization-check | 3881 | 2952 | 538 | 391 |
| integer-overflow | 1410 | 223 | 940 | 247 |
| precondition | 107 | 7 | 87 | 13 |
| range-check | 1740 | 668 | 975 | 97 |

## saatana

GNATprove reports 367 checks (376 messages, a check of a generic unit being repeated for each instance): 367 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 1349 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 10 | 2.7% |
| unproved | 44 | 12.0% |
| unsupported | 155 | 42.2% |
| no obligation here | 89 | 24.3% |
| no such obligation kind | 69 | 18.8% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 103 | 4 | 2 | 55 | 42 | 0 |
| division check | 44 | 6 | 16 | 22 | 0 | 0 |
| overflow check | 31 | 0 | 6 | 18 | 7 | 0 |
| index check | 29 | 0 | 0 | 9 | 20 | 0 |
| precondition | 22 | 0 | 8 | 14 | 0 | 0 |
| length check | 20 | 0 | 0 | 0 | 20 | 0 |
| data dependencies | 20 | 0 | 0 | 0 | 20 | 0 |
| initialization of | 18 | 0 | 0 | 0 | 18 | 0 |
| flow dependencies | 14 | 0 | 0 | 0 | 14 | 0 |
| postcondition | 13 | 0 | 4 | 7 | 2 | 0 |
| assertion | 10 | 0 | 8 | 2 | 0 | 0 |
| Always_Terminates | 10 | 0 | 0 | 0 | 10 | 0 |
| loop invariant initialization | 9 | 0 | 0 | 9 | 0 | 0 |
| loop invariant preservation | 9 | 0 | 0 | 9 | 0 | 0 |
| initialization check | 6 | 0 | 0 | 6 | 0 | 0 |
| predicate check | 5 | 0 | 0 | 0 | 5 | 0 |
| loop variant | 4 | 0 | 0 | 4 | 0 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| nothing on this line | 37 |
| another kind on this line | 27 |
| same kind within 3 lines | 20 |
| fewer obligations of this kind on the line | 5 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unsupported | outside bounded verification subset | 155 |
| unproved | static evaluation does not determine a nonzero operand | 16 |
| unproved | this expression form is outside the scalar VC subset | 12 |
| unproved | static evaluation is inconclusive | 6 |
| unproved | the required bounds are not statically known | 6 |
| unproved | the expression conflicts with its symbolic scalar sort | 3 |
| unproved | this attribute is outside the scalar VC subset | 1 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 9 | 0 | 0 | 9 |
| division-by-zero | 15 | 6 | 1 | 8 |
| index-check | 161 | 92 | 4 | 65 |
| initialization-check | 539 | 158 | 26 | 355 |
| integer-overflow | 187 | 40 | 19 | 128 |
| precondition | 72 | 0 | 16 | 56 |
| range-check | 157 | 13 | 28 | 116 |

## libkeccak

GNATprove reports 3321 checks (20673 messages, a check of a generic unit being repeated for each instance): 3321 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 11058 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 270 | 8.1% |
| unproved | 1305 | 39.3% |
| unsupported | 280 | 8.4% |
| no obligation here | 877 | 26.4% |
| no such obligation kind | 558 | 16.8% |
| file without any obligation | 31 | 0.9% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 631 | 26 | 212 | 42 | 351 | 0 |
| overflow check | 569 | 35 | 433 | 94 | 7 | 0 |
| initialization of | 344 | 2 | 8 | 0 | 334 | 0 |
| division check | 306 | 176 | 93 | 37 | 0 | 0 |
| precondition | 273 | 1 | 151 | 1 | 120 | 0 |
| index check | 199 | 11 | 93 | 22 | 73 | 0 |
| data dependencies | 155 | 0 | 0 | 0 | 155 | 0 |
| predicate check | 154 | 0 | 0 | 0 | 154 | 0 |
| loop invariant initialization | 114 | 10 | 67 | 37 | 0 | 0 |
| loop invariant preservation | 114 | 2 | 75 | 37 | 0 | 0 |
| assertion | 90 | 3 | 86 | 1 | 0 | 0 |
| flow dependencies | 81 | 0 | 0 | 0 | 81 | 0 |
| postcondition | 79 | 2 | 72 | 1 | 4 | 0 |
| length check | 74 | 0 | 0 | 0 | 74 | 0 |
| Always_Terminates | 46 | 0 | 0 | 0 | 46 | 0 |
| non-aliasing | 37 | 0 | 0 | 0 | 37 | 0 |
| contract case | 28 | 0 | 0 | 0 | 28 | 0 |
| loop variant | 21 | 0 | 13 | 8 | 0 | 0 |
| initialization check | 4 | 2 | 2 | 0 | 0 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 332 |
| nothing on this line | 288 |
| same kind within 3 lines | 251 |
| fewer obligations of this kind on the line | 6 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the blocking object is not known to be initialized | 429 |
| unsupported | outside bounded verification subset | 280 |
| unproved | the current range domain does not certify the result | 248 |
| unproved | this expression form is outside the scalar VC subset | 179 |
| unproved | the required bounds are not statically known | 106 |
| unproved | the current non-relational range domain is inconclusive | 82 |
| unproved | the scalar loop preservation VC was not discharged | 55 |
| unproved | static evaluation does not determine a nonzero operand | 30 |
| unproved | this call form cannot be inlined safely | 26 |
| unproved | abstract interpretation and the scalar VC portfolio did not certify it | 23 |
| unproved | Ada division semantics require a provably nonzero divisor | 23 |
| unproved | the divisor range is unknown or contains zero | 19 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 141 | 1 | 87 | 53 |
| division-by-zero | 399 | 90 | 243 | 66 |
| index-check | 677 | 514 | 73 | 90 |
| initialization-check | 5278 | 2212 | 2591 | 475 |
| integer-overflow | 1004 | 62 | 762 | 180 |
| loop-invariant-initialization | 17 | 1 | 2 | 14 |
| loop-invariant-preservation | 17 | 1 | 2 | 14 |
| loop-variant | 2 | 0 | 2 | 0 |
| postcondition | 3 | 0 | 3 | 0 |
| precondition | 191 | 1 | 183 | 7 |
| range-check | 1474 | 178 | 1115 | 181 |

## coap_spark

GNATprove reports 6809 checks (7423 messages, a check of a generic unit being repeated for each instance): 6795 proved, 0 justified by the corpus, 14 not proved. AdaLang raises 13251 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 20 | 0.3% |
| unproved | 2126 | 31.3% |
| unsupported | 907 | 13.3% |
| no obligation here | 1796 | 26.4% |
| no such obligation kind | 1631 | 24.0% |
| file without any obligation | 315 | 4.6% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| precondition | 2294 | 0 | 1148 | 413 | 733 | 0 |
| Always_Terminates | 869 | 0 | 0 | 0 | 869 | 0 |
| range check | 845 | 12 | 176 | 128 | 529 | 0 |
| postcondition | 379 | 0 | 177 | 69 | 133 | 0 |
| pointer dereference check | 336 | 0 | 0 | 0 | 336 | 0 |
| assertion | 299 | 0 | 104 | 191 | 4 | 0 |
| overflow check | 278 | 2 | 178 | 44 | 54 | 0 |
| initialization of | 277 | 0 | 0 | 0 | 277 | 0 |
| division check | 265 | 1 | 247 | 17 | 0 | 0 |
| resource or memory leak | 211 | 0 | 0 | 0 | 211 | 0 |
| predicate check | 181 | 0 | 0 | 0 | 181 | 0 |
| discriminant check | 135 | 0 | 0 | 0 | 135 | 0 |
| length check | 108 | 0 | 0 | 0 | 108 | 0 |
| index check | 96 | 5 | 25 | 3 | 63 | 0 |
| loop invariant preservation | 47 | 0 | 26 | 21 | 0 | 0 |
| loop invariant initialization | 47 | 0 | 26 | 21 | 0 | 0 |
| data dependencies | 42 | 0 | 0 | 0 | 42 | 0 |
| flow dependencies | 28 | 0 | 0 | 0 | 28 | 0 |
| initialization check | 21 | 0 | 18 | 0 | 3 | 0 |
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
| nothing on this line | 911 |
| same kind within 3 lines | 448 |
| another kind on this line | 430 |
| fewer obligations of this kind on the line | 7 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | this expression form is outside the scalar VC subset | 1193 |
| unsupported | outside bounded verification subset | 907 |
| unproved | this attribute is outside the scalar VC subset | 265 |
| unproved | the blocking object is not known to be initialized | 156 |
| unproved | static evaluation does not determine a nonzero operand | 113 |
| unproved | the required bounds are not statically known | 88 |
| unproved | the callee is not a plain expression function | 70 |
| unproved | the expression conflicts with its symbolic scalar sort | 62 |
| unproved | the current range domain does not certify the result | 49 |
| unproved | the current non-relational range domain is inconclusive | 42 |
| unproved | the invariant is not at the loop-head cut point | 20 |
| unproved | this operator is outside the scalar VC subset | 19 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 58 | 0 | 26 | 32 |
| division-by-zero | 13 | 0 | 9 | 4 |
| index-check | 171 | 5 | 95 | 71 |
| initialization-check | 7458 | 3782 | 2089 | 1587 |
| integer-overflow | 634 | 6 | 483 | 145 |
| postcondition | 23 | 0 | 10 | 13 |
| precondition | 890 | 0 | 451 | 439 |
| range-check | 939 | 44 | 392 | 503 |

GNATprove messages not counted as checks: function contract feasibility proved (Z3: 1 VC in max 0.0 se (2); function contract feasibility proved (CVC5: 1 VC in max 0.0  (2).

## tokeneer

GNATprove reports 2127 checks (2205 messages, a check of a generic unit being repeated for each instance): 2114 proved, 13 justified by the corpus, 0 not proved. AdaLang raises 7115 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 51 | 2.4% |
| unproved | 435 | 20.6% |
| no obligation here | 771 | 36.5% |
| no such obligation kind | 540 | 25.5% |
| file without any obligation | 317 | 15.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initialization of | 708 | 0 | 0 | 0 | 708 | 0 |
| data dependencies | 281 | 0 | 0 | 0 | 281 | 0 |
| flow dependencies | 233 | 0 | 0 | 0 | 233 | 0 |
| precondition | 226 | 9 | 208 | 0 | 9 | 0 |
| range check | 208 | 5 | 81 | 0 | 122 | 0 |
| Always_Terminates | 141 | 0 | 0 | 0 | 141 | 0 |
| postcondition | 57 | 1 | 56 | 0 | 0 | 0 |
| index check | 56 | 3 | 14 | 0 | 39 | 0 |
| length check | 42 | 0 | 0 | 0 | 42 | 0 |
| division check | 41 | 24 | 17 | 0 | 0 | 0 |
| overflow check | 29 | 7 | 21 | 0 | 1 | 0 |
| predicate check | 23 | 0 | 0 | 0 | 23 | 0 |
| refined post | 19 | 0 | 0 | 0 | 19 | 0 |
| loop invariant initialization | 19 | 1 | 18 | 0 | 0 | 0 |
| loop invariant preservation | 19 | 1 | 18 | 0 | 0 | 0 |
| invariant check | 9 | 0 | 0 | 0 | 9 | 0 |
| assertion | 3 | 0 | 2 | 0 | 1 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| nothing on this line | 544 |
| same kind within 3 lines | 146 |
| another kind on this line | 80 |
| fewer obligations of this kind on the line | 1 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | this expression form is outside the scalar VC subset | 130 |
| unproved | the blocking object is not known to be initialized | 108 |
| unproved | current contract transfer does not certify safety | 91 |
| unproved | this call form cannot be inlined safely | 16 |
| unproved | the expression conflicts with its symbolic scalar sort | 16 |
| unproved | the scalar loop preservation VC was not discharged | 14 |
| unproved | the required bounds are not statically known | 12 |
| unproved | index and bound ranges remain inconclusive | 11 |
| unproved | the current range domain does not certify the result | 10 |
| unproved | the callee is not a plain expression function | 9 |
| unproved | the current non-relational range domain is inconclusive | 5 |
| unproved | this attribute is outside the scalar VC subset | 2 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 19 | 0 | 19 | 0 |
| division-by-zero | 10 | 8 | 2 | 0 |
| index-check | 240 | 36 | 184 | 20 |
| initialization-check | 4053 | 1743 | 2138 | 172 |
| integer-overflow | 221 | 26 | 178 | 17 |
| postcondition | 4 | 0 | 4 | 0 |
| precondition | 337 | 11 | 316 | 10 |
| range-check | 1744 | 248 | 1382 | 114 |

