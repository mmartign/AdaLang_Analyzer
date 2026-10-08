# What separates `--verify` from GNATprove: a ledger

Recorded 2026-10-08 with AdaLang Analyzer 1.8.4, against the GNATprove
output saved by the 2026-10-02 runs of the five fully proved corpora
(`sparknacl`, `saatana`, `libkeccak`, `coap_spark`, `tokeneer`).

1.8.4 adds obligations to those of 1.8.3, and proves most of what it adds.
An array given to a target has a length check, a kind of obligation
AdaLang did not have: 308 of GNATprove's 311 have one, and 129 of them are
proved. The length of an array is checked where it is converted to an
integer type, and is known to be no more than the number of values of its
index subtype. The precondition of an operator that a declaration defines
is an obligation at the operator. `FP-116` is fixed, a false-safe that
shows in no corpus: such an operator was read as the predefined operation.
1.8.3 proved 4,299 of the checks below, left 6,317 unproved and 1,306
unsupported, and had no obligation for 3,121.

1.8.3 had kept the obligations of 1.8.2, but for three range checks on an
actual that is a static value, and decided more of them. A name written
with its package in front of it is the entity it names, a named number is
its value, and `T'Size` of a static discrete subtype is a number. A loop
with a name, a `goto` to a label further down and a quantified loop
invariant no longer put a subprogram outside the subset. It fixed two
false-safes in the checks that were there (`FP-112`, `FP-113`), a false
positive (`FP-114`) and a false-safe that no corpus exercises (`FP-115`).
1.8.2 had proved 3,536 of the checks, left 6,062 unproved and 2,324
unsupported.

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

The per-corpus comparisons (`<corpus>/RESULTS_2026-10-09.md`) answer one
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
| proved-safe | 4757 | 31.6% |
| unproved | 6397 | 42.5% |
| unsupported | 1397 | 9.3% |
| no obligation here | 1178 | 7.8% |
| no such obligation kind | 1105 | 7.3% |
| file without any obligation | 209 | 1.4% |

| Corpus | Proved by GNATprove | AdaLang proved | Unproved | Unsupported | No obligation here | No such kind | File without obligations |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| sparknacl | 2446 | 979 | 1126 | 120 | 149 | 72 | 0 |
| saatana | 367 | 139 | 208 | 0 | 15 | 5 | 0 |
| libkeccak | 3321 | 889 | 1845 | 2 | 364 | 221 | 0 |
| coap_spark | 6795 | 1918 | 2192 | 1273 | 449 | 756 | 207 |
| tokeneer | 2114 | 832 | 1026 | 2 | 201 | 51 | 2 |

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
| sparknacl | 2,446 | 979 | 1,246 | 221 | 0 |
| saatana | 367 | 139 | 208 | 20 | 0 |
| libkeccak | 3,321 | 889 | 1,847 | 585 | 0 |
| coap_spark | 6,795 | 1,918 | 3,465 | 1,412 | 0 |
| tokeneer | 2,114 | 832 | 1,028 | 254 | 0 |
| All five | 15,043 | 4,757 | 7,794 | 2,492 | 0 |

The second column is what AdaLang proves; it is 4,757 with the logs and
without them. The third and fourth are GNATprove's work, reported as
GNATprove's: 7,794 checks on an obligation AdaLang has and did not decide
(the 6,397 unproved and the 1,397 unsupported above) and 2,492 for which it
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

2490 checks GNATprove proved have no AdaLang obligation at their place. By the construct they are in:

| Construct | Checks |
| --- | ---: |
| argument | 421 |
| slice | 301 |
| assignment-target | 185 |
| assignment-value | 148 |
| subprogram-body | 143 |
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
| range check | 451 | argument 117, object-declaration 52, expression-function 51, in pragma loop_invariant 44, in aspect pre 41 |
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
The construct is read from the syntax alone, from the inside out. What is
left under a `Global` aspect is the initialization of state abstractions
and of globals in sources outside the analyzed project; under a subprogram
declaration, the termination and contract checks of the SPARK library
units, which the lanes do not analyze.

## sparknacl

GNATprove reports 2454 checks (2463 messages, a check of a generic unit being repeated for each instance): 2446 proved, 0 justified by the corpus, 8 not proved. AdaLang raises 10344 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 979 | 40.0% |
| unproved | 1126 | 46.0% |
| unsupported | 120 | 4.9% |
| no obligation here | 149 | 6.1% |
| no such obligation kind | 72 | 2.9% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 585 | 200 | 276 | 22 | 87 | 0 |
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
| length check | 67 | 58 | 9 | 0 | 0 | 0 |
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
| unproved | this call form cannot be inlined safely | 145 |
| unproved | the invariant is not at the loop-head cut point | 138 |
| unsupported | outside bounded verification subset | 120 |
| unproved | incoming paths disagree or object is external | 114 |
| unproved | the required bounds are not statically known | 113 |
| unproved | this expression form is outside the scalar VC subset | 85 |
| unproved | current contract transfer does not certify safety | 82 |
| unproved | the blocking object is not known to be initialized | 80 |
| unproved | the current non-relational range domain is inconclusive | 71 |
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
| index-check | 939 | 754 | 128 | 57 |
| initialization-check | 2720 | 2360 | 321 | 39 |
| integer-overflow | 1423 | 324 | 1083 | 16 |
| postcondition | 1 | 0 | 1 | 0 |
| precondition | 119 | 7 | 102 | 10 |
| range-check | 1833 | 757 | 1073 | 3 |

## saatana

GNATprove reports 367 checks (376 messages, a check of a generic unit being repeated for each instance): 367 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 1617 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 139 | 37.9% |
| unproved | 208 | 56.7% |
| no obligation here | 15 | 4.1% |
| no such obligation kind | 5 | 1.4% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 103 | 23 | 77 | 0 | 3 | 0 |
| division check | 44 | 42 | 2 | 0 | 0 | 0 |
| overflow check | 31 | 4 | 27 | 0 | 0 | 0 |
| index check | 29 | 9 | 8 | 0 | 12 | 0 |
| precondition | 22 | 0 | 22 | 0 | 0 | 0 |
| length check | 20 | 10 | 10 | 0 | 0 | 0 |
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
| same kind within 3 lines | 9 |
| another kind on this line | 6 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unproved | this expression form is outside the scalar VC subset | 30 |
| unproved | the required bounds are not statically known | 26 |
| unproved | the blocking object is not known to be initialized | 24 |
| unproved | the invariant is not at the loop-head cut point | 18 |
| unproved | the current non-relational range domain is inconclusive | 17 |
| unproved | information flow is not yet analyzed to the point of proof | 14 |
| unproved | slice bound and array bound ranges remain inconclusive | 14 |
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
| integer-overflow | 214 | 94 | 95 | 25 |
| length-check | 2 | 0 | 0 | 2 |
| precondition | 73 | 0 | 30 | 43 |
| range-check | 181 | 72 | 80 | 29 |

## libkeccak

GNATprove reports 3321 checks (20673 messages, a check of a generic unit being repeated for each instance): 3321 proved, 0 justified by the corpus, 0 not proved. AdaLang raises 12380 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 889 | 26.8% |
| unproved | 1845 | 55.6% |
| unsupported | 2 | 0.1% |
| no obligation here | 364 | 11.0% |
| no such obligation kind | 221 | 6.7% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| range check | 631 | 226 | 316 | 0 | 89 | 0 |
| overflow check | 569 | 84 | 480 | 0 | 5 | 0 |
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
| length check | 74 | 33 | 41 | 0 | 0 | 0 |
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
| unproved | the blocking object is not known to be initialized | 529 |
| unproved | the current range domain does not certify the result | 276 |
| unproved | this expression form is outside the scalar VC subset | 183 |
| unproved | incoming paths disagree or object is external | 130 |
| unproved | slice bound and array bound ranges remain inconclusive | 109 |
| unproved | the scalar loop preservation VC was not discharged | 87 |
| unproved | the required bounds are not statically known | 84 |
| unproved | information flow is not yet analyzed to the point of proof | 81 |
| unproved | the current non-relational range domain is inconclusive | 64 |
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
| integer-overflow | 1026 | 146 | 880 | 0 |
| length-check | 20 | 18 | 2 | 0 |
| loop-invariant-initialization | 17 | 3 | 14 | 0 |
| loop-invariant-preservation | 17 | 1 | 16 | 0 |
| loop-variant | 2 | 0 | 2 | 0 |
| postcondition | 3 | 0 | 3 | 0 |
| precondition | 195 | 7 | 187 | 1 |
| range-check | 1671 | 338 | 1333 | 0 |
| termination | 4 | 3 | 1 | 0 |

## coap_spark

GNATprove reports 6809 checks (7423 messages, a check of a generic unit being repeated for each instance): 6795 proved, 0 justified by the corpus, 14 not proved. AdaLang raises 22274 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 1918 | 28.2% |
| unproved | 2192 | 32.3% |
| unsupported | 1273 | 18.7% |
| no obligation here | 449 | 6.6% |
| no such obligation kind | 756 | 11.1% |
| file without any obligation | 207 | 3.0% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| precondition | 2294 | 599 | 996 | 556 | 143 | 0 |
| Always_Terminates | 869 | 723 | 79 | 0 | 67 | 0 |
| range check | 845 | 139 | 337 | 200 | 169 | 0 |
| postcondition | 379 | 63 | 214 | 78 | 24 | 0 |
| pointer dereference check | 336 | 0 | 0 | 0 | 336 | 0 |
| assertion | 299 | 2 | 131 | 162 | 4 | 0 |
| overflow check | 278 | 23 | 178 | 61 | 16 | 0 |
| initialization of | 277 | 128 | 57 | 90 | 2 | 0 |
| division check | 265 | 209 | 32 | 24 | 0 | 0 |
| resource or memory leak | 211 | 0 | 0 | 0 | 211 | 0 |
| predicate check | 181 | 0 | 0 | 0 | 181 | 0 |
| discriminant check | 135 | 0 | 0 | 0 | 135 | 0 |
| length check | 108 | 13 | 21 | 71 | 3 | 0 |
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
| another kind on this line | 243 |
| same kind within 3 lines | 153 |
| nothing on this line | 44 |
| fewer obligations of this kind on the line | 9 |

Reasons AdaLang gives where it has an obligation but no verdict:

| Status | Reason | Checks |
| --- | ---: | ---: |
| unsupported | outside bounded verification subset | 1273 |
| unproved | current contract transfer does not certify safety | 875 |
| unproved | this expression form is outside the scalar VC subset | 240 |
| unproved | the blocking object is not known to be initialized | 160 |
| unproved | the required bounds are not statically known | 146 |
| unproved | this call form cannot be inlined safely | 98 |
| unproved | this attribute is outside the scalar VC subset | 72 |
| unproved | the current non-relational range domain is inconclusive | 61 |
| unproved | incoming paths disagree or object is external | 59 |
| unproved | slice bound and array bound ranges remain inconclusive | 48 |
| unproved | the current range domain does not certify the result | 43 |
| unproved | the expression conflicts with its symbolic scalar sort | 36 |

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
| integer-overflow | 985 | 23 | 809 | 153 |
| length-check | 5 | 0 | 0 | 5 |
| postcondition | 23 | 0 | 10 | 13 |
| precondition | 2314 | 687 | 965 | 662 |
| range-check | 1117 | 67 | 556 | 494 |
| termination | 48 | 13 | 35 | 0 |

GNATprove messages not counted as checks: function contract feasibility proved (Z3: 1 VC in max 0.0 se (2); function contract feasibility proved (CVC5: 1 VC in max 0.0  (2).

## tokeneer

GNATprove reports 2127 checks (2205 messages, a check of a generic unit being repeated for each instance): 2114 proved, 13 justified by the corpus, 0 not proved. AdaLang raises 8941 obligations.

### Checks GNATprove proved

| AdaLang | Checks | Share |
| --- | ---: | ---: |
| proved-safe | 832 | 39.4% |
| unproved | 1026 | 48.5% |
| unsupported | 2 | 0.1% |
| no obligation here | 201 | 9.5% |
| no such obligation kind | 51 | 2.4% |
| file without any obligation | 2 | 0.1% |

| GNATprove check | Proved | AdaLang proved | Unproved | Unsupported | No obligation | Definite error |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| initialization of | 708 | 281 | 397 | 0 | 30 | 0 |
| data dependencies | 281 | 260 | 21 | 0 | 0 | 0 |
| flow dependencies | 233 | 0 | 210 | 0 | 23 | 0 |
| precondition | 226 | 74 | 143 | 0 | 9 | 0 |
| range check | 208 | 14 | 91 | 0 | 103 | 0 |
| Always_Terminates | 141 | 133 | 8 | 0 | 0 | 0 |
| postcondition | 57 | 2 | 55 | 0 | 0 | 0 |
| index check | 56 | 3 | 15 | 2 | 36 | 0 |
| length check | 42 | 15 | 27 | 0 | 0 | 0 |
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
| same kind within 3 lines | 69 |
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
| unproved | this expression form is outside the scalar VC subset | 50 |
| unproved | some path to the exit does not assign the whole parameter | 47 |
| unproved | the two lengths are not known to be equal | 20 |
| unproved | slice bound and array bound ranges remain inconclusive | 18 |
| unproved | this call form cannot be inlined safely | 18 |
| unproved | the required bounds are not statically known | 16 |
| unproved | State is used and is not listed | 16 |

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
| integer-overflow | 230 | 36 | 177 | 17 |
| length-check | 56 | 13 | 42 | 1 |
| postcondition | 4 | 0 | 4 | 0 |
| precondition | 400 | 76 | 314 | 10 |
| range-check | 1891 | 303 | 1469 | 119 |

