# Compliance reporting

```sh
alr exec -- ./bin/adalang_analyzer --do178c=A --compliance-report=do178c \
  --compliance-report-output=compliance.md -P adalang_analyzer.gpr

alr exec -- ./bin/adalang_analyzer --automotive --compliance-report=iso26262 \
  --compliance-report-output=compliance.md -P adalang_analyzer.gpr

alr exec -- ./bin/adalang_analyzer --automotive --compliance-report=en50128 \
  --compliance-report-output=compliance.md -P adalang_analyzer.gpr

alr exec -- ./bin/adalang_analyzer --do178c=A --compliance-report=do178c \
  --compliance-report-format=json \
  --compliance-report-output=compliance.json -P adalang_analyzer.gpr
```

Writes a per-objective evidence report to `--compliance-report-output` (or
standard output if omitted), for `do178c` (paired with a `--do178c=<level>`
run), `iso26262`, or `en50128` (the latter two both paired with an
`--automotive` run -- ISO 26262 and EN 50128 converge on the same
restricted-Ada-subset techniques, so both read the identical
`--automotive` rule set under their own labeled objectives).
`--compliance-report-format` selects the representation: `markdown`
(default) or `json`, the same content as a machine-readable document for
tooling that consumes the report programmatically (CI gates, dashboards).
SARIF is not offered here — SARIF's result-oriented schema has no natural
slot for this report's objective/evidence structure; use `--format=sarif`
for a SARIF rendering of the underlying findings instead. For each objective
it lists the mapped checks, whether they were enabled this run, and this
run's open and baselined findings against them; it also lists every inline
suppression recorded this run together with its rationale, every finding
matched against `--baseline` (which currently carries no rationale of its
own), and the verification activities this analyzer does not automate at all
(structural coverage, requirements-based or dynamic testing, object-code or
run-time-error proof beyond the supported subset, tool qualification).

An unrecognized standard or report format fails the invocation rather than
silently producing no report. Likewise, `--compliance-report-output` or
`--compliance-report-format` given without the `--compliance-report=<standard>`
that makes them meaningful fails fast, before any file is analyzed, instead
of quietly analyzing the source and never writing (or explaining why it
never wrote) a report. If the run has no checks enabled at all --
typically a `--compliance-report` invocation missing its paired
`--do178c=<level>` or `--automotive` -- every objective would otherwise show
"0 open findings" indistinguishable from a genuine clean run; a warning is
printed to stderr and a matching `**WARNING:**` banner (or a non-empty
`warning` field in JSON) is written into the report itself, so the empty
report cannot pass as evidence unnoticed. Objective labels are AdaLang's own
paraphrase:
for `do178c`, of publicly discussed DO-178C Annex A Table A-5 activities;
for `iso26262` and `en50128`, of the same general safety themes already
summarized non-normatively in
[Automotive Ada compliance matrix](automotive-compliance-matrix.md)
and [EN 50128 rail compliance matrix](en50128-rail-compliance-matrix.md)
respectively -- the same `--automotive` rule set read under two different
labelings, not two independently derived mappings. None cites the
respective standard's normative text or official numbering, and the report
states this. Like the profiles above, this report is verification-support
evidence, not a compliance determination.
