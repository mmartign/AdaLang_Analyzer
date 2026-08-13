# False-Safe Response and Release Policy

A false-safe result is any `Proved_Safe` obligation for which a concrete Ada
execution allowed by the recorded assumptions can violate that obligation.
Because this result can be used as assurance evidence, it is treated as a
release-blocking correctness defect rather than an ordinary precision issue.

## Immediate response

1. Preserve the exact analyzer version, command, project scenario variables,
   target/toolchain information, report, and smallest reproducible source.
2. Add the case to `quality/known_analysis_issues.tsv` as an open
   `false-negative`. Do not suppress or baseline it away.
3. Disable or conservatively narrow the affected `Proved_Safe` path if a
   complete fix cannot be reviewed immediately. Returning `Unproved` or
   `Unsupported` is the required safe fallback.
4. Notify maintainers through a private security report when the affected
   build is released or used for safety/security assurance; otherwise use a
   normal reproducible issue.

## Required fix evidence

A correction is complete only when it includes:

- a minimal seeded-defect regression that fails if the obligation becomes
  `Proved_Safe` again;
- a positive sibling demonstrating that supported proofs still work;
- an audit of sibling obligation kinds and all callers of the faulty proof
  mechanism;
- GNATprove differential evidence where the construct is accepted by SPARK;
- an update to the supported-subset boundary when semantics changed; and
- a `quality/known_analysis_issues.tsv` entry that records root cause,
  mitigation, tests, and closure.

The full `sh tests/run_all.sh` gate is mandatory. A reviewer must explicitly
check that failure and solver-unavailable paths remain conservative and that
reporting preserves the assumptions and provenance used for the result.

## Release handling

No release candidate or final release may be published with an open confirmed
false-safe result. If a released version is affected, maintainers must identify
the affected version range, document which obligation/status combinations are
untrustworthy, and publish either a corrected release or a mitigation that
prevents those obligations from being reported as `Proved_Safe`.

Closing the issue requires a reviewed regression and a clean complete gate.
Historical release metrics are append-only; they are not rewritten to hide
the period during which the issue was open.
