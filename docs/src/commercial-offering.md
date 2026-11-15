# Qualification and validation kits

AdaLang Analyzer is free software under GPL-3.0-or-later, and it stays that
way: everything on this site, every check, and every evidence gate in the
repository can be used without a commercial agreement.

Programs that need the tool inside a certified lifecycle need more than the
software. They need its tool qualification under DO-330, a tool confidence
level under ISO 26262, or a T2 justification under EN 50128. That takes
material packaged for one frozen version of the tool, in the configuration
the project uses, and it has to keep being maintained. [Spazio
IT](https://spazioit.com/), which develops and maintains the analyzer,
supplies that material and the assistance around it as a commercial
offering.

## What is available

| Offering | What you receive |
| --- | --- |
| **Qualification kit** | The documents a project's tool-qualification argument is built on, written for one analyzer release and the project's configuration: profile, enabled checks, `--verify` options, and Libadalang and solver versions. |
| **Validation kit** | The test cases, procedures, inputs and expected results that show the tool works as specified, packaged so that you can run them again in your own environment and keep the results as evidence. |
| **Qualified-version maintenance** | A frozen release kept available for the program's lifetime, problem reports and false-safe notifications assessed against it, and validation kits refreshed with each maintenance release. |
| **Qualification assistance** | Help writing the project-specific plans, tool classification and the parts of the argument that only the project can own, and support during reviews with the certification authority or assessor. |

Kits are made per release and per configuration on request. They are not
included in the open-source distribution.

## Qualification kit

The kit follows the structure each standard asks for. The documents are
prepared for the applicant's tool-qualification argument; they are not a
substitute for it.

- **DO-178C / DO-330.** Used for verification, AdaLang Analyzer is a
  criteria 3 tool: it can fail to detect an error but cannot insert one into
  the airborne software.
  The kit is therefore aimed at TQL-5 and covers the tool qualification
  data DO-330 asks of a TQL-5 tool. That means the Tool Operational
  Requirements for the functions the project uses, the tool verification
  cases, procedures and results in the operational environment, the
  configuration identification of the tool, and the inputs for the
  applicant's Tool Qualification Plan and Tool Accomplishment Summary. The
  [DO-178C verification-support profiles](do178c-profiles.md) and the
  [DO-178C compliance matrix](do178c-compliance-matrix.md) describe the
  configuration it starts from.
- **ISO 26262-8 §11.** The kit includes a tool classification analysis of
  the use cases (tool impact, tool error detection, the resulting TCL) and
  the evidence for the qualification method the project chooses, typically
  validation of the software tool (method 1c). The
  [automotive compliance matrix](automotive-compliance-matrix.md) is the
  starting point.
- **EN 50128 §6.7.** Used for verification, AdaLang Analyzer is a T2 tool:
  it can fail to reveal a defect but cannot introduce one. The kit includes the
  tool specification and the evidence of its validation that §6.7.4 asks of
  a T2 tool, mapped to the
  [EN 50128 compliance matrix](en50128-rail-compliance-matrix.md).

Every kit includes an analysis of the tool's failure modes: what an
undetected malfunction of each tool function could do, and which
verification activity catches it. That analysis starts from the assurance
classes of the
[tool-function validation evidence](tool-qualification-support.md).

## Validation kit

The validation kit is built from the evidence the repository's gate already
produces for every release, frozen for the qualified version and
re-runnable in your environment:

- one tool-function statement per check, each with positive and negative
  validation cases ([tool-function validation
  evidence](tool-qualification-support.md));
- the seeded-defect and precision corpora, with their expected outcomes;
- the seeded mutation campaign, which guards each proof-obligation family
  against false-safe regressions;
- the proof-path evidence, which ties every route that can produce a
  `Proved_Safe` result to fixtures that exercise it;
- the differential comparison with GNATprove on clean and deliberately
  broken units, where GNATprove's verdict is the reference;
- the benchmark results on the external corpora, including the
  [GNATprove gap ledger](evidence.md);
- the [false-safe response policy](false-safe-response.md) and the record
  of known analysis issues for that version.

The kit adds the installation and operational checks: scripts that confirm
the delivered binary is the qualified one, run the validation suite on the
project's host, and compare the results with the expected ones. The results
become part of the project's records.

## What remains the project's responsibility

Tool qualification is always done in the context of a project. The
applicant owns the qualification argument, chooses the tool's use cases
and configuration, and obtains the agreement of the certification
authority or assessor. The kit supplies the tool-side data and Spazio IT
supports the process, but neither grants certification credit by itself.
The claims the kit makes are those in [positioning and approved
claims](positioning.md) and the [assurance model](assurance-model.md): a
`Proved_Safe` result is about one obligation under its stated assumptions,
and absence of a finding is not evidence that a defect is absent.

## Other commercial services

Spazio IT also provides pilot and rollout projects, enterprise support,
custom rule development, SPARK-adoption assessments and training (see the
[project README](https://github.com/mmartign/AdaLang_Analyzer#commercial-support-from-spazio-it)).
For teams that want a ready-to-run platform, AdaLang Analyzer and
SonarAdaPlugin come pre-integrated with SonarQube in Spazio IT's
[SAFe Toolset](https://spazioit.com/pages_en/sol_inf_en/code_quality_en/safe-toolset-en/).

## Requesting a kit

Write to [info@spazioit.com](mailto:info@spazioit.com?subject=AdaLang%20Analyzer%20qualification%20kit)
with the standard and assurance level of the program, the analyzer version
or the date you need it frozen, and the profile or checks you intend to
use. Spazio IT will propose the scope of the kit and the maintenance period.
