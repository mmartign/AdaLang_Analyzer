#!/bin/sh
set -eu

#  Seeded-defect gate for --verify.
#
#  tests/seeded_defects/ holds small programs in which marked checks really
#  fail (--  BAD) or really hold (--  OK). No marked defect may be reported
#  Proved_Safe or Unreachable, and every marked line must keep the outcome
#  recorded in quality/seeded_defect_outcomes.tsv. See
#  tests/seeded_defect_check.py for the marker syntax and --update.

python3 tests/seeded_defect_check.py
