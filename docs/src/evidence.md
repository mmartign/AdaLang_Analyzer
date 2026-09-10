# Benchmarks & quality evidence

AdaLang Analyzer treats precision as a release artifact. Two evidence bodies
live in the repository, next to the scripts and data that produce them, and
are refreshed as part of the release process.

## Benchmarks — validation against real, independently authored code

The [`benchmarks/`](https://github.com/mmartign/AdaLang_Analyzer/tree/main/benchmarks)
directory validates the analyzer against real Ada/SPARK codebases rather than
hand-constructed fixtures. It holds three kinds of validation:

- **Independent-oracle comparisons** — on a SPARK corpus GNATprove can fully
  prove, GNATprove's verdict is ground truth. Every obligation both tools
  evaluate at the same `(file, line, check kind)` is compared, and in
  particular whether AdaLang ever calls something safe that GNATprove could
  not prove (possible unsoundness) or a definite error that GNATprove proved
  safe (false positive).
- **Real-code validation** where GNATprove cannot serve as an oracle — an
  ordinary non-SPARK codebase, or a SPARK corpus with genuine unresolved
  findings of its own — exercising breadth and specific checks that synthetic
  fixtures do not reach.
- **GNATcheck oracle comparison** — for the AdaLang rules with a direct
  GNATcheck counterpart, GNATcheck's findings on the same corpus become
  ground truth for potential false positives and false negatives. See the
  [GNATcheck rule comparison](gnatcheck-rule-comparison.md) for the rule
  mapping.

Each benchmark is a `run.sh` plus a `README.md` (setup, toolchain notes,
pinned revision) plus a dated `RESULTS_*.md` (latest run only; see `git log`
for prior snapshots).

**Read it:**
[`benchmarks/README.md`](https://github.com/mmartign/AdaLang_Analyzer/blob/main/benchmarks/README.md)
— methodology, pinned revisions, per-corpus results, and limitations.

## Quality — the current release's precision evidence

The [`quality/`](https://github.com/mmartign/AdaLang_Analyzer/tree/main/quality)
directory carries the per-release gate: the boundary-case precision corpus,
adversarial verification mutations, proof-path evidence, the reviewed
baseline, the known-false-positive / known-false-negative register, the
per-check tool-function validation manifest behind the
[tool-function validation evidence](tool-qualification-support.md) page, and
the release metrics tracked over time.

**Read it:**
[`quality/README.md`](https://github.com/mmartign/AdaLang_Analyzer/blob/main/quality/README.md)
— what each artifact is and how it is maintained.
