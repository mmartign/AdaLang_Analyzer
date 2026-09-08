# DO-178C verification-support profiles

Select a software level with:

```sh
alr exec -- ./bin/adalang_analyzer --do178c=A -P adalang_analyzer.gpr
```

Levels A and B enable the strictest source, flow, exception, initialization,
coupling, traceability, and suppression-rationale checks. Level C retains the
high-confidence runtime, flow, and traceability checks without the additional
A/B coding restrictions. Level D enables only the core high-confidence defect
checks and does not imply source-code traceability objectives. Later
`-checks`, `+R`, and `-R` switches can refine any profile.

The selected profile and its external structural-coverage objective are
recorded in JSON and SARIF:

| Level | Recorded coverage objective |
|-------|-----------------------------|
| A | MC/DC |
| B | Decision coverage |
| C | Statement coverage |
| D | None |

AdaLang Analyzer does not measure structural coverage. Coverage data must come
from an appropriate target-aware coverage workflow such as GNATcoverage.

Associate a subprogram body with a low-level requirement by placing this
annotation on its declaration line or within the three immediately preceding
lines:

```ada
--  do-178c: req LLR-FLIGHT-CONTROL-042
procedure Update_Control_Surface is
begin
   ...
end Update_Control_Surface;
```

Rule suppressions used with the A/B profiles require an explicit rationale:

```ada
null;  --  adalang-analyzer: ignore Null_Statement -- rationale: empty state
```

Place `rationale:` on the suppression line. The analyzer currently associates
requirement annotations with bodies in the same source file; project-wide
requirements databases and test/coverage import remain separate lifecycle
evidence.

These profiles support verification activities; they do not determine or
claim DO-178C compliance. DO-178C also covers planning, requirements, design,
testing, configuration management, quality assurance, certification liaison,
and lifecycle evidence. Projects taking certification credit from analyzer
results must separately assess tool qualification under DO-330. See
[FAA AC 20-115D](https://www.faa.gov/regulations_policies/advisory_circulars/index.cfm/go/document.information/documentID/1032046).

See the [DO-178C Compliance Matrix](do178c-compliance-matrix.md) for a
non-normative rule-by-rule mapping to DO-178C Annex A Table A-5 activity
categories, the Ada Reference Manual, and SPARK Reference Manual guidance,
limitations, and remaining compliance gaps.
