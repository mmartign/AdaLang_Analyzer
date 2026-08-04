# Saatana comparison benchmark

This benchmark compares AdaLang Analyzer's `--verify` bounded-scalar proof
obligations against GNATprove's `--mode=prove` results, per obligation (same
file, line, and check kind), on a pinned revision of
[HeisenbugLtd/Saatana](https://github.com/HeisenbugLtd/Saatana) — a small,
actively-maintained SPARK 2014 cryptographic framework (currently the Phelix
stream cipher), CI-verified fully proved on every push.

Like `benchmarks/sparknacl/`, Saatana is a fully-proved corpus, so
GNATprove's verdict is a trustworthy oracle here: the same two questions
matter — (1) does AdaLang ever call something `Proved_Safe` that GNATprove
could not prove (a soundness question), and (2) how often does AdaLang's
`Definite_Error` agree with GNATprove's not-proved verdict (a precision
question). Saatana is much smaller than SPARKNaCl (about 1,200 lines across
5 source units vs. SPARKNaCl's 51), so this benchmark's value isn't
sample size — it's a third, independently-written fully-proved corpus, by a
different author, in a still-different style (a single dense cryptographic
primitive with a hand-tuned per-file `Prove` package, rather than SPARKNaCl's
library-wide arithmetic or CubedOS's message-passing framework).

## Pinned source

- HeisenbugLtd/Saatana: `7ba07e735498de39216a30479c3d2cc0817f03ac`

Clone the corpus from the AdaLang Analyzer repository root:

```sh
git clone https://github.com/HeisenbugLtd/Saatana.git \
  /private/tmp/adalang-saatana-benchmark
git -C /private/tmp/adalang-saatana-benchmark checkout \
  7ba07e735498de39216a30479c3d2cc0817f03ac
```

No separate build/setup step is needed: `saatana.gpr` only depends on `gnat`
(`alire.toml`'s sole `[[depends-on]]`), and GNATprove is resolved the same
way `benchmarks/sparknacl/run.sh` resolves it (`GNATPROVE` env var, then
`PATH`, then `~/.alire/bin/gnatprove`).

Run the benchmark:

```sh
SAATANA_ROOT=/private/tmp/adalang-saatana-benchmark sh benchmarks/saatana/run.sh
```

`run.sh` verifies the pinned revision, then runs:

- AdaLang `--verify` against `saatana.gpr`, `--format=json`;
- GNATprove `--mode=prove -U --output=oneline` against the same project, with
  three explicit overrides of Saatana's own `Prove` package switches (see
  "Toolchain overrides" below) rather than the project's switches unmodified,
  unlike `benchmarks/sparknacl/`;
- `compare.awk` (identical to `benchmarks/sparknacl/compare.awk` and
  `benchmarks/cubedos/compare.awk`) over both outputs, writing
  `comparison.txt` to the results directory (default
  `benchmark-results/saatana/`, override with `RESULTS_DIR`).

## Toolchain overrides

Saatana's own `saatana.gpr` carries a tuned, per-file `Prove` package (see
`artifacts/gnatprove.out`, checked into the corpus itself: 338 checks, 0
unproved, 0 justified — the evidence backing its "fully proved" claim). Two
things about that configuration don't survive unmodified onto this
benchmark's toolchain:

1. **`saatana-crypto-phelix.adb`'s own switches name `--prover=Z3,CVC4`.**
   This benchmark's GNATprove (the same FSF 16.1.0 / Why3 1.8.2+git / CVC5
   1.3.2 pin `benchmarks/sparknacl/RESULTS_*.md` and
   `benchmarks/cubedos/RESULTS_*.md` document) does not ship CVC4 — the
   modern SPARK Community/FSF toolchain bundles CVC5 instead. Run
   unmodified, GNATprove aborts outright ("Selected prover not installed or
   not configured") partway through the corpus, the same category of
   environment gap as `FP-029`, not an AdaLang defect.
2. Substituting `--prover=z3,cvc5` on the command line (which overrides the
   project file's per-file switches) alone still leaves 3 `medium`
   ("step/time limit reached") findings on the tight per-file step budgets
   Saatana tuned specifically for CVC4's performance. `--timeout=60
   --steps=0`, the same generous budget `benchmarks/sparknacl/`'s own
   project file uses, resolves all three back to fully proved — CVC5 needs a
   larger budget than CVC4 needed to close the same three obligations, not a
   different result.
3. Saatana's `Prove` package has no `--report` switch at all, which leaves
   GNATprove's default of only reporting failed checks — fine for Saatana's
   own CI (a pass/fail gate), but useless for this benchmark's per-obligation
   comparison, which needs an "info: `<kind>` proved" line for every
   successfully discharged check, not just residual failures.
   `--report=statistics` matches the switch SPARKNaCl's own `sparknacl.gpr`
   already carries for the same reason.

None of these three change what Saatana's own CI already established — the
corpus is still fully proved (0 `medium`/`high` findings) once CVC5 is given
the budget CVC4 had — they are what makes an already-fully-proved corpus
produce a comparable, per-check GNATprove log on a toolchain it wasn't
originally tuned for.

## Matching design

Same as `benchmarks/sparknacl/` and `benchmarks/cubedos/`: obligations are
matched by `(basename(file), line, normalized check kind)`, count-mismatched
locations are reported separately rather than guessed, and `compare.awk`'s
five per-pair buckets and two coverage-only counts have the same meaning.
See `benchmarks/sparknacl/README.md` for the full design description.

## Caveats

- GNATprove version, solver versions, and exact message wording are recorded
  in each dated `RESULTS_*.md` for reproducibility.
- Saatana's own checked-in `artifacts/gnatprove.out` reports 338 total
  checks (under real CVC4, GNAT Community 2020); this benchmark's run
  reports 404 (under CVC5, FSF 16.1.0) — both 0 unproved / 0 justified, but
  the different GNATprove version evidently identifies more implicit
  `Always_Terminates` and initialization obligations by default than the
  2020-era toolchain did. This is a GNATprove version difference in the
  oracle itself, not a Saatana or AdaLang discrepancy.
- The GNATprove message-text substring matching in `compare.awk` is a
  heuristic against observed wording, not a stable GNATprove API — see
  `benchmarks/sparknacl/README.md`'s caveat for the same point.

See the latest `RESULTS_*.md` in this directory for recorded runs.
