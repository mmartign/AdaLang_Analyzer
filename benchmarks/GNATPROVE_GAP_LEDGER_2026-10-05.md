# What separates `--verify` from GNATprove: a ledger

Recorded 2026-10-08 with the development tree that follows AdaLang Analyzer
1.8.2 (commit `8d4a867`), against the GNATprove output saved by the
2026-10-02 runs of the five fully proved corpora (`sparknacl`, `saatana`,
`libkeccak`, `coap_spark`, `tokeneer`).

The obligations are those of 1.8.2 but for three range checks on an actual
that is now a static value; more of them are decided. A name written with
its package in front of it is the entity it names, a named number is its
value, and `T'Size` of a static discrete subtype is a number. A loop with
a name, a `goto` to a label further down and a quantified loop invariant
no longer put a subprogram outside the subset. Two false-safes in the
checks that were there are fixed (`FP-112`, `FP-113`), a false positive
(`FP-114`) and a false-safe that no corpus exercises (`FP-115`). 1.8.2
proved 3,536 of the checks below, left 6,062 unproved and 2,324
unsupported; the rows without an obligation have not moved.

1.8.2 had added to 1.8.1 the calls: a call to a function of its arguments
is a term the provers can match, a procedure call with known effects leaves
what is known of the caller's own scalars, and a callee's postcondition is
assumed after the call; with the fixes `FP-109` to `FP-111`. 1.8.1 had
proved 3,018 of the checks.

1.8.1 had added to 1.8.0 the initialization of an `out` parameter and of
an `Output` global at its subprogram's exit, the bounds of a slice, the
range check on an actual parameter, the termination, data-dependencies and
flow-dependencies obligations, the verification of expression functions and
of the checks inside preconditions and postconditions, and the fixes
`FP-106` to `FP-108`.

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
    all (predicate, length and pointer-dereference checks, memory leaks,
    ...).
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
| proved-safe | 4299 | 28.6% |
| unproved | 6317 | 42.0% |
| unsupported | 1306 | 8.7% |
| no obligation here | 1496 | 9.9% |
| no such obligation kind | 1416 | 9.4% |
| file without any obligation | 209 | 1.4% |

| Corpus | Proved by GNATprove | AdaLang proved | Unproved | Unsupported | No obligation here | No such kind | File without obligations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2446 | 897 | 1132 | 120 | 158 | 139 | 0 |
| saatana | 367 | 115 | 201 | 0 | 26 | 25 | 0 |
| libkeccak | 3321 | 679 | 1857 | 2 | 488 | 295 | 0 |
| coap_spark | 6795 | 1795 | 2127 | 1182 | 620 | 864 | 207 |
| tokeneer | 2114 | 813 | 1000 | 2 | 204 | 93 | 2 |

Disagreements: 0 checks AdaLang proved that GNATprove did not, 0 definite errors on checks GNATprove proved.

## Where the missing obligations are

3119 checks GNATprove proved have no AdaLang obligation at their place. By the construct they are in:

| Construct | Checks |
| --- | ---: |
| argument | 423 |
| slice | 385 |
| subprogram-body | 221 |
| in aspect pre | 213 |
| assignment-value | 200 |
| assignment-target | 185 |
| object-declaration | 150 |
| condition | 147 |
| in aspect post | 135 |
| in aspect global | 128 |
| call-statement | 113 |
| expression-function | 104 |
| attribute prefix or argument | 96 |
| in pragma loop_invariant | 93 |
| subprogram-declaration | 76 |
| in aspect contract_cases | 61 |
| aggregate | 57 |
| conditional-expression | 50 |
| loop-range | 39 |
| in pragma assert | 38 |
| component-declaration | 33 |
| in aspect refined_post | 30 |
| subtype-indication | 26 |
| in aspect initializes | 25 |
| in aspect abstract_state | 16 |

By GNATprove check, with the constructs it is most often in:

| GNATprove check | Checks | Where |
| --- | ---: | --- |
| range check | 730 | in aspect pre 128, argument 119, in pragma loop_invariant 89, object-declaration 75, expression-function 72 |
| predicate check | 421 | assignment-target 173, argument 131, assignment-value 50, slice 33, type-declaration 8 |
| pointer dereference check | 336 | attribute prefix or argument 94, slice 65, in aspect pre 63, in aspect post 63, argument 20 |
| precondition | 310 | call-statement 109, assignment-value 59, conditional-expression 32, subprogram-declaration 21, in aspect pre 17 |
| length check | 309 | condition 80, subprogram-body 78, slice 72, assignment-value 49, object-declaration 18 |
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

Produced by `benchmarks/gnatprove_gap_contexts.py` from the ledger's rows.
The construct is read from the syntax alone, from the inside out. What is
left under a `Global` aspect is the initialization of state abstractions
and of globals in sources outside the analyzed project; under a subprogram
declaration, the termination and contract checks of the SPARK library
units, which the lanes do not analyze.

## sparknacl

GNATprove reports 2454 checks (2463 messages, a check of a generic unit being repeated for each instance): 2446 proved, 0 justified by the corpus, 8 not proved. AdaLang raises 10258 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 897 | 36.7% |
| unproved | 1132 | 46.3% |
| unsupported | 120 | 4.9% |
| no obligation here | 158 | 6.5% |
| no such obligation kind | 139 | 5.7% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 585 | 176 | 291 | 22 | 96 | 0 |
| initialization of | 356 | 229 | 119 | 6 | 2 | 0 |
| data dependencies | 198 | 197 | 1 | 0 | 0 | 0 |
| assertion | 187 | 19 | 150 | 18 | 0 | 0 |
| overflow check | 155 | 3 | 136 | 0 | 16 | 0 |
| division check | 153 | 147 | 0 | 6 | 0 | 0 |
| index check | 142 | 21 | 73 | 6 | 42 | 0 |
| precondition | 123 | 7 | 106 | 10 | 0 | 0 |
| initialization check | 105 | 19 | 46 | 38 | 2 | 0 |
| Always_Terminates | 103 | 79 | 24 | 0 | 0 | 0 |
| loop invariant initialization | 81 | 0 | 74 | 7 | 0 | 0 |
| loop invariant preservation | 79 | 0 | 72 | 7 | 0 | 0 |
| length check | 67 | 0 | 0 | 0 | 67 | 0 |
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
| another kind on this line | 76 |
| same kind within 3 lines | 71 |
| nothing on this line | 6 |
| fewer obligations of this kind on the line | 5 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | this call form cannot be inlined safely | 145 |
| unproved | the invariant is not at the loop-head cut point | 138 |
| unsupported | outside bounded verification subset | 120 |
| unproved | incoming paths disagree or object is external | 114 |
| unproved | the required bounds are not statically known | 112 |
| unproved | the current non-relational range domain is inconclusive | 90 |
| unproved | current contract transfer does not certify safety | 82 |
| unproved | this expression form is outside the scalar VC subset | 80 |
| unproved | the blocking object is not known to be initialized | 79 |
| unproved | some path to the exit does not assign the whole parameter | 51 |
| unproved | slice bound and array bound ranges remain inconclusive | 42 |
| unproved | the expression conflicts with its symbolic scalar sort | 40 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 81 | 1 | 73 | 7 |
| division-by-zero | 39 | 19 | 20 | 0 |
| index-check | 939 | 753 | 129 | 57 |
| initialization-check | 2720 | 2360 | 321 | 39 |
| integer-overflow | 1423 | 320 | 1087 | 16 |
| postcondition | 1 | 0 | 1 | 0 |
| precondition | 119 | 7 | 102 | 10 |
| range-check | 1823 | 748 | 1070 | 5 |

## saatana

GNATprove reports 367 checks (376 messages, a check of a generic unit being repeated for each instance): 367 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 1595 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 115 | 31.3% |
| unproved | 201 | 54.8% |
| no obligation here | 26 | 7.1% |
| no such obligation kind | 25 | 6.8% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 103 | 9 | 80 | 0 | 14 | 0 |
| division check | 44 | 42 | 2 | 0 | 0 | 0 |
| overflow check | 31 | 4 | 27 | 0 | 0 | 0 |
| index check | 29 | 9 | 8 | 0 | 12 | 0 |
| precondition | 22 | 0 | 22 | 0 | 0 | 0 |
| length check | 20 | 0 | 0 | 0 | 20 | 0 |
| data dependencies | 20 | 20 | 0 | 0 | 0 | 0 |
| initialization of | 18 | 16 | 2 | 0 | 0 | 0 |
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
| another kind on this line | 12 |
| same kind within 3 lines | 8 |
| fewer obligations of this kind on the line | 4 |
| nothing on this line | 2 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the required bounds are not statically known | 26 |
| unproved | the blocking object is not known to be initialized | 23 |
| unproved | this expression form is outside the scalar VC subset | 22 |
| unproved | the current non-relational range domain is inconclusive | 18 |
| unproved | the invariant is not at the loop-head cut point | 18 |
| unproved | slice bound and array bound ranges remain inconclusive | 15 |
| unproved | information flow is not yet analyzed to the point of proof | 14 |
| unproved | current contract transfer does not certify safety | 12 |
| unproved | the callee is not a plain expression function | 9 |
| unproved | this operator is outside the scalar VC subset | 8 |
| unproved | the slice range is not written as two bounds | 7 |
| unproved | static evaluation is inconclusive | 6 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 9 | 0 | 9 | 0 |
| division-by-zero | 15 | 7 | 1 | 7 |
| index-check | 164 | 138 | 23 | 3 |
| initialization-check | 573 | 339 | 144 | 90 |
| integer-overflow | 215 | 94 | 95 | 26 |
| precondition | 72 | 0 | 30 | 42 |
| range-check | 192 | 66 | 77 | 49 |

## libkeccak

GNATprove reports 3321 checks (20673 messages, a check of a generic unit being repeated for each instance): 3321 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 12104 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 679 | 20.4% |
| unproved | 1857 | 55.9% |
| unsupported | 2 | 0.1% |
| no obligation here | 488 | 14.7% |
| no such obligation kind | 295 | 8.9% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 631 | 53 | 365 | 0 | 213 | 0 |
| overflow check | 569 | 80 | 484 | 0 | 5 | 0 |
| initialization of | 344 | 100 | 163 | 0 | 81 | 0 |
| division check | 306 | 204 | 102 | 0 | 0 | 0 |
| precondition | 273 | 7 | 149 | 1 | 116 | 0 |
| index check | 199 | 44 | 82 | 0 | 73 | 0 |
| data dependencies | 155 | 113 | 42 | 0 | 0 | 0 |
| predicate check | 154 | 0 | 0 | 0 | 154 | 0 |
| loop invariant initialization | 114 | 21 | 93 | 0 | 0 | 0 |
| loop invariant preservation | 114 | 2 | 112 | 0 | 0 | 0 |
| assertion | 90 | 6 | 84 | 0 | 0 | 0 |
| flow dependencies | 81 | 0 | 81 | 0 | 0 | 0 |
| postcondition | 79 | 2 | 76 | 1 | 0 | 0 |
| length check | 74 | 0 | 0 | 0 | 74 | 0 |
| Always_Terminates | 46 | 45 | 1 | 0 | 0 | 0 |
| non-aliasing | 37 | 0 | 0 | 0 | 37 | 0 |
| contract case | 28 | 0 | 0 | 0 | 28 | 0 |
| loop variant | 21 | 0 | 21 | 0 | 0 | 0 |
| initialization check | 4 | 2 | 2 | 0 | 0 | 0 |
| contract or exit cases | 2 | 0 | 0 | 0 | 2 | 0 |

Where AdaLang has no obligation of the kind at the place:

| What AdaLang has instead | Checks |
| --- | ---: |
| another kind on this line | 284 |
| same kind within 3 lines | 165 |
| nothing on this line | 29 |
| fewer obligations of this kind on the line | 10 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | the blocking object is not known to be initialized | 505 |
| unproved | the current range domain does not certify the result | 280 |
| unproved | this expression form is outside the scalar VC subset | 183 |
| unproved | incoming paths disagree or object is external | 130 |
| unproved | the current non-relational range domain is inconclusive | 110 |
| unproved | slice bound and array bound ranges remain inconclusive | 109 |
| unproved | the scalar loop preservation VC was not discharged | 87 |
| unproved | the required bounds are not statically known | 84 |
| unproved | information flow is not yet analyzed to the point of proof | 81 |
| unproved | some path to the exit does not assign the whole parameter | 35 |
| unproved | this call form cannot be inlined safely | 26 |
| unproved | static evaluation does not determine a nonzero operand | 25 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 141 | 1 | 140 | 0 |
| data-dependencies | 36 | 15 | 21 | 0 |
| division-by-zero | 399 | 148 | 251 | 0 |
| flow-dependencies | 8 | 0 | 8 | 0 |
| index-check | 677 | 530 | 147 | 0 |
| initialization-check | 4702 | 2213 | 2485 | 4 |
| integer-overflow | 1026 | 135 | 891 | 0 |
| loop-invariant-initialization | 17 | 3 | 14 | 0 |
| loop-invariant-preservation | 17 | 1 | 16 | 0 |
| loop-variant | 2 | 0 | 2 | 0 |
| postcondition | 3 | 0 | 3 | 0 |
| precondition | 195 | 7 | 187 | 1 |
| range-check | 1613 | 274 | 1339 | 0 |
| termination | 4 | 3 | 1 | 0 |

## coap_spark

GNATprove reports 6809 checks (7423 messages, a check of a generic unit being repeated for each instance): 6795 proved, 0 justified by the corpus, 14 not proved. AdaLang raises 22064 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1795 | 26.4% |
| unproved | 2127 | 31.3% |
| unsupported | 1182 | 17.4% |
| no obligation here | 620 | 9.1% |
| no such obligation kind | 864 | 12.7% |
| file without any obligation | 207 | 3.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| precondition | 2294 | 599 | 954 | 556 | 185 | 0 |
| Always_Terminates | 869 | 723 | 79 | 0 | 67 | 0 |
| range check | 845 | 29 | 335 | 180 | 301 | 0 |
| postcondition | 379 | 63 | 214 | 78 | 24 | 0 |
| pointer dereference check | 336 | 0 | 0 | 0 | 336 | 0 |
| assertion | 299 | 2 | 131 | 162 | 4 | 0 |
| overflow check | 278 | 23 | 178 | 61 | 16 | 0 |
| initialization of | 277 | 128 | 57 | 90 | 2 | 0 |
| division check | 265 | 209 | 32 | 24 | 0 | 0 |
| resource or memory leak | 211 | 0 | 0 | 0 | 211 | 0 |
| predicate check | 181 | 0 | 0 | 0 | 181 | 0 |
| discriminant check | 135 | 0 | 0 | 0 | 135 | 0 |
| length check | 108 | 0 | 0 | 0 | 108 | 0 |
| index check | 96 | 5 | 25 | 17 | 49 | 0 |
| loop invariant preservation | 47 | 2 | 38 | 7 | 0 | 0 |
| loop invariant initialization | 47 | 7 | 33 | 7 | 0 | 0 |
| data dependencies | 42 | 5 | 6 | 0 | 31 | 0 |
| flow dependencies | 28 | 0 | 26 | 0 | 2 | 0 |
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
| another kind on this line | 375 |
| same kind within 3 lines | 174 |
| nothing on this line | 67 |
| fewer obligations of this kind on the line | 4 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unsupported | outside bounded verification subset | 1182 |
| unproved | current contract transfer does not certify safety | 833 |
| unproved | this expression form is outside the scalar VC subset | 240 |
| unproved | the required bounds are not statically known | 159 |
| unproved | the blocking object is not known to be initialized | 150 |
| unproved | this attribute is outside the scalar VC subset | 113 |
| unproved | the current non-relational range domain is inconclusive | 99 |
| unproved | incoming paths disagree or object is external | 59 |
| unproved | slice bound and array bound ranges remain inconclusive | 51 |
| unproved | the current range domain does not certify the result | 43 |
| unproved | the expression conflicts with its symbolic scalar sort | 36 |
| unproved | the callee is not a plain expression function | 34 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 58 | 2 | 38 | 18 |
| division-by-zero | 13 | 1 | 8 | 4 |
| flow-dependencies | 3 | 0 | 3 | 0 |
| index-check | 841 | 13 | 714 | 114 |
| initialization-check | 10904 | 6909 | 1842 | 2153 |
| integer-overflow | 1028 | 33 | 842 | 153 |
| postcondition | 23 | 0 | 10 | 13 |
| precondition | 2314 | 687 | 965 | 662 |
| range-check | 1149 | 62 | 551 | 536 |
| termination | 48 | 13 | 35 | 0 |

GNATprove messages not counted as checks: function contract feasibility proved (Z3: 1 VC in max 0.0 se (2); function contract feasibility proved (CVC5: 1 VC in max 0.0  (2).

## tokeneer

GNATprove reports 2127 checks (2205 messages, a check of a generic unit being repeated for each instance): 2114 proved, 13 justified by the corpus, 0 not proved. AdaLang raises 8802 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 813 | 38.5% |
| unproved | 1000 | 47.3% |
| unsupported | 2 | 0.1% |
| no obligation here | 204 | 9.6% |
| no such obligation kind | 93 | 4.4% |
| file without any obligation | 2 | 0.1% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initialization of | 708 | 281 | 397 | 0 | 30 | 0 |
| data dependencies | 281 | 260 | 21 | 0 | 0 | 0 |
| flow dependencies | 233 | 0 | 210 | 0 | 23 | 0 |
| precondition | 226 | 74 | 143 | 0 | 9 | 0 |
| range check | 208 | 10 | 92 | 0 | 106 | 0 |
| Always_Terminates | 141 | 133 | 8 | 0 | 0 | 0 |
| postcondition | 57 | 2 | 55 | 0 | 0 | 0 |
| index check | 56 | 3 | 15 | 2 | 36 | 0 |
| length check | 42 | 0 | 0 | 0 | 42 | 0 |
| division check | 41 | 41 | 0 | 0 | 0 | 0 |
| overflow check | 29 | 8 | 20 | 0 | 1 | 0 |
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
| same kind within 3 lines | 72 |
| nothing on this line | 51 |
| fewer obligations of this kind on the line | 4 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | incoming paths disagree or object is external | 216 |
| unproved | information flow is not yet analyzed to the point of proof | 210 |
| unproved | some path to the exit does not assign the whole object, or it is a state abstraction | 134 |
| unproved | current contract transfer does not certify safety | 108 |
| unproved | the blocking object is not known to be initialized | 87 |
| unproved | some path to the exit does not assign the whole parameter | 47 |
| unproved | this expression form is outside the scalar VC subset | 45 |
| unproved | slice bound and array bound ranges remain inconclusive | 18 |
| unproved | this call form cannot be inlined safely | 18 |
| unproved | State is used and is not listed | 16 |
| unproved | the scalar loop preservation VC was not discharged | 15 |
| unproved | the required bounds are not statically known | 14 |

### Disagreements

- AdaLang proved, GNATprove did not: 0
- AdaLang reports a definite error, GNATprove proved: 0

### AdaLang obligations without a GNATprove check

| Kind | Obligations | Proved | Unproved | Unsupported |
| --- | ---: | ---: | ---: | ---: |
| assertion | 19 | 0 | 19 | 0 |
| division-by-zero | 10 | 8 | 2 | 0 |
| index-check | 248 | 37 | 188 | 23 |
| initialization-check | 3576 | 1724 | 1642 | 210 |
| integer-overflow | 230 | 32 | 181 | 17 |
| postcondition | 4 | 0 | 4 | 0 |
| precondition | 400 | 76 | 314 | 10 |
| range-check | 1853 | 257 | 1477 | 119 |
