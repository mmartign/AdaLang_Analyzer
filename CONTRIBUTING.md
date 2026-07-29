# Contributing to adalang_analyzer

Thank you for helping improve `adalang_analyzer`.

Before opening a pull request:

1. Create a focused branch from the default branch.
2. Exercise affected checks against representative valid and invalid Ada
   sources.
3. Run the complete local gate with `sh tests/run_all.sh`. It builds the
   current sources and runs every repository suite; the GNATprove differential
   suite reports an explicit skip when the optional tool is unavailable.
4. Refresh the reviewed baseline or release metrics only after explaining and
   reviewing the change.
5. Keep commits small and explain observable behavior changes in the pull
   request.

Please use GitHub issues for reproducible bug reports and feature proposals.
Include the analyzer version, host platform, command line, a minimal Ada input,
and the actual and expected output whenever possible.

By contributing, you agree that your contribution is distributed under the
repository's GNU General Public License, version 3 or any later version.
