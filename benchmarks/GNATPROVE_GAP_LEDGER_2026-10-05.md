# What separates `--verify` from GNATprove: a ledger

Recorded 2026-10-05 with AdaLang Analyzer 1.8.0, against the GNATprove
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
| proved-safe | 433 | 2.9% |
| unproved | 3796 | 25.2% |
| unsupported | 1725 | 11.5% |
| no obligation here | 4834 | 32.1% |
| no such obligation kind | 2823 | 18.8% |
| file without any obligation | 1432 | 9.5% |

| Corpus | Proved by GNATprove | AdaLang proved | Unproved | Unsupported | No obligation here | No such kind | File without obligations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2446 | 110 | 715 | 434 | 643 | 335 | 209 |
| saatana | 367 | 1 | 48 | 149 | 100 | 69 | 0 |
| libkeccak | 3321 | 231 | 1235 | 279 | 980 | 548 | 48 |
| coap_spark | 6795 | 39 | 1408 | 863 | 2374 | 1508 | 603 |
| tokeneer | 2114 | 52 | 390 | 0 | 737 | 363 | 572 |

Disagreements: 0 checks AdaLang proved that GNATprove did not, 0 definite errors on checks GNATprove proved.

## sparknacl

GNATprove reports 2454 checks (2463 messages, a check of a generic unit being repeated for each instance): 2446 proved, 0 justified by the corpus, 8 not proved. AdaLang raises 9484 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 110 | 4.5% |
| unproved | 715 | 29.2% |
| unsupported | 434 | 17.7% |
| no obligation here | 643 | 26.3% |
| no such obligation kind | 335 | 13.7% |
| file without any obligation | 209 | 8.5% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 585 | 36 | 182 | 75 | 292 | 0 |
| initialization of | 356 | 0 | 0 | 0 | 356 | 0 |
| data dependencies | 198 | 0 | 0 | 0 | 198 | 0 |
| assertion | 187 | 9 | 100 | 78 | 0 | 0 |
| overflow check | 155 | 0 | 122 | 12 | 21 | 0 |
| division check | 153 | 28 | 107 | 18 | 0 | 0 |
| index check | 142 | 16 | 10 | 70 | 46 | 0 |
| precondition | 123 | 7 | 91 | 13 | 12 | 0 |
| initialization check | 105 | 14 | 33 | 56 | 2 | 0 |
| Always_Terminates | 103 | 0 | 0 | 0 | 103 | 0 |
| loop invariant initialization | 81 | 0 | 26 | 55 | 0 | 0 |
| loop invariant preservation | 79 | 0 | 26 | 53 | 0 | 0 |
| length check | 67 | 0 | 0 | 0 | 67 | 0 |
| predicate check | 58 | 0 | 0 | 0 | 58 | 0 |
| postcondition | 29 | 0 | 8 | 4 | 17 | 0 |
| loop variant | 10 | 0 | 10 | 0 | 0 | 0 |
| unchecked conversion | 6 | 0 | 0 | 0 | 6 | 0 |
| contract case | 6 | 0 | 0 | 0 | 6 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |
| flow dependencies | 1 | 0 | 0 | 0 | 1 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| same kind within 3 lines | 281 |
| another kind on this line | 188 |
| nothing on this line | 170 |
| fewer obligations of this kind on the line | 4 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unsupported | outside bounded verification subset | 434 |
| unproved | the blocking object is not known to be initialized | 144 |
| unproved | the required bounds are not statically known | 105 |
| unproved | this call form cannot be inlined safely | 83 |
| unproved | this expression form is outside the scalar VC subset | 70 |
| unproved | current contract transfer does not certify safety | 69 |
| unproved | the invariant is not at the loop-head cut point | 44 |
| unproved | the current non-relational range domain is inconclusive | 42 |
| unproved | the expression conflicts with its symbolic scalar sort | 38 |
| unproved | incoming paths disagree or object is external | 33 |
| unproved | the callee is not a plain expression function | 19 |
| unproved | the current range domain does not certify the result | 13 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 81 | 1 | 25 | 55 |
| division-by-zero | 40 | 14 | 21 | 5 |
| index-check | 920 | 605 | 52 | 263 |
| initialization-check | 3882 | 2952 | 539 | 391 |
| integer-overflow | 1411 | 223 | 941 | 247 |
| postcondition | 17 | 0 | 14 | 3 |
| precondition | 119 | 7 | 99 | 13 |
| range-check | 1751 | 673 | 981 | 97 |

## saatana

GNATprove reports 367 checks (376 messages, a check of a generic unit being repeated for each instance): 367 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 1359 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1 | 0.3% |
| unproved | 48 | 13.1% |
| unsupported | 149 | 40.6% |
| no obligation here | 100 | 27.2% |
| no such obligation kind | 69 | 18.8% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 103 | 1 | 2 | 55 | 45 | 0 |
| division check | 44 | 0 | 22 | 22 | 0 | 0 |
| overflow check | 31 | 0 | 6 | 18 | 7 | 0 |
| index check | 29 | 0 | 0 | 9 | 20 | 0 |
| precondition | 22 | 0 | 8 | 14 | 0 | 0 |
| length check | 20 | 0 | 0 | 0 | 20 | 0 |
| data dependencies | 20 | 0 | 0 | 0 | 20 | 0 |
| initialization of | 18 | 0 | 0 | 0 | 18 | 0 |
| flow dependencies | 14 | 0 | 0 | 0 | 14 | 0 |
| postcondition | 13 | 0 | 2 | 1 | 10 | 0 |
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
| nothing on this line | 44 |
| another kind on this line | 29 |
| same kind within 3 lines | 22 |
| fewer obligations of this kind on the line | 5 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unsupported | outside bounded verification subset | 149 |
| unproved | static evaluation does not determine a nonzero operand | 22 |
| unproved | this expression form is outside the scalar VC subset | 10 |
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
| division-by-zero | 25 | 12 | 5 | 8 |
| index-check | 161 | 92 | 4 | 65 |
| initialization-check | 539 | 158 | 26 | 355 |
| integer-overflow | 187 | 40 | 19 | 128 |
| postcondition | 8 | 0 | 2 | 6 |
| precondition | 72 | 0 | 16 | 56 |
| range-check | 160 | 16 | 28 | 116 |

## libkeccak

GNATprove reports 3321 checks (20673 messages, a check of a generic unit being repeated for each instance): 3321 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 11172 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 231 | 7.0% |
| unproved | 1235 | 37.2% |
| unsupported | 279 | 8.4% |
| no obligation here | 980 | 29.5% |
| no such obligation kind | 548 | 16.5% |
| file without any obligation | 48 | 1.4% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 631 | 26 | 207 | 42 | 356 | 0 |
| overflow check | 569 | 34 | 388 | 94 | 53 | 0 |
| initialization of | 344 | 3 | 9 | 0 | 332 | 0 |
| division check | 306 | 137 | 132 | 37 | 0 | 0 |
| precondition | 273 | 1 | 151 | 1 | 120 | 0 |
| index check | 199 | 11 | 93 | 22 | 73 | 0 |
| data dependencies | 155 | 0 | 0 | 0 | 155 | 0 |
| predicate check | 154 | 0 | 0 | 0 | 154 | 0 |
| loop invariant initialization | 114 | 10 | 67 | 37 | 0 | 0 |
| loop invariant preservation | 114 | 2 | 75 | 37 | 0 | 0 |
| assertion | 90 | 3 | 86 | 1 | 0 | 0 |
| flow dependencies | 81 | 0 | 0 | 0 | 81 | 0 |
| postcondition | 79 | 2 | 12 | 0 | 65 | 0 |
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
| nothing on this line | 382 |
| another kind on this line | 360 |
| same kind within 3 lines | 232 |
| fewer obligations of this kind on the line | 6 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the blocking object is not known to be initialized | 412 |
| unsupported | outside bounded verification subset | 279 |
| unproved | the current range domain does not certify the result | 207 |
| unproved | this expression form is outside the scalar VC subset | 126 |
| unproved | the required bounds are not statically known | 100 |
| unproved | static evaluation does not determine a nonzero operand | 84 |
| unproved | the current non-relational range domain is inconclusive | 77 |
| unproved | the scalar loop preservation VC was not discharged | 55 |
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
| division-by-zero | 514 | 129 | 319 | 66 |
| index-check | 677 | 514 | 73 | 90 |
| initialization-check | 5275 | 2211 | 2589 | 475 |
| integer-overflow | 1050 | 63 | 807 | 180 |
| loop-invariant-initialization | 17 | 1 | 2 | 14 |
| loop-invariant-preservation | 17 | 1 | 2 | 14 |
| loop-variant | 2 | 0 | 2 | 0 |
| postcondition | 64 | 0 | 63 | 1 |
| precondition | 191 | 1 | 183 | 7 |
| range-check | 1479 | 178 | 1120 | 181 |

## coap_spark

GNATprove reports 6809 checks (7423 messages, a check of a generic unit being repeated for each instance): 6795 proved, 0 justified by the corpus, 14 not proved. AdaLang raises 13297 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 39 | 0.6% |
| unproved | 1408 | 20.7% |
| unsupported | 863 | 12.7% |
| no obligation here | 2374 | 34.9% |
| no such obligation kind | 1508 | 22.2% |
| file without any obligation | 603 | 8.9% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| precondition | 2294 | 0 | 608 | 411 | 1275 | 0 |
| Always_Terminates | 869 | 0 | 0 | 0 | 869 | 0 |
| range check | 845 | 12 | 169 | 128 | 536 | 0 |
| postcondition | 379 | 0 | 32 | 27 | 320 | 0 |
| pointer dereference check | 336 | 0 | 0 | 0 | 336 | 0 |
| assertion | 299 | 0 | 104 | 191 | 4 | 0 |
| overflow check | 278 | 0 | 151 | 44 | 83 | 0 |
| initialization of | 277 | 21 | 1 | 0 | 255 | 0 |
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
| nothing on this line | 1555 |
| another kind on this line | 448 |
| same kind within 3 lines | 363 |
| fewer obligations of this kind on the line | 8 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unsupported | outside bounded verification subset | 863 |
| unproved | this expression form is outside the scalar VC subset | 557 |
| unproved | this attribute is outside the scalar VC subset | 203 |
| unproved | static evaluation does not determine a nonzero operand | 165 |
| unproved | the blocking object is not known to be initialized | 132 |
| unproved | the required bounds are not statically known | 78 |
| unproved | the callee is not a plain expression function | 58 |
| unproved | the expression conflicts with its symbolic scalar sort | 51 |
| unproved | the current non-relational range domain is inconclusive | 42 |
| unproved | the current range domain does not certify the result | 38 |
| unproved | the invariant is not at the loop-head cut point | 20 |
| unproved | incoming paths disagree or object is external | 19 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 58 | 0 | 26 | 32 |
| division-by-zero | 66 | 0 | 62 | 4 |
| index-check | 171 | 5 | 95 | 71 |
| initialization-check | 7429 | 3755 | 2087 | 1587 |
| integer-overflow | 663 | 8 | 510 | 145 |
| postcondition | 213 | 0 | 158 | 55 |
| precondition | 1432 | 0 | 991 | 441 |
| range-check | 946 | 44 | 399 | 503 |

GNATprove messages not counted as checks: function contract feasibility proved (Z3: 1 VC in max 0.0 se (2); function contract feasibility proved (CVC5: 1 VC in max 0.0  (2).

## tokeneer

GNATprove reports 2127 checks (2205 messages, a check of a generic unit being repeated for each instance): 2114 proved, 13 justified by the corpus, 0 not proved. AdaLang raises 7118 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 52 | 2.5% |
| unproved | 390 | 18.4% |
| no obligation here | 737 | 34.9% |
| no such obligation kind | 363 | 17.2% |
| file without any obligation | 572 | 27.1% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initialization of | 708 | 1 | 0 | 0 | 707 | 0 |
| data dependencies | 281 | 0 | 0 | 0 | 281 | 0 |
| flow dependencies | 233 | 0 | 0 | 0 | 233 | 0 |
| precondition | 226 | 9 | 193 | 0 | 24 | 0 |
| range check | 208 | 5 | 81 | 0 | 122 | 0 |
| Always_Terminates | 141 | 0 | 0 | 0 | 141 | 0 |
| postcondition | 57 | 1 | 26 | 0 | 30 | 0 |
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
| nothing on this line | 507 |
| same kind within 3 lines | 148 |
| another kind on this line | 81 |
| fewer obligations of this kind on the line | 1 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the blocking object is not known to be initialized | 101 |
| unproved | this expression form is outside the scalar VC subset | 99 |
| unproved | current contract transfer does not certify safety | 91 |
| unproved | this call form cannot be inlined safely | 16 |
| unproved | the scalar loop preservation VC was not discharged | 14 |
| unproved | the required bounds are not statically known | 12 |
| unproved | the expression conflicts with its symbolic scalar sort | 11 |
| unproved | index and bound ranges remain inconclusive | 11 |
| unproved | the current range domain does not certify the result | 10 |
| unproved | the callee is not a plain expression function | 9 |
| unproved | the current non-relational range domain is inconclusive | 5 |
| unproved | exit states do not imply the contract | 2 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 19 | 0 | 19 | 0 |
| division-by-zero | 10 | 8 | 2 | 0 |
| index-check | 240 | 36 | 184 | 20 |
| initialization-check | 4055 | 1742 | 2141 | 172 |
| integer-overflow | 221 | 26 | 178 | 17 |
| postcondition | 34 | 0 | 34 | 0 |
| precondition | 352 | 11 | 331 | 10 |
| range-check | 1744 | 248 | 1382 | 114 |

