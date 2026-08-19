# Saatana: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Eighth run of the GNATcheck oracle comparison (after sparknacl, aws,
gnatcoll-core, ada_drivers_library, cubedos, coap_spark, libkeccak). By far
the smallest corpus in the series (~1,200 lines across 5 source units plus
2 test drivers), and a useful data point specifically because of its size:
the recurring unidentified `STORAGE_ERROR` crash class shows up here too,
proving it is not a scale-dependent effect.

## Environment

- Corpus: HeisenbugLtd/Saatana at `7ba07e735498de39216a30479c3d2cc0817f03ac`
  (`SAATANA_REVISION`), `saatana.gpr`, no scenario args, no external project
  dependencies beyond `gnat` itself. 7 files got at least one mapped-rule
  finding from either tool: `saatana.ads`, `saatana-crypto.ads`/`.adb`,
  `saatana-crypto-phelix.ads`/`.adb`, `saatana-crypto-stream_tools.adb`,
  `test_phelix.adb`, `test_phelix_api.adb`.
- AdaLang Analyzer: commit `8cb0553be2bb5c041cf2ec3a5271b8b52cad1a44`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged. `recursive_subprograms`/
  `No_Recursion` excluded as in every prior run.
- Reproduce: `SAATANA_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/saatana/run_gnatcheck.sh`.

## Run completeness: one crash, but on the smallest corpus in the series

`gnatcheck.status` is `2`. One `STORAGE_ERROR: stack overflow`
(`"unparsable worker output"`), same crash class as AWS/
ada_drivers_library/cubedos/libkeccak, appearing at the very start of the
log (before any violation lines, same position as cubedos's single crash).
**This is the most useful data point on this crash class so far**: it
recurs even on a ~1,200-line, 5-unit corpus, ruling out "only happens on
large/complex real-world code" as an explanation. Processing evidently
continued regardless — all 7 files with plausible findings show up in
`gnatcheck.txt` (167 total violation lines), so this again reads as a
single crashed worker in a parallel batch, not a run-ending abort. The
exact rule/file trigger remains unidentified, same open problem as every
prior occurrence.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 157 | |
| &nbsp;&nbsp;matched by GNATcheck | 96 | 61.1% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 61 | 38.9% |
| GNATcheck findings (mapped rules) | 120 | |
| &nbsp;&nbsp;matched by AdaLang | 96 | 80.0% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 24 | 20.0% |

Full per-rule table: `benchmark-results/saatana/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

The GNATcheck-side match rate (80.0%) is the second-best of any corpus so
far, after libkeccak's 90.4% — both are small-to-medium, disciplined SPARK
cryptographic libraries, the same shape sparknacl (75.9%) also fits,
reinforcing that this rule-checking domain (versus real, large,
general-purpose codebases like AWS/gnatcoll-core) is where the two tools
agree most.

## What matched / didn't, at this corpus's necessarily small scale

`Magic_Number`/`numeric_literals`: 138 AdaLang findings, 89 GNATcheck
findings, 100% GNATcheck-side match — every GNATcheck `numeric_literals`
finding has an AdaLang counterpart, the same 100%-one-direction result
libkeccak's larger run also showed, now confirmed at the opposite end of
the corpus-size range. `Cyclomatic_Complexity`/`metrics_cyclomatic_
complexity`: 1 finding each side, matched (100%, but `n=1` — not a
meaningful sample on its own, consistent with the larger corpora's
threshold-gap explanation rather than contradicting it). `Naming_
Convention`/`min_identifier_length` (46%/23%) and `potential_parameters_
aliasing` (0% at `n=1`) are too small a sample to say anything beyond "not
inconsistent with the scope-difference explanations already established on
larger corpora" — not independently investigated further given the volume
doesn't support it.

## Caveats

- **Sample size is very small** (157 AdaLang / 120 GNATcheck findings
  total, an order of magnitude below every other corpus except the
  driver-subset runs) — several per-rule percentages above are single-digit
  counts and should not be read as precise rates, only as "not
  contradicting" the patterns already established on sparknacl, AWS,
  gnatcoll-core, and libkeccak.
- **Run completeness not independently re-confirmed**: one crash, apparent
  full completion (see above), not re-run to verify determinism.
- **Line-granularity matching**, **rule pairs are name-level, not
  proven-semantically-equivalent** — same caveat family as every prior run.
- Per `benchmarks/saatana/README.md`, this corpus is CI-verified fully
  proved on every push — not directly relevant to this GNATcheck
  rule-oracle comparison, but worth keeping in mind alongside the separate
  `--verify`/GNATprove comparison for this corpus.
