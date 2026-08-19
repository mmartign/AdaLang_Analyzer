# project_bias: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Ninth run of the GNATcheck oracle comparison (after sparknacl, aws,
gnatcoll-core, ada_drivers_library, cubedos, coap_spark, libkeccak,
saatana). A small (~3,600 line, per `README.md`) SPARK/Ada cryptographic
random-stream engine with heavy floating-point entropy math — the first
corpus in this series where the floating-point-specific rule pair gets a
real, large sample.

## Environment

- Corpus: EliAvila10/project_bias at
  `bb83565322eba9a0bd59ccda607edcdc0a1bd381` (`PROJECT_BIAS_REVISION`),
  `project_bias.gpr`, no scenario args, no external project dependencies
  (`config/project_bias_config.gpr` already checked into the pinned
  revision, unlike gnatcoll-core/libkeccak/coap_spark's Alire-generated
  configs).
- AdaLang Analyzer: commit `8cb0553be2bb5c041cf2ec3a5271b8b52cad1a44`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged. `recursive_subprograms`/
  `No_Recursion` excluded as in every prior run.
- Reproduce: `PROJECT_BIAS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/project_bias/run_gnatcheck.sh`.

## Run completeness: one crash, same recurring class

`gnatcheck.status` is `2`. One more `STORAGE_ERROR: stack overflow`
(`"unparsable worker output"`) — the same crash signature seen on AWS,
ada_drivers_library, cubedos, libkeccak (twice), and saatana; this is now
the **sixth of eight corpora** to hit this exact crash class (only
gnatcoll-core and coap_spark ran clean). Combined with saatana's tiny
corpus also triggering it, this crash class reads as an intrinsic defect
in this from-source GNATcheck build (independent of corpus size, domain,
or SPARK-vs-ordinary-Ada status) rather than something specific to any one
codebase's constructs — worth escalating as a build-quality issue on its
own, separate from anything about AdaLang's or GNATcheck's rule logic.
298 violation lines were recorded regardless, consistent with the
"crashed but kept processing" pattern established on the other five
occurrences.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 225 | |
| &nbsp;&nbsp;matched by GNATcheck | 165 | 73.3% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 60 | 26.7% |
| GNATcheck findings (mapped rules) | 263 | |
| &nbsp;&nbsp;matched by AdaLang | 165 | 62.7% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 98 | 37.3% |

Full per-rule table: `benchmark-results/project_bias/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

## Two-for-two perfect matches, both real volume

**`Floating_Equality`/`float_equality_checks`: 31 AdaLang findings, 31
GNATcheck findings, 100% match in both directions.** The first large,
clean sample for this rule pair in the series (every prior corpus showed
`n/a` or single-digit counts for it) — fitting, since
`README.md` specifically calls out this corpus's "floating-point equality
in formal contracts" as a distinguishing feature, and both
independently-implemented tools agree completely on every instance.

**`Redundant_Boolean_Comparison`/`redundant_boolean_expressions`: 14
findings each side, 100% match in both directions.** Second full, two-way
clean match in this run, at a smaller but still non-trivial sample size —
the strongest joint showing for this "close" rule pair across the series
so far (every prior corpus showed 0 or `n/a` for it).

## Confirms prior runs' explained effects

`Magic_Number`/`numeric_literals` (73%/90%) and `Naming_Convention`/
`min_identifier_length` (78%/15%) both land within the range already
established across sparknacl, AWS, gnatcoll-core, cubedos, coap_spark, and
libkeccak — not re-investigated example-by-example given six prior runs
already explain this pair's shape (loop-index exemption asymmetry for
naming; near-universal but not 100% agreement for numeric literals).
`No_Multiple_Return`/`improper_returns` (0% AdaLang-side match, 4 vs. 34)
is consistent with the subprogram-level-vs-statement-level granularity
split gnatcoll-core's Finding 2 and ada_drivers_library both already
established, not re-derived here.

## Caveats

- **This corpus is explicitly not an independent-oracle corpus**
  (`benchmarks/project_bias/README.md`'s own "Classification" section: no
  reproducible fully-proved GNATprove baseline at this revision) — that
  caveat is about the separate `--verify`/GNATprove comparison, not this
  GNATcheck rule-oracle one, but worth remembering this corpus sits outside
  the "fully proved" table for a reason unrelated to GNATcheck.
- **Run completeness not independently re-confirmed**: one crash, apparent
  full completion (see above), not re-run to verify determinism.
- **Line-granularity matching**, **rule pairs are name-level, not
  proven-semantically-equivalent** — same caveat family as every prior run.
- Per `README.md`, "the generator contains many near-identical procedures
  for different output alphabets" — this corpus's ~3,600 lines provide
  less independent structural diversity than the raw line count suggests,
  which may inflate agreement/disagreement counts for whichever rules fire
  inside those repeated procedures without adding independent evidence.
