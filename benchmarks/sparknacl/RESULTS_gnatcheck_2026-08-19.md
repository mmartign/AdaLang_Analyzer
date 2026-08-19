# SPARKNaCl: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

First real (not documentation-only) run of the GNATcheck oracle comparison
tracked as an open item in `AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md`'s gap
register and prepared for in `GNATCHECK_RULE_COMPARISON.md`. This compares
actual findings, not rule catalogs, using GNATcheck as ground truth (it is
AdaCore's own, mature, widely-used rule-based linter) for the 31 AdaLang
rules (of 32 documented direct/close matches) that could be tested this run.

## Environment

- Corpus: rod-chapman/SPARKnaCl at `49e3bddf092561ce2b74c134a35acff91a2da9a4`
  (pinned, `SPARKNACL_REVISION`), 119 source files.
- AdaLang Analyzer: commit `563dca1a2cbf221d471d5a5b9d10469384731a8b` (this
  repository's `HEAD` at run time).
- GNATcheck: `gnatcheck 27.0w`, built from source (no AdaCore account/
  license used) per `benchmarks/README.md`'s tool-availability note; the
  full build recipe and every macOS-specific workaround it needed live in
  this session's memory (`project_gnatcheck_acquisition.md`) since there is
  no Alire package or prebuilt download for it. **This binary exists only
  on the machine it was built on** (`~/gnatcheck-build`, ~300MB, local-only,
  not committed anywhere) -- reproducing this run elsewhere means rebuilding
  it from scratch, which is a real multi-hour undertaking, not a quick step.
- Rule map: `benchmarks/gnatcheck_rule_map.tsv`, derived from
  `GNATCHECK_RULE_COMPARISON.md`'s direct/close tables, expanded to 39
  individual (AdaLang rule, GNATcheck rule) pairs across 31 AdaLang rules
  (`No_Pragma`/`Forbidden_Pragmas` excluded: GNATcheck's rule needs an
  explicit configured pragma list to fire at all, which is a policy
  decision, not a rule-name mapping -- left for a future run).
- Comparator: `benchmarks/gnatcheck_compare.awk`, matching on
  `(basename(file), line, rule pair)` -- same line-granularity convention as
  the existing GNATprove `compare.awk` (not column-level; two violations of
  the same rule on one line collapse to a single matched/unmatched key).
- Reproduce: `SPARKNACL_ROOT=<checkout> GNATCHECK_ENV=<path to the built
  gnatcheck's runtime env.sh> benchmarks/sparknacl/run_gnatcheck.sh`.
  Verified deterministic across two consecutive runs (identical counts on
  every rule) once invoked through the script; an earlier ad hoc manual
  invocation from a different working directory produced different counts
  for a few rules, so **only script-driven runs from a fixed cwd should be
  trusted** -- root cause not fully isolated, noted as an open caveat below.

## Known limitation: `recursive_subprograms` excluded

GNATcheck's `recursive_subprograms` (paired with AdaLang's `No_Recursion`)
does whole-program call-graph analysis and reliably crashes this
from-source build with `STORAGE_ERROR: stack overflow` in the Ada driver,
even at the maximum `ulimit -s` macOS allows (63.9MB). Isolated by testing
it alone: `exception_propagation_from_callbacks`, the map's other
"(global analysis required)" rule, runs fine alone, so the crash is
specific to `recursive_subprograms`, not global-analysis rules generally.
Both `No_Recursion` and `recursive_subprograms` are excluded from this run
(and from the totals below) rather than silently reporting zero. This is a
defect in *this build*, not evidence about either tool's rule logic.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 1557 | |
| &nbsp;&nbsp;matched by GNATcheck | 1334 | 85.7% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 223 | 14.3% |
| GNATcheck findings (mapped rules) | 1758 | |
| &nbsp;&nbsp;matched by AdaLang | 1334 | 75.9% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 424 | 24.1% |

Full per-rule table: `benchmark-results/sparknacl/gnatcheck-comparison.txt`
from the run this document reports (not committed -- `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

## What actually explains the gap (not a coverage failure)

Investigated the three largest divergences directly against SPARKNaCl's
source before writing anything below -- these are documented, defensible
scope/policy differences discovered *by running both tools*, which is
exactly the value a documentation-only comparison can't produce.

**`Non_Short_Circuit_Condition` vs. `non_short_circuit_operators` (1
matched / 178 GNATcheck-only, 99% of this run's GNATcheck-only findings on
just this pair).** AdaLang's check is deliberately scoped to `if`, `elsif`,
`exit when`, and `while` *statement* conditions (confirmed against its own
`-list-checks` description). GNATcheck's flags predefined `and`/`or`
between Boolean operands *anywhere*, including in `Pre =>`/`Post =>`
contract aspects -- e.g. `sparknacl-aes.adb:25`,
`Pre => (Output'First = State'First) and (State'First = 0)`, which
GNATcheck flags and AdaLang does not, by design. This is the single
largest contributor to the false-negative count, and it's a scope
decision, not a bug: whether contract-aspect `and`/`or` deserves the same
treatment as executable-code conditions is a legitimate open question
(SPARK preconditions are expected to be side-effect-free, which weakens
but doesn't eliminate the short-circuit-evaluation argument for them).

**`Naming_Convention` vs. `min_identifier_length` (bidirectional gap: 120
AdaLang-only, 205 GNATcheck-only).** Two distinct scope differences found
by inspecting specific mismatches:
- AdaLang explicitly exempts loop-index variables (`-list-checks`: "outside
  conventional loop-index declarations... single-letter loop indices
  remain permitted"). GNATcheck's `min_identifier_length` does not exempt
  them -- e.g. `for I in Ci'Range loop` at `sparknacl-aes.adb:82` is flagged
  by GNATcheck, not AdaLang. This is most of the 205 GNATcheck-only count.
- Conversely, AdaLang flags single-character *formal parameter* names (e.g.
  `function GF2p2p2p2_Inverse (X : in U32) return U32` at
  `sparknacl-aes.adb:32`) that GNATcheck's `min_identifier_length` does not
  flag at that location at all -- parameters appear to be outside that
  rule's scope. This is most of the 120 AdaLang-only count.
- Net: the two tools are checking different, only partially-overlapping
  populations of "short identifier," not one being a strict subset of the
  other.

**`Too_Many_Parameters`/`Cyclomatic_Complexity` vs. `maximum_parameters`/
`metrics_cyclomatic_complexity` (default-threshold mismatch, not a logic
gap).** GNATcheck's `maximum_parameters` default threshold is 3 (flags
subprograms with 4+ parameters); AdaLang's default `-parameter-threshold`
is 6 (flags 7+). Every one of the 22 `maximum_parameters` GNATcheck-only
findings is a subprogram with 4-6 parameters -- exactly the band AdaLang's
default doesn't reach. Not run with matched thresholds this time (`-r
maximum_parameters=N` vs. `-parameter-threshold=N` would need to agree);
left as a follow-up for an apples-to-apples second pass. Cyclomatic
complexity shows the same shape at a smaller scale (7 GNATcheck findings,
6 unmatched).

**`Magic_Number` vs. `numeric_literals` (91% agreement, the largest clean
pair)** and **`min_identifier_length`/`Naming_Convention`'s matched core**
are the strongest positive signal in this run: on a large, high-volume,
non-threshold-configurable rule pair, the two independently-implemented
tools agree at high volume, which is meaningful corroboration for both.

## Caveats

- **Run-to-run reproducibility**: confirmed identical results across two
  consecutive script-driven runs from the repository root; an earlier
  manual run (same rules, invoked from within the SPARKNaCl checkout
  directory rather than via the script) produced different counts on
  `non_short_circuit_operators` (191 vs. 178), `metrics_cyclomatic_complexity`
  (9 vs. 7), and `maximum_parameters` (27 vs. 22) -- all higher, i.e. that
  run found *more* violations, not fewer, so this isn't obviously partial/
  crashed output. Root cause not isolated (candidate: cwd-relative GPR
  object-directory reuse across the two invocation styles); until it is,
  treat only `run_gnatcheck.sh`-driven runs as the trustworthy baseline,
  and re-run twice before trusting a new number.
- **Line-granularity matching**: like the existing GNATprove `compare.awk`,
  this does not use column, so multiple same-rule violations on one line
  collapse to a single matched/unmatched key. This slightly inflates both
  match and miss rates versus true per-violation matching; not expected to
  change the qualitative conclusions above.
- **Rule pairs are name-level, not proven-semantically-equivalent** matches
  from `GNATCHECK_RULE_COMPARISON.md` -- see that document's own caveat
  that rule descriptions "were not cross-checked against the gnatcheck
  source." This run is the first real check of several of those pairings
  against actual behavior, and found the scope differences documented
  above.
- **One corpus, SPARK code**: SPARKNaCl is small (119 files), disciplined,
  fully-proved SPARK -- it has essentially zero `goto`/`abort`/recursion/
  controlled-type violations (many rule pairs show `n/a`, zero on both
  sides). A "real code" corpus (e.g. `benchmarks/aws` or
  `benchmarks/ada_drivers_library`) would exercise the direct-match rules
  this corpus left completely untested and is the natural next run.
- **`No_Pragma`/`Forbidden_Pragmas` excluded** (see Environment) --
  GNATcheck's rule needs an explicit pragma list, which is a policy
  decision this run didn't make.
