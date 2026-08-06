# Security Policy

## Supported Versions

AdaLang Analyzer is pre-1.0 and moves quickly. Security fixes are applied to
the most recent release only; there is no long-term support branch at this
time.

| Version         | Supported          |
|-----------------|---------------------|
| latest `main`   | :white_check_mark: |
| older releases  | :x:                 |

## Reporting a Vulnerability

Please **do not** open a public GitHub issue for suspected security
vulnerabilities.

Instead, report them privately using either channel:

- **GitHub Security Advisories**: use the
  ["Report a vulnerability"](https://github.com/mmartign/AdaLang_Analyzer/security/advisories/new)
  form on this repository.
- **Email**: [info@spazioit.com](mailto:info@spazioit.com), with `SECURITY`
  in the subject line.

Include as much of the following as you can:

- A description of the vulnerability and its potential impact.
- Steps to reproduce, including a minimal Ada input or command line if
  applicable.
- The analyzer version (`adalang_analyzer --version`), host platform, and
  build configuration.

### What to expect

- Acknowledgment of your report within 5 business days.
- An initial assessment of severity and affected versions within 10 business
  days.
- Coordinated disclosure: we will work with you on a disclosure timeline
  once a fix is available, and credit reporters who wish to be credited.

## Scope

AdaLang Analyzer is a static analysis tool that reads Ada source files and
writes reports. Relevant classes of vulnerability include (non-exhaustively):

- Memory-safety or crash issues triggered by crafted, malformed, or
  adversarial Ada source input.
- Path traversal, command injection, or unsafe handling of file paths and
  configuration files.
- Supply-chain issues in the build or release process.

Findings about the *quality or precision* of static analysis rules (false
positives/negatives) are not security issues — please report those as
regular [bug reports](.github/ISSUE_TEMPLATE/bug_report.yml) instead.
