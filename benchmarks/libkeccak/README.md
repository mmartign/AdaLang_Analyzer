# Libkeccak comparison benchmark

This benchmark compares AdaLang Analyzer's `--verify` bounded-scalar proof
obligations against GNATprove's `--mode=prove` results, per obligation (same
file, line, and check kind), on a pinned revision of
[damaki/libkeccak](https://github.com/damaki/libkeccak) (BSD-3, actively
maintained by Daniel King) — a SPARK 2014 implementation of the Keccak
family of sponge functions (SHA-3, SHAKE, cSHAKE, KMAC, TupleHash,
ParallelHash, KangarooTwelve) plus the Gimli and Ascon permutations.

Like `benchmarks/sparknacl/` and `benchmarks/saatana/`, libkeccak targets
the *silver* level of SPARK assurance — an auto-active proof that the code
is free of run-time errors (uninitialized reads, overflow, division by
zero, out-of-range values, out-of-bounds accesses, non-terminating loops).
Per its own README, "all checks are fully proved, except for a few
initialisation checks which GNATprove's flow analysis cannot automatically
verify due to the use of loops," which are manually reviewed and suppressed
with `pragma Annotate`. Unlike SPARKNaCl and Saatana, the library does
*not* claim functional-correctness proofs — its algorithm correctness is
established by Known Answer Tests, not GNATprove. That distinction does not
affect this benchmark: it only compares the run-time-error obligation
category both tools evaluate, not functional postconditions, so
GNATprove's verdict remains a trustworthy oracle for the two questions that
matter here: (1) does AdaLang ever call something `Proved_Safe` that
GNATprove could not prove (a soundness question), and (2) how often does
AdaLang's `Definite_Error` agree with GNATprove's not-proved verdict (a
precision question).

This is a fourth, independently authored corpus (Daniel King/damaki, distinct
from SPARKNaCl's rod-chapman, Saatana's HeisenbugLtd, and CubedOS's
cubesatlab) in a different implementation style again: a sponge-construction
hash family built from generic permutation cores and instantiated many times
over varying state sizes, rather than SPARKNaCl's fixed-width arithmetic
library, Saatana's single dense stream cipher, or CubedOS's message-passing
framework.

A candidate corpus considered and rejected before this one,
[Componolit/libsparkcrypto](https://github.com/Componolit/libsparkcrypto),
turned out to hit a genuine `gnat2why` internal crash
(`Program_Error gnat2why-unchecked_conversion.adb:965`) on this benchmark
suite's GNATprove version, blocking most of its hash-related units; it was
set aside as unsuitable for a same-toolchain oracle comparison rather than
worked around.

## Pinned source

- damaki/libkeccak: `4b7174fccbf5461998b18395aaeecc68bb25798d`

Clone the corpus from the AdaLang Analyzer repository root:

```sh
git clone https://github.com/damaki/libkeccak.git \
  /private/tmp/adalang-libkeccak-benchmark
git -C /private/tmp/adalang-libkeccak-benchmark checkout \
  4b7174fccbf5461998b18395aaeecc68bb25798d
```

libkeccak is an Alire-native crate: `libkeccak.gpr` `with`s
`config/libkeccak_config.gpr`, which Alire generates and does not check
into the repository. Run the one-time setup step before `run.sh`:

```sh
cd /private/tmp/adalang-libkeccak-benchmark && alr build
```

This benchmark always uses `-XLIBKECCAK_ARCH=generic -XLIBKECCAK_SIMD=none`
(also this project's own default), the portable Ada implementation with no
SIMD intrinsics or x86-specific code — the `x86_64`/`SSE2`/`AVX2` variants
are unrelated performance backends, not part of what either tool proves
here, and (unlike the generic path) would not build on a non-x86_64 host
such as this benchmark suite's Apple Silicon machines.

Run the benchmark:

```sh
LIBKECCAK_ROOT=/private/tmp/adalang-libkeccak-benchmark sh benchmarks/libkeccak/run.sh
```

`run.sh` verifies the pinned revision, then runs:

- AdaLang `--verify` against `libkeccak.gpr`, `--format=json`;
- GNATprove `--mode=prove --output=oneline` against the same project, with
  one explicit override of libkeccak's own `Prove` package switches (see
  "Toolchain override" below);
- `compare.awk` (identical to the other three benchmarks' copies) over both
  outputs, writing `comparison.txt` to the results directory (default
  `benchmark-results/libkeccak/`, override with `RESULTS_DIR`).

## Toolchain override

libkeccak's own `libkeccak.gpr` carries a tuned `Prove` package
(`--proof=per_path`, `--prover=cvc4,z3,altergo`, `--timeout=60`,
`--steps=16000`, `--report=statistics`). One entry — `--prover=cvc4,z3,altergo`
— names a prover this benchmark suite's GNATprove toolchain does not ship:
the same FSF 16.1.0 / Why3 1.8.2+git / CVC5 1.3.2 pin the other three
benchmarks in this directory document bundles CVC5, not the older CVC4. Run
unmodified, GNATprove aborts outright ("Selected prover not installed or
not configured") on every check, the same category of environment gap as
`FP-029` and `benchmarks/saatana/`'s own CVC4 override, not an AdaLang
defect. `--prover=z3,cvc5,altergo` on the command line substitutes CVC5 for
CVC4 project-wide; the project's own `--steps=16000`/`--timeout=60` budget
is otherwise left unmodified. See the latest `RESULTS_*.md` for whether
that budget alone was sufficient or needed further widening for this
toolchain, the way Saatana's did.

## Matching design

Same as `benchmarks/sparknacl/`, `benchmarks/saatana/`, and
`benchmarks/cubedos/`: obligations are matched by `(basename(file), line,
normalized check kind)`, count-mismatched locations are reported separately
rather than guessed, and `compare.awk`'s five per-pair buckets and two
coverage-only counts have the same meaning. See
`benchmarks/sparknacl/README.md` for the full design description.

## Caveats

- GNATprove version, solver versions, and exact message wording are recorded
  in each dated `RESULTS_*.md` for reproducibility.
- libkeccak's proofs cover run-time-error freedom only, not functional
  correctness (see above) — this benchmark's agreement numbers should be
  read as being about that scope, the same scope `--verify` itself targets.
- The GNATprove message-text substring matching in `compare.awk` is a
  heuristic against observed wording, not a stable GNATprove API — see
  `benchmarks/sparknacl/README.md`'s caveat for the same point.

See the latest `RESULTS_*.md` in this directory for recorded runs.
