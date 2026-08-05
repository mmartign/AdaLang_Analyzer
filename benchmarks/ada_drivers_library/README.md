# Ada_Drivers_Library benchmark

This benchmark runs AdaLang Analyzer's `--recommended`, `--spark`, and
`--automotive` presets against a pinned subset of
[AdaCore/Ada_Drivers_Library](https://github.com/AdaCore/Ada_Drivers_Library)
(BSD-3, actively maintained): `arch/ARM/STM32/drivers/`, the shared STM32
peripheral driver tree used by every board in the library (90 files, ~26,300
lines).

Unlike the other benchmarks in this directory (`benchmarks/aws/`,
`benchmarks/sparknacl/`, `benchmarks/cubedos/`, `benchmarks/saatana/`), this
one is not a GNATprove oracle comparison -- bare-metal register-level driver
code is not a natural SPARK proof target and only 2 of the 90 files even set
`SPARK_Mode`. Its purpose instead is real-code validation for the
`--automotive`-only concurrency-prohibition checks (`No_Tasking`,
`No_Rendezvous`, `No_Select`, `No_Requeue`, `No_Asynchronous_Transfer`,
`Potentially_Blocking_Operation`), none of which had ever run against real
tasking/protected-object code before: `quality/precision_corpus.tsv`'s
fixtures for them are hand-constructed, and none of the other four
benchmarks' corpora use tasking at all. This one does: 7 files under
`arch/ARM/STM32/drivers/` declare `protected` types or objects for
interrupt-driven peripherals (DMA, RNG, SD/MMC, LTDC), the idiomatic
Ravenscar pattern of a hardware interrupt handler behind a protected
operation with an `entry` the foreground task blocks on.

## Pinned source

- AdaCore/Ada_Drivers_Library: `81c04806d267fc12116a6f746c8e05012cef0484`

Clone the corpus from the AdaLang Analyzer repository root:

```sh
git clone https://github.com/AdaCore/Ada_Drivers_Library.git \
  /private/tmp/adalang-adl-benchmark
git -C /private/tmp/adalang-adl-benchmark checkout \
  81c04806d267fc12116a6f746c8e05012cef0484
```

No build or setup step is needed. Unlike `benchmarks/aws/`, this benchmark
does not invoke a `-P` project at all: `arch/ARM/STM32/drivers/` has no
project file of its own (board-specific projects elsewhere in the library
pull it in alongside MCU/board scenario variables and an ARM cross
toolchain), and AdaLang only has to parse and check the sources, not build
them. Every `.ads`/`.adb` under the directory is passed directly on the
command line; Libadalang's file-list unit provider resolves the with-graph
among the files actually given, the same mechanism
`tests/run_circular_dependencies.sh` relies on for its own whole-program
check. A native host GNAT toolchain (for `gnatls`, so `Interfaces`/`System`
resolve -- see `FP-029`) is still required, the same as every other
benchmark here.

Run the benchmark:

```sh
ADL_ROOT=/private/tmp/adalang-adl-benchmark sh benchmarks/ada_drivers_library/run.sh
```

`run.sh` verifies the pinned revision, then runs AdaLang `--recommended`,
`--spark`, and `--automotive` against every file under
`arch/ARM/STM32/drivers/`, `--format=json`, writing per-lane JSON, a `jq`
summary (finding count by rule), and POSIX timing files to
`benchmark-results/ada_drivers_library/` (override with `RESULTS_DIR`).

## What this benchmark checks

Two questions, both answered by manual review of the findings, not an
independent oracle (there is no GNATprove lane here to cross-check against):

1. **Do the concurrency-prohibition checks correctly fire on real tasking
   constructs, and correctly stay silent on the constructs they don't cover?**
   All 7 files with `protected` declarations use `protected`, never `task` --
   `No_Tasking` correctly finds nothing (a true negative, not a check that
   never ran: `No_Select`, `No_Requeue`, and `No_Asynchronous_Transfer`
   likewise find nothing, since none of those constructs need a real `task`
   body). `No_Rendezvous` correctly fires on all 5 real `entry` declarations.
   `Potentially_Blocking_Operation` correctly finds nothing: none of these
   interrupt handlers call anything blocking, which is exactly the
   discipline a correct ISR must observe, and exactly what a false negative
   here would have missed.
2. **Does anything else look wrong on a real, unfamiliar, register-bashing
   embedded codebase this project's own hand-constructed fixtures don't
   resemble?** Yes: this benchmark's first run found `FP-042` (see
   `RESULTS_2026-08-05.md`), a real false positive in
   `Circular_Package_Dependency` on a `limited with` pair, fixed as part of
   recording these results.

See [RESULTS_2026-08-05.md](RESULTS_2026-08-05.md) for the first recorded
run and its full finding breakdown by rule.
