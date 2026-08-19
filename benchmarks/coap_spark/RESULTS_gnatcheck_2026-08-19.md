# coap_spark: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Sixth run of the GNATcheck oracle comparison (after sparknacl, aws,
gnatcoll-core, ada_drivers_library, cubedos). Second fully-SPARK corpus
after sparknacl, but structurally very different: most of its 85 files are
RecordFlux-generated protocol message parsers/encoders (heavy use of
case-expressions, `Depends` aspects, and machine-generated `goto`-based
state dispatch), not hand-written cryptographic arithmetic. Needed a real,
previously-undocumented environment fix before either lane could run at
all.

## Environment

- Corpus: mgrojo/coap_spark at `2fa345b8c70d621287b932aee7ea39b3520a5adf`
  (`COAP_SPARK_REVISION`) with wolfssl submodule at
  `59f4fa568615396fbf381b073b220d1e8d61e4c2`, `coap_spark.gpr` scope (85
  files, matching `README.md`'s own count; `analyzedFiles` in AdaLang's
  own JSON output confirms 85).
- AdaLang Analyzer: commit `8cb0553be2bb5c041cf2ec3a5271b8b52cad1a44`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged. `recursive_subprograms`/
  `No_Recursion` excluded as in every prior run.
- Reproduce: `COAP_SPARK_ROOT=<checkout> COAP_SPARK_SPARKLIB=<alr-get'd
  sparklib=16.1.0 dir> GNATCHECK_ENV=<env.sh>
  benchmarks/coap_spark/run_gnatcheck.sh`.

## Environment fix required beyond what README.md documents

`benchmarks/coap_spark/README.md`'s "Toolchain override" section describes
pointing `GPR_PROJECT_PATH` at a standalone `alr get sparklib=16.1.0`
crate, ahead of `coap_spark_root`, so `with "sparklib.gpr";` in
`coap_spark.gpr` resolves to that FSF-16-compatible copy instead of the
pinned checkout's own 14.1.1-era wrapper (which fails to load:
`"extended project file sparklib_external.gpr not found"`). On this
machine's current `alr`/`gpr2` versions, that override alone is not
sufficient: **directory-less `with` clause resolution checks the with-ing
project's own directory before ever consulting `GPR_PROJECT_PATH`**,
confirmed by direct experiment (`gprls` and `adalang_analyzer` both fail
identically and deterministically with `GPR_PROJECT_PATH` set exactly per
the README). Since `coap_spark_root` itself already contains its own
`sparklib.gpr`, it always wins regardless of `GPR_PROJECT_PATH` ordering —
this is not the intermittent/order-sensitive behavior the README's
phrasing implies, it is 100% reproducible on this environment.
`run_gnatcheck.sh` works around this by moving the pinned checkout's own
`sparklib.gpr` aside (to `sparklib.gpr.orig`) once, idempotently, before
either lane runs — `coap_spark_root` is a throwaway `/private/tmp` clone,
not this repository or a protected benchmark directory, so this does not
touch anything covered by the "do not modify" boundaries for this task.
**This is worth a maintainer's attention**: either `alr`/`gpr2` behavior
has changed since the README was written (most likely — a plausible
environment-drift regression, not a one-time fluke) or the original
recorded runs (`RESULTS_2026-08-08.md` through `RESULTS_2026-08-13.md`)
relied on a different local `sparklib.gpr` state that was never
documented. `benchmarks/coap_spark/run.sh` (the GNATprove-comparison
runner) was not modified and will hit the same failure unmodified on this
environment — not fixed here, since editing it wasn't part of this task,
but flagged since it affects reproducibility of the existing GNATprove
results too, not just this new GNATcheck lane.

## Run completeness: clean, no crash

`gnatcheck.status` is `1` — no `STORAGE_ERROR` stack overflow this run,
unlike AWS/ada_drivers_library/cubedos. The largest corpus by finding
volume so far (7,629 mapped GNATcheck findings) completed without incident.

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 779 | |
| &nbsp;&nbsp;matched by GNATcheck | 641 | 82.3% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 138 | 17.7% |
| GNATcheck findings (mapped rules) | 7629 | |
| &nbsp;&nbsp;matched by AdaLang | 641 | 8.4% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 6988 | 91.6% |

Full per-rule table: `benchmark-results/coap_spark/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

The GNATcheck-side match rate is the lowest of any corpus so far (8.4%),
almost entirely explained by two effects below at unusually large scale,
not a new class of disagreement.

## Confirms prior runs' effects, at much larger scale

**Non-statement boolean-expression scope, `Non_Short_Circuit_Condition`/
`non_short_circuit_operators` (13 matched / 3231 GNATcheck-only — 46% of
this run's entire GNATcheck-only total by itself).** Same root cause
sparknacl's run established (AdaLang scoped to `if`/`elsif`/`exit when`/
`while` statement conditions only), but the generated form here is
different: RecordFlux's generated `Valid`/`Invalid`/`Has_Buffer`-style
accessor functions return large `case`-expression bodies chaining `and`/
`or` between boolean function calls (e.g.
`rflx-coap-coap_message.adb:89-91`), not `Pre =>`/`Post =>` contract
aspects. Same scope decision, much bigger manifestation given how much of
this corpus is generated accessor code.

**Naming-length scope split, `Naming_Convention`/`min_identifier_length`
(18 matched / 1852 GNATcheck-only, the single largest raw GNATcheck-only
count of any rule in any run so far).** Consistent direction with prior
runs (GNATcheck doesn't exempt loop indices; RecordFlux-generated code
uses very short field/cursor names extensively), not independently
re-verified example-by-example given the volume — flagged as "same
pattern, bigger corpus" rather than re-derived from scratch.

**Library-closure scope: GNATcheck also reports on `sparklib`'s own
bundled sources.** `subprogram_access`/`No_Access_To_Subp_Def`: AdaLang
found **zero** on this corpus; GNATcheck found 179, all traced to
`spark-containers-functional-*` and similar files under the overridden
`sparklib` crate deployed for this run — SPARKlib's own sources, not
coap_spark's. `README.md`'s own "Scope" section already documents that
AdaLang's `-P` analyzes only a project's own declared `Source_Dirs`, not
transitively-`with`ed library projects, while GNATcheck (like AWS's own
run found for `templates_parser`) analyzes the full project closure by
default. Same explained effect as AWS's completeness note, confirmed here
by checking the file paths directly rather than assumed.

## New finding: `Depends`-without-`Global` split on `spark_procedures_without_globals`

`Missing_Global_Contract`: 24 AdaLang findings, 0 matched.
`spark_procedures_without_globals`: 371 GNATcheck findings, 0 matched —
290 of them outside `sparklib`'s own sources (mostly RecordFlux-generated
`rflx-*.ads` specs and the `wolfssl` Ada binding). Investigated one
directly: `rflx-coap-coap_message.ads:73`'s `procedure Initialize` has an
explicit `Depends =>` aspect (`Ctx => (Buffer, Written_Last), Buffer =>
null`) but no explicit `Global` aspect — legal SPARK, since `Global` can be
inferred from `Depends`. GNATcheck's `spark_procedures_without_globals`
still flags it (it requires an explicit `Global` aspect specifically);
AdaLang's `Missing_Global_Contract` does not, evidently treating an
explicit `Depends` aspect as adequate contract documentation on its own.
This is a specific, previously-undocumented variant of the general
"different checks, different definition of 'has adequate contract'"
family (same shape as AWS's `Exception_Propagation` Finding 2 and the
already-resolved `Missing_Global_Contract`/SPARK-readiness question from
AWS Finding 3, but a different mechanism from both) — not confirmed
against either tool's own documentation, worth a maintainer look if this
pairing's "close" label is revisited.

## Strongest match of any run so far: `No_Goto`/`goto_statements`, 100%/100% at real volume

136 AdaLang findings, 136 GNATcheck findings, **every one matched on both
sides** — the first rule pair in six runs to reach 100% in both
directions at meaningful volume (prior 100%-AdaLang-side results were all
at low GNATcheck-side volume, e.g. AWS's 112-finding
`No_Access_To_Subp_Def`). RecordFlux's generated parser state machines
make heavy, idiomatic use of `goto` for verification-friendly control
flow, giving this direct-match rule pair its first genuinely large,
completely clean sample.

## Caveats

- **Environment fix (`sparklib.gpr` relocation) is a deviation from
  README.md's documented setup**, done only to this throwaway clone, not
  committed anywhere — see above; worth revisiting whether the documented
  GNATprove-comparison setup is still reproducible as written.
- **Line-granularity matching**, **rule pairs are name-level, not
  proven-semantically-equivalent**, and **project-closure scope
  differences between the two tools' default behavior** (see above) —
  same caveat family as every prior run, all confirmed present here too.
- Per `benchmarks/coap_spark/README.md`, GNATprove itself is not a fully
  trustworthy oracle on this corpus even for the (separate) `--verify`
  comparison — not directly relevant to this GNATcheck-oracle run, but
  worth keeping in mind alongside it.
