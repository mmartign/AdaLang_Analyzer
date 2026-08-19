# libkeccak: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Seventh run of the GNATcheck oracle comparison (after sparknacl, aws,
gnatcoll-core, ada_drivers_library, cubedos, coap_spark). Third fully-SPARK
corpus, and the best-agreeing run so far by a clear margin — both the
highest GNATcheck-side match rate of any corpus and the first perfect
(100%) match for a high-volume rule pair in either direction.

## Environment

- Corpus: damaki/libkeccak at `4b7174fccbf5461998b18395aaeecc68bb25798d`
  (`LIBKECCAK_REVISION`), `libkeccak.gpr` with
  `-XLIBKECCAK_ARCH=generic -XLIBKECCAK_SIMD=none` (the portable Ada path,
  same as the GNATprove-comparison `run.sh`), 100 analyzed files (110
  `.adb`/`.ads` files total under `src/`).
- AdaLang Analyzer: commit `8cb0553be2bb5c041cf2ec3a5271b8b52cad1a44`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged. `recursive_subprograms`/
  `No_Recursion` excluded as in every prior run.
- Reproduce: `LIBKECCAK_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/libkeccak/run_gnatcheck.sh` (after `alr build` in the checkout
  per `README.md`, to generate `config/libkeccak_config.gpr`).

## Run completeness: two crashes, run otherwise complete

`gnatcheck.status` is `2`. Two `STORAGE_ERROR: stack overflow` occurrences
(`"unparsable worker output"`), same crash class as AWS/
ada_drivers_library/cubedos, exact trigger unidentified again. 85 of the
100 analyzed files show at least one mapped-rule violation; processing
continued after both crashes (1,660 total violation lines recorded), same
"crashed but kept going" pattern as ada_drivers_library and cubedos, not
AWS's apparent early termination.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1460 | |
| &nbsp;&nbsp;matched by GNATcheck | 1224 | 83.8% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 236 | 16.2% |
| GNATcheck findings (mapped rules) | 1354 | |
| &nbsp;&nbsp;matched by AdaLang | 1224 | 90.4% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 130 | 9.6% |

Full per-rule table: `benchmark-results/libkeccak/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

**Both match rates are the best of any corpus run so far** (sparknacl:
85.7%/75.9%; AWS: 52.4%/28.9%; gnatcoll-core: 55.8%/39.1%;
ada_drivers_library: 43.2%/38.9%; cubedos: 85.7%/25.3%; coap_spark:
82.3%/8.4%). GNATcheck-side match at 90.4% is the strongest cross-tool
agreement observed in this entire series.

## Standout: `Magic_Number`/`numeric_literals` at 100% GNATcheck-side, real volume

1192 AdaLang findings, 1054 GNATcheck findings, **every one of GNATcheck's
1054 `numeric_literals` findings matched an AdaLang finding** (100%
GNATcheck-side — `numeric_literals` row shows `GCMatch% = 100%`). This is
the first rule pair in seven runs to reach 100% match in the
GNATcheck-side direction at four-figure volume (sparknacl's early 91% and
AWS's 89% were the previous high-water marks; gnatcoll-core's 97% and
cubedos's 97% AdaLang-side were close but not this direction). The
remaining 138 AdaLang-only findings are additional literals AdaLang flags
that GNATcheck's `numeric_literals` did not — a false-positive-direction
gap only, not a two-way disagreement.

## Confirms prior runs' explained effects, better-behaved than most

**Non-statement boolean-expression scope, `Non_Short_Circuit_Condition`/
`non_short_circuit_operators` (20 matched / 49 GNATcheck-only)** — same
root cause as every prior run (contract-aspect/expression-context `and`/
`or` outside AdaLang's statement-condition scope), at a modest scale here,
not re-derived from scratch.

**Naming-length scope split, `Naming_Convention`/`min_identifier_length`
(76%/70%)** — the best showing for this historically noisy pair across all
seven runs (sparknacl 63%/58% implied, AWS 87%/66%, gnatcoll-core 69%/66%,
cubedos 93%/19%, coap_spark 50%/1%); libkeccak's generic-permutation-core
style apparently uses fewer of the very short loop-index/parameter names
that drive the usual split, though this was not individually re-verified
example-by-example given the volume already explained by four prior runs.

## Caveats

- **Run completeness not independently re-confirmed**: two per-file
  crashes occurred; processing appears to have continued normally
  afterward (consistent with ada_drivers_library and cubedos, both later
  confirmed non-terminating crashes), but this run was not repeated to
  verify determinism.
- **Line-granularity matching**, **rule pairs are name-level, not
  proven-semantically-equivalent** — same caveat family as every prior
  run.
- Per `benchmarks/libkeccak/README.md`, this corpus's own SPARK proofs
  cover run-time-error freedom only, not functional correctness — not
  directly relevant to this GNATcheck rule-oracle comparison, but worth
  keeping in mind alongside the separate `--verify`/GNATprove comparison
  for this corpus.
