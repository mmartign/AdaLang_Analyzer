#!/bin/sh
set -eu

#  Complete repository gate. Build first so every suite exercises the current
#  sources rather than a stale executable. GNATprove remains an explicit skip
#  inside its differential script when the optional tool is unavailable.
alr build

for test_script in \
  tests/run_control_flow_graph_model.sh \
  tests/run_proof_obligations_model.sh \
  tests/run_recoverable_diagnostic.sh \
  tests/run_bug_findings.sh \
  tests/run_automotive.sh \
  tests/run_automotive_evidence.sh \
  tests/run_do178c.sh \
  tests/run_do178c_evidence.sh \
  tests/run_compliance_report.sh \
  tests/run_precision_corpus.sh \
  tests/run_circular_dependencies.sh \
  tests/run_cli_robustness.sh \
  tests/run_cli_parameter_effects.sh \
  tests/run_config_file.sh \
  tests/run_reporting.sh \
  tests/run_recommended.sh \
  tests/run_recommended_gate.sh \
  tests/run_quality_metrics.sh \
  tests/run_verification.sh \
  tests/run_verification_mutations.sh \
  tests/run_gnatprove_differential.sh \
  tests/run_performance_smoke.sh
do
   sh "$test_script"
done

echo "all available tests passed"
