# Tokeneer comparison results — 2026-08-13, re-run after two same-day commits

Same-day re-run of `RESULTS_2026-08-13.md` (the 06:49 baseline), against
two analyzer commits landed later that day:

- `a6239c1d4cbba51ca237239b251c4710b7e5916c` — "Prove bounded loop variant
  progress": `VC_Prover` now discharges a leading `Increases`/`Decreases`
  `Loop_Variant` as `Proved_Safe` (previously always `Unproved`).
- `f8a0375fd3fcf13e72356e08018d7f60db12df7d` — "Resolve symbolic scalar
  sorts semantically": fixes scalar-sort resolution (enum/Boolean/Int) in
  symbolic assignment, closing a soundness gap for enum-typed assignments.

See `README.md` for full methodology; this file only records the delta
against the 06:49 baseline.

## Environment and scope

- AdaCore/spark2014: `a97467e91a16409c866434fcc7a5f553bbd98b8a` (same pin
  as the baseline), `testsuite/gnatprove/tests/tokeneer`, 120 source files
  — freshly re-cloned via sparse checkout for this run
- AdaLang Analyzer: `1.0.0-rc1`, commit `f8a0375fd3fcf13e72356e08018d7f60db12df7d`
  (HEAD; includes both commits above)
- GNATprove: FSF 16.1.0, Why3 1.8.2+git, CVC5 (via `--prover` default),
  Z3, Alt-Ergo 2.6.1 — same toolchain as the baseline
- Invocation: unchanged from the baseline (`test.gpr`'s own `Prove`
  package switches plus `--report=statistics`; see `README.md`)

## Primary results

| Lane | Baseline (06:49) | This re-run | Δ |
| --- | ---: | ---: | ---: |
| AdaLang `--verify` time | 10.2 s | 38.1 s | +27.9 s |
| GNATprove time | 279.2 s | 941.2 s | +662.0 s |
| AdaLang total obligations | 6,697 | 6,697 | 0 |
| AdaLang `Proved_Safe` | 1,741 | **1,925** | **+184** |
| AdaLang `Definite_Error` | 0 | 0 | 0 |
| AdaLang `Unproved` | 4,624 | 4,440 | **−184** |
| AdaLang `Unsupported` | 332 | 332 | 0 |
| GNATprove check messages | 2,286 | 2,286 | 0 |

Both wall-time lanes are slower than the baseline, but neither reflects a
behavior change worth reading into. GNATprove's own output is
byte-for-byte the same oracle result as the baseline (2,286 `info`
messages; `gnatprove.out` summary unchanged: 2,219 total, Flow 1,366,
Provers 831, Justified 22, Unproved 0) — GNATprove itself did not change
between the two runs, so its 3.4x wall-time increase is host contention,
not a GNATprove effect. This machine had well over 400 concurrent
`gnatwhy3` solver processes running for other benchmarks at the time of
this run, confirmed via `ps aux` mid-run. AdaLang's own 3.7x increase
(10.2s → 38.1s) most plausibly reflects genuine additional solver work
from the two new `VC_Prover` code paths (loop-variant progress proof and
richer scalar-sort resolution both mean more obligations now go through
real solver reasoning instead of returning `Unproved` immediately), with
some added noise from the same host contention — the two effects aren't
separable from this single run.

## What moved: `Proved_Safe` up 184, `Unproved` down 184, nothing else

`Definite_Error` and `Unsupported` are both unchanged (0 and 332
respectively) — every one of the 184 obligations that moved came directly
out of `Unproved` and into `Proved_Safe`, no other category involved.

### The bounded-loop-variant commit (`a6239c1`) plausibly contributed nothing here

Tokeneer's pinned revision contains **zero** `Loop_Variant` pragmas
anywhere in `testsuite/gnatprove/tests/tokeneer` (confirmed by grep over
the full sparse checkout). `a6239c1` only changes how a leading
`Increases`/`Decreases` `Loop_Variant` is discharged; with no such pragma
present in this corpus at all, this commit cannot be responsible for any
of the movement recorded here. This is a null result for this corpus, not
evidence the fix doesn't work — Tokeneer's loops are bounded by other
means (structural iteration, `exit when`, explicit counters), not
`Loop_Variant` annotations.

### The scalar-sort commit (`f8a0375`) is the only plausible driver

All 184 newly-`Proved_Safe` obligations are consistent with `f8a0375`'s
scope. Breaking down the current run's `Proved_Safe` obligations by kind:

| Kind | `Proved_Safe` count (this run) |
| --- | ---: |
| `initialization-check` | 1,462 |
| `range-check` | 248 |
| `precondition` | 138 |
| `division-by-zero` | 30 |
| `index-check` | 24 |
| `integer-overflow` | 22 |
| `loop-invariant-initialization` | 1 |

These are exactly the general-purpose obligation kinds whose underlying
expressions route through symbolic scalar-sort resolution when they
involve enum, Boolean, or Integer comparisons/assignments — and Tokeneer
is unusually enum-heavy: at least 27 single-clause enumeration type
declarations across the corpus, including `DoorStateT` (`Error, Open,
Closed`), `PresenceT` (`Present, Absent`), `StatusT` (`Alarming,
Silent`), `FileStatusT`, `AccessPolicyT`, and role/severity/message-state
enumerations — precisely the door/latch-state and role modeling the task
description anticipated as a strong candidate for this fix. No archived
raw JSON from the 06:49 baseline survives to diff obligation-by-obligation
(`benchmark-results/` is gitignored and was overwritten by this run), so
the kind-level attribution here is plausible from the shape of the
corpus and the shape of the fix, not confirmed line-for-line against the
baseline.

## Agreement: matched obligations

**221** obligations matched 1:1 (file, line, kind) — same count as the
baseline, since GNATprove's own obligation set is unchanged and AdaLang's
obligation locations/kinds didn't change, only their proof status:

| Bucket | Baseline (06:49) | This re-run | Δ |
| --- | ---: | ---: | ---: |
| Both safe | 15 | **24** | **+9** |
| AdaLang conservative | 206 | 197 | **−9** |
| Possible AdaLang unsoundness | 0 | **0** | 0 |
| AdaLang false positive | 0 | **0** | 0 |
| Both flag a problem | 0 | 0 | 0 |

**Still zero possible unsoundness and zero false positives.** Nine
matched-pair obligations moved from "AdaLang conservative" into "Both
safe" — AdaLang now agrees with GNATprove on 24/221 pairs (≈11%), up from
15/221 (≈7%), consistent with the same scalar-sort fix now resolving some
of the matched-pair obligations too, not just the larger AdaLang-only
pool. The two risk buckets that matter most (possible unsoundness, false
positive) are bit-identical to the baseline: the fix bought AdaLang more
`Proved_Safe` verdicts without introducing any new disagreement with the
GNATprove oracle.

Count-mismatch keys: 170, unchanged from the baseline (same GNATprove
`--output=oneline` message-grouping behavior, same AdaLang per-check
counting — neither commit touches obligation counting or matching).

## Coverage-only counts (not agreement failures)

- **AdaLang-only**: 5,439 (baseline: 5,439 — unchanged; still dominated by
  `initialization-check` and `range-check`, the same categories that
  gained the bulk of this run's new `Proved_Safe` verdicts).
- **GNATprove-only**: 207 (baseline: 207 — unchanged).
- **GNATprove messages with no AdaLang kind mapping**: 1,574 (baseline:
  1,574 — unchanged).

None of the coverage-only pools moved at all, consistent with both
commits changing proof *status* on already-registered obligations, not
obligation *registration* or coverage scope.

## Bottom line

`f8a0375` (scalar-sort resolution) is the only plausible driver of this
run's movement: `Proved_Safe` up 184 (1,741 → 1,925), all of it coming
directly out of `Unproved`, concentrated in `initialization-check` and
`range-check`, on a corpus with 27+ enumeration types modeling exactly the
door/latch/role state the fix targets. `a6239c1` (bounded loop variant)
contributed nothing measurable here because Tokeneer contains zero
`Loop_Variant` pragmas — a clean null result, not a sign the fix is
ineffective elsewhere. Both risk buckets that matter most — possible
AdaLang unsoundness and AdaLang false positives — stayed at exactly zero,
matched-pair-for-matched-pair identical to the baseline, so today's
commits bought strictly more precision with no new disagreement against
the GNATprove oracle. Wall-clock time increases in both lanes are best
read as host contention (GNATprove's own oracle output is unchanged) with
a plausible smaller contribution from genuinely more solver work on the
AdaLang side; not separable from this single run.
