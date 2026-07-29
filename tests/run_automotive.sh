#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
output=$(mktemp "${TMPDIR:-/tmp}/adalang-automotive.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

structural='No_Dynamic_Allocation,Restricted_Access_Type,No_Explicit_Dereference,No_Unchecked_Deallocation,No_Tasking,No_Rendezvous,No_Select,No_Requeue,No_Asynchronous_Transfer'

if "$analyzer" -checks="$structural" \
     tests/automotive_restrictions_findings.adb >"$output" 2>&1
then
   echo "expected automotive structural findings" >&2
   exit 1
fi

for rule in \
   No_Dynamic_Allocation Restricted_Access_Type No_Explicit_Dereference \
   No_Unchecked_Deallocation No_Tasking No_Rendezvous No_Select No_Requeue \
   No_Asynchronous_Transfer
do
   grep -F "[$rule]" "$output" >/dev/null || {
      echo "missing automotive finding: $rule" >&2
      exit 1
   }
done

"$analyzer" -q -checks="$structural" \
  tests/automotive_restrictions_clean.adb

semantic='Exception_Propagation,No_Dispatching_Call,No_Classwide_Type,No_Controlled_Type'
if "$analyzer" -checks="$semantic" \
     tests/automotive_semantic_findings.adb >"$output" 2>&1
then
   echo "expected automotive semantic findings" >&2
   exit 1
fi

for rule in \
   Exception_Propagation No_Dispatching_Call No_Classwide_Type \
   No_Controlled_Type
do
   grep -F "[$rule]" "$output" >/dev/null || {
      echo "missing automotive semantic finding: $rule" >&2
      cat "$output" >&2
      exit 1
   }
done

"$analyzer" -q -checks="$semantic" tests/automotive_semantic_clean.adb

state_rules='Complete_Initialization,Volatile_Atomic_Consistency,Representation_Clause_Policy,Library_Level_Initialization'
if "$analyzer" -checks="$state_rules" \
     tests/automotive_state_findings.ads \
     tests/automotive_state_findings.adb >"$output" 2>&1
then
   echo "expected automotive state-policy findings" >&2
   exit 1
fi
for rule in \
   Complete_Initialization Volatile_Atomic_Consistency \
   Representation_Clause_Policy Library_Level_Initialization
do
   grep -F "[$rule]" "$output" >/dev/null || {
      echo "missing automotive state finding: $rule" >&2
      cat "$output" >&2
      exit 1
   }
done

"$analyzer" -q -checks="$state_rules" tests/automotive_state_clean.ads

policy_rules='Generic_Instantiation_Limit,Dependency_Limit,Naming_Convention,No_Compiler_Extensions'
if "$analyzer" -generic-threshold=1 -dependency-threshold=1 \
     -checks="$policy_rules" tests/automotive_policy_findings.adb \
     >"$output" 2>&1
then
   echo "expected automotive policy findings" >&2
   exit 1
fi
for rule in \
   Generic_Instantiation_Limit Dependency_Limit Naming_Convention \
   No_Compiler_Extensions
do
   grep -F "[$rule]" "$output" >/dev/null || {
      echo "missing automotive policy finding: $rule" >&2
      cat "$output" >&2
      exit 1
   }
done

"$analyzer" -q -generic-threshold=1 -dependency-threshold=1 \
  -checks="$policy_rules" tests/automotive_policy_clean.adb

#  Alire-generated configuration pragmas are build metadata, not authored
#  compiler extensions, and cannot be removed from the generated source.
"$analyzer" -q -checks='No_Compiler_Extensions' \
  config/adalang_analyzer_config.ads

#  The preset must include both structural and semantic policy rules.
if "$analyzer" --automotive \
     tests/automotive_restrictions_findings.adb >"$output" 2>&1
then
   echo "automotive preset unexpectedly missed restricted constructs" >&2
   exit 1
fi
grep -F '[No_Dynamic_Allocation]' "$output" >/dev/null
grep -F '[No_Tasking]' "$output" >/dev/null
if "$analyzer" --automotive tests/automotive_policy_findings.adb \
     >"$output" 2>&1
then
   echo "automotive preset unexpectedly missed policy violations" >&2
   exit 1
fi
grep -F '[Naming_Convention]' "$output" >/dev/null
grep -F '[No_Compiler_Extensions]' "$output" >/dev/null

echo "automotive profile tests passed"
