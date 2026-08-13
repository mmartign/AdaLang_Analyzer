# Contributing to adalang_analyzer

Thank you for helping improve `adalang_analyzer`. External bug reports,
precision feedback (false positives/negatives), and focused pull requests are
all welcome — this project is used in safety-critical contexts, so reviews
from outside contributors with Ada/SPARK or static-analysis experience are
especially valuable.

By participating, you are expected to uphold our
[Code of Conduct](CODE_OF_CONDUCT.md).

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

Changes that add or broaden a `Proved_Safe` result must also follow the
evidence requirements in
[Supported Verification Subset](SUPPORTED_VERIFICATION_SUBSET.md). Confirmed
false-safe results use the release-blocking process in
[False-Safe Response and Release Policy](FALSE_SAFE_RESPONSE.md).
Every new `Record_Proved_Safe` producer needs a unique `proof-path` source tag
and one or more routes in `quality/proof_path_evidence.tsv`.

Please use GitHub issues for reproducible bug reports and feature proposals;
the issue forms prompt for the analyzer version, host platform, command line,
a minimal Ada input, and the actual and expected output. Found a security
vulnerability instead? Please follow [SECURITY.md](SECURITY.md) rather than
filing a public issue.

By contributing, you agree that your contribution is distributed under the
repository's GNU General Public License, version 3 or any later version.
