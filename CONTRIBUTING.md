# Contributing to adalang_analyzer

Thank you for helping improve `adalang_analyzer`.

Before opening a pull request:

1. Create a focused branch from the default branch.
2. Build the project with `alr build`.
3. Exercise the affected checks against representative valid and invalid Ada
   sources.
4. Run `sh tests/run_recommended_gate.sh` and
   `sh tests/run_quality_metrics.sh`. Refresh the reviewed baseline or release
   metrics only after explaining and reviewing the change.
5. Keep commits small and explain observable behavior changes in the pull
   request.

Please use GitHub issues for reproducible bug reports and feature proposals.
Include the analyzer version, host platform, command line, a minimal Ada input,
and the actual and expected output whenever possible.

By contributing, you agree that your contribution is distributed under the
repository's GNU General Public License, version 3 or any later version.
