#!/bin/sh
set -eu

#  Complete repository gate. Build first so every suite exercises the current
#  sources rather than a stale executable. GNATprove remains an explicit skip
#  inside its differential script when the optional tool is unavailable.
#  With ADALANG_TESTS_KEEP_GOING=1 every script runs even after one fails,
#  and the failed ones are listed at the end.
alr build

keep_going=${ADALANG_TESTS_KEEP_GOING:-0}
failed=''

for test_script in \
  tests/run_control_flow_graph_model.sh \
  tests/run_proof_obligations_model.sh \
  tests/run_recoverable_diagnostic.sh \
  tests/run_bug_findings.sh \
  tests/run_automotive.sh \
  tests/run_automotive_evidence.sh \
  tests/run_do178c.sh \
  tests/run_do178c_evidence.sh \
  tests/run_corpus_exercise_coverage.sh \
  tests/run_tool_function_evidence.sh \
  tests/run_compliance_report.sh \
  tests/run_precision_corpus.sh \
  tests/run_circular_dependencies.sh \
  tests/run_objectada_projects.sh \
  tests/run_line_ends.sh \
  tests/run_clone_detection.sh \
  tests/run_cli_robustness.sh \
  tests/run_alire_gnatls_fallback.sh \
  tests/run_cli_parameter_effects.sh \
  tests/run_config_file.sh \
  tests/run_compiler_checks.sh \
  tests/run_gnatcheck_names.sh \
  tests/run_gap_ledger.sh \
  tests/run_gnatprove_import.sh \
  tests/run_reporting.sh \
  tests/run_recommended.sh \
  tests/run_recommended_gate.sh \
  tests/run_quality_metrics.sh \
  tests/run_verification.sh \
  tests/run_solver_limits.sh \
  tests/run_verification_mutations.sh \
  tests/run_seeded_defects.sh \
  tests/run_proof_path_evidence.sh \
  tests/run_gnatprove_differential.sh \
  tests/run_performance_smoke.sh
do
   if [ "$keep_going" = 1 ]; then
      echo "=== $test_script"
      if ! sh "$test_script"; then
         echo "=== FAILED: $test_script" >&2
         failed="$failed $test_script"
      fi
   else
      sh "$test_script"
   fi
done

if [ -n "$failed" ]; then
   echo "failed test scripts:$failed" >&2
   exit 1
fi

echo "all available tests passed"
