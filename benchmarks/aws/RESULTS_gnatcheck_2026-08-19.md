# AWS: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Second run of the GNATcheck oracle comparison (see
`benchmarks/sparknacl/RESULTS_gnatcheck_2026-08-19.md` for the first), and
the first on ordinary, non-SPARK, real-world Ada. This is the corpus that
actually exercises the direct-match rules SPARKNaCl left untested
(`No_Goto`, `No_Abort`, `No_Controlled_Type`, `No_Multiple_Return`, ...),
and it surfaced genuinely different, more consequential findings than the
first run: not scope nuances at the margins, but a systematic
reporting-location mismatch for one rule pair, a real scope-breadth
difference for another, and a design question worth a maintainer decision
in AdaLang itself.

## Environment

- Corpus: AdaCore/aws at `02cbd01c2f96c288440415a46bf865616c0ee0f8`
  (`AWS_REVISION`) with templates_parser submodule at
  `7c59ed4f1ee371c7d3f420b890e287b72c2473f4`, built per
  `benchmarks/aws/README.md` (`ENABLE_SHARED=false XMLADA=true LAL=false
  SOCKET=std`), same pinned configuration the GNATprove lane uses. 324
  `.adb`/`.ads` files under `src/`.
- AdaLang Analyzer: commit `793bd8934b55ab312aa0247003331ac4ad95ea22`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as the
  sparknacl run (see `project_gnatcheck_acquisition.md`).
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged from the first run.
  `recursive_subprograms`/`No_Recursion` still excluded (see below).
- Reproduce: `AWS_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/aws/run_gnatcheck.sh`.

## Infrastructure fix this run required (real, not corpus-specific)

The first (sparknacl) run's `run_gnatcheck.sh` sourced `GNATCHECK_ENV`
*before* running the AdaLang lane, and `env.sh` *prepended* its own
`GPR_PROJECT_PATH` entries. SPARKNaCl has no external project
dependencies, so this never surfaced a problem there. AWS's `src.gpr`
directly `with`s `gnatcoll_core.gpr`, and gnatcheck's build install
happens to also carry a same-named (but headers-stripped, runtime-only)
`gnatcoll_core.gpr`/`xmlada*.gpr` from its own from-source build (see
`project_gnatcheck_acquisition.md`) — with the old prepend order, GNATcheck
resolved AWS's real dependency to that broken stub instead of the proper,
full one `alr exec` already provides, and failed outright ("source file
... not found"). Fixed in both `run_gnatcheck.sh` scripts: run the
AdaLang lane under the plain `alr exec` environment first, and only
source `GNATCHECK_ENV` afterward with its own `GPR_PROJECT_PATH` entries
*appended* (lower priority) rather than prepended, so a real project's own
dependency resolution always wins over gnatcheck's internal, runtime-only
stubs. This is a durable fix, not an AWS-only workaround — it will matter
for any future corpus with its own gnatcoll-core/xmlada/etc. dependency.

## Known limitation carried over: `recursive_subprograms` excluded

Same as the sparknacl run: GNATcheck's `recursive_subprograms` (paired
with `No_Recursion`) crashes this from-source build's global call-graph
analysis. Excluded from both AdaLang and GNATcheck's rule sets for this
run, as before.

## Run completeness: crashed near the end, likely near-complete

GNATcheck exited status 2 (`STORAGE_ERROR: stack overflow`, same class of
crash as `recursive_subprograms`, but here on a *different*, unidentified
rule/file — the crash trace names no file). The last violations recorded
before the crash are in `zlib.ads`/`zlib.adb`; 242 distinct files got at
least one finding on the AdaLang side and 474 on the GNATcheck side (more
than AWS's own 324, since gnatcheck by default also reports on withed
units it's given visibility into, e.g. templates_parser's own sources).
Given the volume of output captured (11,796 GNATcheck violation lines)
and where it stops, this reads as a near-complete run cut short at or
after the last few files, not an early abort — but this was **not**
independently re-confirmed as file-complete the way sparknacl's run-to-run
stability was checked, so treat the totals below as solid but not
proven-exhaustive. Isolating which specific file/rule triggers this
second crash (distinct from `recursive_subprograms`) is unresolved.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 6288 | |
| &nbsp;&nbsp;matched by GNATcheck | 3294 | 52.4% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 2994 | 47.6% |
| GNATcheck findings (mapped rules) | 11356 | |
| &nbsp;&nbsp;matched by AdaLang | 3283 | 28.9% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 8073 | 71.1% |

Full per-rule table: `benchmark-results/aws/gnatcheck-comparison.txt` from
the run this document reports (not committed — `benchmark-results/` is
git-ignored; re-run the script to regenerate it).

**These raw totals are the least useful number in this document.** The
match rate looks far worse than SPARKNaCl's (85.7%/75.9%), but investigating
the three largest gaps shows most of the shortfall is not disagreement
about defects — it's two different, well-defined effects, one a
comparator/reporting-convention artifact and one a genuine, larger
scope difference than `GNATCHECK_RULE_COMPARISON.md`'s "Close" label
implied.

## Finding 1: spec/body reporting-location mismatch dominates `Too_Many_Parameters`/`maximum_parameters`

`Too_Many_Parameters`: 62 AdaLang findings, 0 matched. `maximum_parameters`:
597 GNATcheck findings, 0 matched. Investigated directly: `AWS.Digest`'s
`function Create (Username, Realm, Password : String; Nonce, NC, CNonce,
QOP : String; Method, URI : String) return Digest_String` has **both** a
declaration in `aws-digest.ads:56` and a completing body in
`aws-digest.adb:157`. GNATcheck flags the **specification**
(`aws-digest.ads:56:13`); AdaLang flags the **body**
(`aws-digest.adb:157`). Confirmed the same pattern on a second example
(`AWS.Client.HTTP_Utils.Internal_Post_Without_Attachment_1` and siblings,
flagged by GNATcheck at their `.adb`-file forward-declaration lines
60-180, never at their actual body lines). Both tools **agree these
subprograms have too many parameters** — they just cite different lines
for the same subprogram when it has a separate spec, which
`(basename(file), line, rule)` matching can't reconcile. `Internal_Post`
itself (no separate spec — a body-only local procedure, `aws-client-http_
utils.adb:850`) got zero GNATcheck coverage at all under this rule in
either location, suggesting GNATcheck's `maximum_parameters` may not
check body-only subprograms (no separate declaration) at all — confirmed
as a real, if narrower, scope gap distinct from the reporting-location
issue, not independently verified against GNATcheck's own documentation.
This single reporting-location effect plausibly accounts for most of both
rules' "0% matched" figure; the comparator's line-exact matching design
(shared with the GNATprove comparator) simply isn't built to reconcile it,
and fixing that would need cross-referencing declarations to bodies by
subprogram identity, not by line — a real follow-up for
`gnatcheck_compare.awk`, not attempted this run.

## Finding 2: `Exception_Propagation` is a materially broader check than its three GNATcheck counterparts

948 AdaLang findings for `Exception_Propagation`, 0 matched; the three
GNATcheck rules it's mapped to found 9 combined
(`exception_propagation_from_callbacks` 0, `_from_export` 4, `_from_tasks`
5). This is not a reporting-location artifact — confirmed against both
checks' own descriptions. AdaLang's `Exception_Propagation`: "Find calls
that can explicitly raise an exception when the enclosing subprogram
provides no exception boundary" — applies to **every** subprogram.
GNATcheck's three rules are explicitly scoped to three narrow structural
boundaries: callback parameters, `Export`ed subprograms, and task bodies
only. `GNATCHECK_RULE_COMPARISON.md` labeled this pairing "Close"; running
both tools shows the AdaLang side is closer to two orders of magnitude
broader in practice on real code. Not a defect in either tool — AdaLang is
deliberately checking a more general property (any unguarded exception
propagation) that happens to structurally overlap GNATcheck's three
specific cases, not a peer of them. Worth a note in
`GNATCHECK_RULE_COMPARISON.md` that this pairing understates the scope gap
more than the "Close" label for other rows there does.

## Finding 3: `Missing_Global_Contract` fires on code with zero `SPARK_Mode` markings — confirmed intentional, not a gap

827 AdaLang findings, 0 GNATcheck matches (GNATcheck's
`spark_procedures_without_globals` found 0 on this corpus at all). AWS has
**zero** `SPARK_Mode` occurrences anywhere in its `src/` tree (`grep -rl
SPARK_Mode` : no matches), yet `Missing_Global_Contract` fired 827 times.
Traced to `Effective_SPARK_Enabled` in
`src/adalang_analyzer-spark_readiness.adb`: when no `SPARK_Mode`
pragma/aspect is found anywhere in a subprogram's own declaration or its
full lexical-ancestor chain, the function's fallback (and its `others =>`
exception handler) both `return True` — i.e. code with **no SPARK
annotation anywhere** is treated as SPARK-enabled by default. This same
function gates six other checks (`Global_Contract_Mismatch`,
`Missing_Depends_Contract`, `Incomplete_Depends_Contract`,
`Uninitialized_Output`, `Aliasing_Between_Parameters`,
`Potentially_Blocking_Operation`).

**Investigated as a possible defect in a follow-up session and confirmed
intentional, not a gap.** `tests/run_bug_findings.sh` has a dedicated
regression block that runs `--spark` (and bare `-checks=`) on
`tests/spark_readiness_findings.adb` — a fixture with zero `SPARK_Mode`
markings, explicitly commented "positive regression fixture for SPARK
Bronze/**readiness** diagnostics" — and asserts `Missing_Global_Contract`
and its five siblings still fire. That is a deliberate, pre-existing test
proving the "readiness" framing: the check is meant to flag, on ordinary
Ada that has not yet adopted SPARK, what a Global contract would need to
say if it did — the tool nudging code toward SPARK adoption, not a
compliance check that only applies once adoption has already happened.
GNATcheck's `spark_procedures_without_globals`, by contrast, only examines
code already under `SPARK_Mode`; the two checks measure genuinely
different things by design, the same shape as Finding 2 above, not a
coverage gap. A code-level fix was attempted and reverted twice during
that follow-up session (first a shared-default flip, which broke 12
precision-corpus assertions across four unrelated checks; then a
narrower fix scoped to just `Missing_Global_Contract`, which still broke
the `run_bug_findings.sh` regression above) before this conclusion was
reached. Resolution: `-list-checks` wording for the four checks that
overclaimed "SPARK subprograms" (`Missing_Global_Contract`,
`Global_Contract_Mismatch`, `Missing_Depends_Contract`,
`Incomplete_Depends_Contract`) was corrected to describe the actual,
broader scope instead; no behavior changed.

## What matched cleanly

`Naming_Convention`/`min_identifier_length`: AdaLang 2809, GNATcheck 3722,
87%/66% match — the same loop-index/parameter-name split root-caused on
sparknacl, at real-code volume, no new surprises. `Magic_Number`/
`numeric_literals`: AdaLang 680, GNATcheck 2243, 89% AdaLang-side match —
consistent with sparknacl's 91%, the strongest reproducible positive
signal across both runs so far. `Cyclomatic_Complexity`/
`metrics_cyclomatic_complexity`: 81% AdaLang-side match, cleaner than
sparknacl's small-sample 33% — larger sample, same threshold-gap pattern,
no reporting-location issue (cyclomatic complexity is inherently a
body-only property, so the spec/body split from Finding 1 doesn't apply
here). `No_Access_To_Subp_Def`/`subprogram_access`: 100% AdaLang-side
match (112/112) — a completely clean direct-match rule at real volume,
the strongest exact-agreement result in either run.

## Caveats

- **Run completeness not independently re-confirmed** (see above) — this
  run was not repeated to check for the sparknacl-style run-to-run
  variance; treat the exact counts as approximate until a second
  script-driven run is compared against this one.
- **Line-granularity matching** (see sparknacl's `RESULTS_*.md`) applies
  here too, and interacts badly with Finding 1's spec/body split
  specifically — a subprogram flagged at two different lines by the two
  tools is invisible to this matching design regardless of file/rule
  volume.
- Same rule-map caveats as sparknacl's run: `No_Pragma`/`Forbidden_Pragmas`
  excluded, rule pairs are name-level matches from
  `GNATCHECK_RULE_COMPARISON.md`, not proven semantic equivalence.
