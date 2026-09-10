#!/bin/sh
set -eu

#  Regenerate docs/src/tool-qualification-support.md from
#  quality/tool_function_evidence.tsv and quality/corpus_exercise_coverage.tsv.
#  Deterministic: no timestamps, no host state.
#  tests/run_tool_function_evidence.sh fails if the committed document is not
#  byte-identical to this script's output.
#
#  Usage: sh tests/gen_tool_qualification_doc.sh > docs/src/tool-qualification-support.md

manifest=quality/tool_function_evidence.tsv
coverage=quality/corpus_exercise_coverage.tsv

total=$(awk -F '\t' '!/^#/ && NF {n++} END {print n+0}' "$manifest")
n_gnatcheck=$(awk -F '\t' '!/^#/ && $4=="gnatcheck-comparison" {n++} END {print n+0}' "$manifest")
n_gnatprove=$(awk -F '\t' '!/^#/ && $4=="gnatprove-differential" {n++} END {print n+0}' "$manifest")
n_oracle=$((n_gnatcheck + n_gnatprove))

n_corpora=$(sed -n 's/^# corpora scanned (\([0-9]*\)):.*/\1/p' "$coverage")
n_exercised=$(awk -F '\t' '!/^#/ && $2=="yes" {n++} END {print n+0}' "$coverage")
n_hits=$(awk -F '\t' '!/^#/ && $5+0>0 {n++} END {print n+0}' "$coverage")
not_exercised=$(awk -F '\t' '!/^#/ && $2=="no" {printf "%s`%s`", sep, $1; sep=", "}' "$coverage")

cat <<EOF
# Tool-function validation evidence

This page is generated from
[\`quality/tool_function_evidence.tsv\`](https://github.com/mmartign/AdaLang_Analyzer/blob/main/quality/tool_function_evidence.tsv)
by \`tests/gen_tool_qualification_doc.sh\`, and is kept in sync with it by
\`tests/run_tool_function_evidence.sh\` in the repository gate. Do not edit it
by hand.

## Purpose

A tool-qualification argument under EN 50128 §6.7 (T2), ISO 26262-8 §11, or
DO-330 needs, at minimum, a statement of each tool function, validation
evidence traceable to it, and an analysis of what an undetected tool
malfunction could do. This page assembles the first and third of those for
every AdaLang Analyzer check, and links each check to machine-checked
validation cases.

It is **not** a qualification argument and does not discharge one. As the
[assurance model](assurance-model.md) states, absence of a finding is not
evidence that a defect is absent, and no profile or clean run qualifies this
tool. What follows is the raw material a project's own qualification effort
would build on, not a substitute for it.

## How to read this

Every check is placed in one **assurance class**. The class fixes what a
finding asserts and — because tool-error effects cluster by class rather than
varying per check — what a malfunction of that check would mean. The classes
mirror the confidence hierarchy in the [assurance model](assurance-model.md).

| Class | A finding asserts | Effect if the check **under-reports** (misses a real case) | Effect if the check **over-reports** (spurious finding) |
|---|---|---|---|
| \`policy\` | A construct the selected Ada subset or coding standard prohibits is present. | The prohibited construct stays in subset-restricted code unflagged; the restriction the profile exists to enforce is not enforced on that unit, and a reviewer relying on a clean run keeps it. | Review time is spent on a construct that is within policy. The analyzer only reports and never edits code, so nothing unsafe is introduced; the finding is dismissible with a recorded rationale. |
| \`defect\` | The check's documented analysis found evidence of a likely or definite defect. | The defect is not reported. A clean run is not evidence of absence, so it can pass review and reach downstream verification or the build. | Effort is spent confirming a flagged construct is not defective. The tool makes no change; the finding can be baselined with rationale and does not mask other findings. |
| \`known_failure\` | The abstract state was precise enough to show a run-time error is certain for the represented values at that point. | A statically certain error is not classified as definite; with no independent check it reaches run time as the corresponding Ada exception. Loss of a \`Known_*\`/definite signal is the direction the [false-safe response policy](false-safe-response.md) treats as release-blocking. | A construct is wrongly asserted to be a definite error, causing rework. It creates no unsafe code; the definite-error fixture corpus and, for the obligation kinds it covers, the GNATprove differential guard against it, and a confirmed instance is logged in \`quality/known_analysis_issues.tsv\`. |
| \`readiness\` | A construct, missing contract, or data-flow issue likely to obstruct a later SPARK / GNATprove pass or an assurance objective is present. | The readiness condition is not reported, so a later SPARK/GNATprove pass can fail or stall on exactly what this check was meant to surface early. | Effort is spent on a readiness finding GNATprove would not have needed. The tool changes nothing; the finding is suppressible with rationale. |
| \`metric\` | A configured numeric threshold was exceeded. | A subprogram or unit past the threshold is not reported, so an analyzability/maintainability limit the project set is not enforced there. | A subprogram or unit at or under the threshold is wrongly reported. The threshold is configurable and the finding can be baselined. |
| \`style\` | A house-style or readability rule was broken. | A style deviation is not reported; impact is limited to code consistency and reviewability. | A compliant construct is wrongly reported; cosmetic only, and suppressible with rationale. |

Across every class, an AdaLang over-report wastes engineering effort but
cannot by itself introduce a defect or mask another finding: the tool
produces diagnostics only and never rewrites source. The consequential
direction is under-reporting, and it is bounded differently per class as
above.

## Independent oracles

The **independent oracle** column records whether a second, independently
implemented tool cross-checks this check's behaviour on the shared benchmark
corpora, over and above the analyzer's own fixtures:

- \`gnatcheck-comparison\` — the check has a Direct or Close counterpart in
  the [GNATcheck rule comparison](gnatcheck-rule-comparison.md), and
  \`benchmarks/\`'s GNATcheck oracle run compares the two tools' findings at
  the same \`(file, line)\` across all ten external corpora.
- \`gnatprove-differential\` — the check's proof-obligation kind is
  exercised by the clean and broken GNATprove differential corpora described
  in the [assurance model](assurance-model.md), where GNATprove's verdict is
  ground truth.
- \`none\` — validated by the analyzer's own positive and negative fixtures
  only. This is the majority: most checks have no predefined-rule GNATcheck
  counterpart (see the comparison document), and only scalar run-time-check
  obligations are in the GNATprove differential's scope.

## Coverage summary

- **$total checks**, one per \`Rule_Kind\` literal in
  \`src/adalang_analyzer-rules.ads\`; every one has at least one positive and
  one negative validation invocation, each re-run by the gate one check at a
  time.
- **$n_oracle** carry an independent-tool cross-check
  ($n_gnatcheck via the GNATcheck comparison, $n_gnatprove via the GNATprove
  differential); the remaining $((total - n_oracle)) are fixture-validated
  only.
- Class distribution:
EOF

awk -F '\t' '!/^#/ && NF {c[$2]++} END {
  split("policy defect known_failure readiness metric style", ord, " ")
  for (i = 1; i <= 6; i++) printf "  - `%s`: %d\n", ord[i], c[ord[i]] + 0
}' "$manifest"

cat <<EOF

## Exercise against independently-authored code

The fixtures above are hand-built. Separately, the checks are run over the
$n_corpora external Ada/SPARK corpora in
[\`benchmarks/\`](https://github.com/mmartign/AdaLang_Analyzer/tree/main/benchmarks)
as part of the release process, and
[\`quality/corpus_exercise_coverage.tsv\`](https://github.com/mmartign/AdaLang_Analyzer/blob/main/quality/corpus_exercise_coverage.tsv)
records, per check and derived from the benchmark result JSON, whether a
preset run enabled it there, how many corpora did, and how many findings
across how many files it produced. It is a release snapshot, refreshed with
the benchmark run itself.

- **$n_exercised of $total** checks were enabled by at least one benchmark
  preset run (\`--recommended\` / \`--spark\` / \`--automotive\` / \`--verify\`)
  over an external corpus; **$n_hits** produced at least one finding on that
  real code.
- The remaining $((total - n_exercised)) are not reached by those preset
  runs -- mostly style rules outside every preset, plus any check newer than
  the last benchmark refresh -- and remain fixture-validated only:
  $not_exercised.

This is exercise evidence: the check ran against real, independently authored
Ada, not only against repository fixtures. It is not a soundness or
completeness measure, and a finding count is not a defect count.

The positive and negative invocations below are also exercised, with their
expected outcomes, by the other quality gates: the profile presets through
\`run_automotive_evidence.sh\` and \`run_do178c_evidence.sh\`, and the
boundary/negative corpus through \`run_precision_corpus.sh\`. This page adds
the whole-catalogue view and the per-class tool-error-effect analysis.

## Per-check validation evidence

| Check | Class | Documented function | Independent oracle | Positive invocation | Negative invocation |
|---|---|---|---|---|---|
EOF

awk -F '\t' '!/^#/ && NF {
  printf "| `%s` | `%s` | %s | `%s` | `%s` | `%s` |\n", $1, $2, $3, $4, $5, $6
}' "$manifest"
