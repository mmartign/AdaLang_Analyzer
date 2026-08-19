# Ada_Drivers_Library: AdaLang Analyzer vs. GNATcheck (rule-oracle comparison)

Fourth run of the GNATcheck oracle comparison (after sparknacl, aws,
gnatcoll-core). The first run against embedded, register-level, real
tasking driver code with no GNATprove/SPARK counterpart at all, and the
first that needed a genuine methodology adaptation before GNATcheck could
run at all: this corpus has no single project file GNATcheck can load.

## Environment

- Corpus: AdaCore/Ada_Drivers_Library at
  `81c04806d267fc12116a6f746c8e05012cef0484` (`ADL_REVISION`), 90
  `.adb`/`.ads` files under `arch/ARM/STM32/drivers/`.
- AdaLang Analyzer: commit `8cb0553be2bb5c041cf2ec3a5271b8b52cad1a44`.
- GNATcheck: `gnatcheck 27.0w`, same from-source local build as prior runs.
- Rule map / comparator: `benchmarks/gnatcheck_rule_map.tsv` /
  `benchmarks/gnatcheck_compare.awk`, unchanged. `recursive_subprograms`/
  `No_Recursion` excluded as in every prior run.
- Reproduce: `ADL_ROOT=<checkout> GNATCHECK_ENV=<env.sh>
  benchmarks/ada_drivers_library/run_gnatcheck.sh`.

## Methodology adaptation required: GNATcheck needs two synthetic projects, not one

`benchmarks/ada_drivers_library/README.md` already documents that this
corpus has no project file of its own; AdaLang works around that by taking
the flat 90-file list directly on the command line (Libadalang's file-list
unit provider). GNATcheck has no equivalent no-project multi-file mode that
actually works here: `--no-project` combined with `-files=`/`-U` reported
every file as "not in the analyzed project closure" and processed nothing,
and a single synthetic GPR project with `Source_Dirs => (".../drivers/**")`
fails outright at project-load time with "The source with basename ...
appears multiple times" — this driver tree deliberately holds six
mutually-exclusive board-variant directory pairs that redeclare the same
package under the same basename (`crc_stm32f4`/`crc_stm32f7`,
`devid_stm32f4`/`devid_stm32f7`, `dma`/`dma_stm32f769`,
`i2c_stm32f4`/`i2c_stm32f7`, `power_control_stm32f4`/
`power_control_stm32f7`, `sd/sdio`/`sd/sdmmc`), which a GNAT project
closure cannot contain simultaneously (Ada's compilation model requires
unique basenames per closure; Libadalang's file-list provider has no such
restriction, which is exactly why AdaLang's approach works and GNATcheck's
project-based one doesn't).

Fixed by hand-partitioning the 90 files into two disjoint GPR projects: set
A takes one member of each of the six variant pairs (plus every unpaired
directory and the top-level files), set B takes the other member of each
pair. Verified by diffing the reconstructed file list against a flat `find`
listing that the partition is exact — no file omitted, none duplicated.
`run_gnatcheck.sh` generates both projects into `$RESULTS_DIR` and runs
GNATcheck once per project, concatenating the two `gnatcheck.txt` outputs,
so every file gets exactly one GNATcheck pass, matching AdaLang's single
combined run. This is a real, corpus-specific adaptation (not a template
change) — every prior corpus had a real project file GNATcheck could load
directly.

## Run completeness: two per-file crashes, processing continued afterward

`gnatcheck.status` is `2` for both project variants. Two distinct issues,
both worth separating from genuine tool disagreement:

1. **`too_many_dependencies` (mapped to `Dependency_Limit`) errors
   internally on nearly every file** (`internal issue at
   too_many_dependencies.lkql:12:11: Null receiver in dot access`, 39
   occurrences, plus 2 on `controlled_type_declarations`). Root cause:
   this corpus intentionally only includes `arch/ARM/STM32/drivers/`, not
   the rest of the library tree its sources `with` — `hal.ads`,
   `hal-gpio.ads`, `stm32_svd.ads`, `stm32_svd-rcc.ads`, and 40+ other
   units are unresolvable (`cannot find ...` warnings, 1562 of them across
   both variants). GNATcheck's dependency-counting rule appears unable to
   tolerate an unresolvable `with` and throws rather than degrading;
   AdaLang's `Dependency_Limit` found 0 on this corpus too, so the pair
   reads as `n/a`/uninformative here regardless of tool, not a
   disagreement — this is an inherent limitation of analyzing a driver
   subtree in isolation, present for both tools, not a GNATcheck defect
   specific to this run.
2. **`STORAGE_ERROR: stack overflow`**, the same crash class already seen
   on AWS's run (`"unparsable worker output"`), once in each project
   variant. Unlike AWS, where the crash appeared to end the whole
   invocation, here file processing visibly continued afterward in the
   log (51+ more files with violations recorded past the first crash) —
   consistent with `-j` parallel worker processes, where one worker's
   crash doesn't kill the batch. The crashed file(s) could not be
   conclusively isolated from the interleaved parallel output (same open
   problem as AWS: "exact trigger still unidentified"), but the run reads
   as complete or very close to it, unlike AWS's "cut short near the end."

## Totals (31 AdaLang rules / 34 GNATcheck rules)

| | Count | |
| --- | ---: | --- |
| AdaLang findings (mapped rules) | 849 | |
| &nbsp;&nbsp;matched by GNATcheck | 367 | 43.2% |
| &nbsp;&nbsp;AdaLang-only (potential false positive) | 482 | 56.8% |
| GNATcheck findings (mapped rules) | 943 | |
| &nbsp;&nbsp;matched by AdaLang | 367 | 38.9% |
| &nbsp;&nbsp;GNATcheck-only (potential false negative / miss) | 576 | 61.1% |

Full per-rule table: `benchmark-results/ada_drivers_library/gnatcheck-comparison.txt`
from the run this document reports (not committed — `benchmark-results/`
is git-ignored; re-run the script to regenerate it).

## Confirms the same two reporting-convention effects seen on AWS and gnatcoll-core

**Spec/body split, `Too_Many_Parameters`/`maximum_parameters` (20 vs. 79
findings, 20% AdaLang-side match).** Same pattern as AWS Finding 1 and
gnatcoll-core Finding 1: GNATcheck's `maximum_parameters` fires separately
on both the `.ads` declaration and the `.adb` body of the same overloaded
subprogram set (e.g. `stm32-dac.ads:96`, `:109` alongside
`stm32-dac.adb:103`, `:146`, `:210`), while AdaLang reports mostly at the
body. Confirmed, not re-investigated in depth — same conclusion as the
prior two runs.

**Subprogram-level vs. statement-level granularity, `No_Multiple_Return`/
`improper_returns` (71 vs. 340 findings, 3% AdaLang-side match).** Same
pattern as gnatcoll-core's Finding 2: AdaLang reports once per subprogram
(e.g. `stm32-dma.adb:361`), GNATcheck reports once per excess `return`
statement, producing a much larger raw count and near-zero line-exact
overlap despite substantive agreement. `null_paths` (`Empty_If_Body`) shows
a related shape (50 GNATcheck findings, 0 AdaLang-mapped matches — `Empty_
If_Body` itself found 0 on this corpus) — not investigated further given
low volume.

## What matched cleanly (with real tasking exercised for the first time)

`subprogram_access` (`No_Access_To_Subp_Def`): 100% AdaLang-side match at
low volume (1/1). `Non_Short_Circuit_Condition`: 80% AdaLang-side match
(10 findings, 2 unmatched) — the strongest showing for this pair across
all four runs so far, on real (non-contract) conditional code. This is
also the first corpus with genuine `protected`/`entry` tasking constructs
(`arch/ARM/STM32/drivers/`'s DMA/RNG/SD/LTDC interrupt handlers, per
`README.md`) — none of the concurrency-prohibition checks
(`No_Tasking`/`No_Rendezvous`/`No_Select`/`No_Requeue`/
`No_Asynchronous_Transfer`/`Potentially_Blocking_Operation`) are in the
GNATcheck rule map (`GNATCHECK_RULE_COMPARISON.md` has no GNATcheck
counterpart documented for them), so this run doesn't add oracle evidence
for those checks specifically — that validation already happened via
manual review in `RESULTS_2026-08-05.md`, not GNATcheck cross-checking.

## Caveats

- **Two synthetic, hand-built GPR projects, not one, unlike every prior
  corpus** (see above) — a real, load-bearing adaptation specific to this
  corpus's variant-directory structure, not a template change.
- **`Dependency_Limit`/`too_many_dependencies` is uninformative here** (see
  Run completeness) — both tools effectively report nothing meaningful for
  this pair on this corpus, not a genuine agreement or disagreement.
- **Run completeness not independently re-confirmed**, same caveat as AWS:
  two per-file crashes occurred, processing appears to have continued past
  them, but this was not re-run to verify determinism or exact
  completeness.
- **Line-granularity matching** (see sparknacl/AWS/gnatcoll-core
  `RESULTS_*.md`) applies here too, and interacts with both the spec/body
  split and the subprogram/statement granularity split documented above.
- Same rule-map caveats as every prior run: `No_Pragma`/`Forbidden_Pragmas`
  excluded, rule pairs are name-level matches from
  `GNATCHECK_RULE_COMPARISON.md`, not proven semantic equivalence.
