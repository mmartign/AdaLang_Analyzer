#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
source_file=src/adalang_analyzer-flow_interp.adb
manifest=quality/proof_path_evidence.tsv
work=$(mktemp -d "${TMPDIR:-/tmp}/adalang-proof-paths.XXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM

grep -Eo 'proof-path: [a-z0-9-]+' "$source_file" |
  sed 's/.*proof-path: //' | sort -u >"$work/source-producers"
awk -F '\t' '!/^#/ && NF {print $2}' "$manifest" |
  sort -u >"$work/manifest-producers"
if ! cmp -s "$work/source-producers" "$work/manifest-producers"; then
   echo "proof-path evidence does not match source producers" >&2
   diff -u "$work/source-producers" "$work/manifest-producers" >&2 || true
   exit 1
fi

producer_calls=$(grep -Ec '^[[:space:]]+Record_Proved_Safe$' "$source_file")
producer_tags=$(wc -l <"$work/source-producers" | tr -d ' ')
if [ "$producer_calls" -ne "$producer_tags" ]; then
   echo "Record_Proved_Safe producer/tag count mismatch:" \
     "$producer_calls calls, $producer_tags tags" >&2
   exit 1
fi
if ! awk '
  /^[[:space:]]+Record_Proved_Safe$/ {
     if (previous !~ /proof-path: [a-z0-9-]+/) missing = 1
  }
  { previous = $0 }
  END { exit missing }
' "$source_file"; then
   echo "every Record_Proved_Safe call must have an adjacent proof-path tag" >&2
   exit 1
fi

awk -F '\t' '!/^#/ && NF {print $1}' "$manifest" | sort >"$work/routes"
if [ "$(wc -l <"$work/routes" | tr -d ' ')" -ne \
     "$(uniq "$work/routes" | wc -l | tr -d ' ')" ]
then
   echo "proof-path evidence contains duplicate route IDs" >&2
   exit 1
fi

run_fixture()
{
   fixture=$1
   mode=$2
   key=$(basename "$fixture" .adb)
   output="$work/$mode-$key.json"
   if [ ! -f "$output" ]; then
      status=0
      if [ "$mode" = unavailable ]; then
         ADALANG_CVC5=/nonexistent/cvc5 ADALANG_Z3=/nonexistent/z3 \
           "$analyzer" --verify -q --format=json --output="$output" \
           "$fixture" >/dev/null 2>&1 || status=$?
      else
         "$analyzer" --verify -q --format=json --output="$output" \
           "$fixture" >/dev/null 2>&1 || status=$?
      fi
      if [ "$status" -gt 1 ]; then
         echo "proof-path fixture failed: $fixture ($mode), status $status" >&2
         exit "$status"
      fi
   fi
   printf '%s\n' "$output"
}

matching_obligation()
{
   output=$1
   kind=$2
   operation=$3
   grep -F "\"kind\": \"$kind\"" "$output" |
     grep -F "\"operation\": \"$operation\"" || true
}

tab=$(printf '\t')
routes=0
while IFS="$tab" read -r route producer kind positive_method \
  positive_fixture positive_operation adversarial_fixture \
  adversarial_operation adversarial_status unsupported_fixture \
  unsupported_operation solver_required note
do
   case "$route" in
      ''|'#'*) continue ;;
   esac

   positive_output=$(run_fixture "$positive_fixture" normal)
   positive=$(matching_obligation \
     "$positive_output" "$kind" "$positive_operation")
   if ! printf '%s\n' "$positive" |
     grep -F '"status": "proved-safe"' |
     grep -F "\"method\": \"$positive_method\"" >/dev/null
   then
      echo "positive proof-path evidence missing: $route ($producer)" >&2
      echo "  expected $kind/$positive_method: $positive_operation" >&2
      exit 1
   fi

   adversarial_output=$(run_fixture "$adversarial_fixture" normal)
   adversarial=$(matching_obligation \
     "$adversarial_output" "$kind" "$adversarial_operation")
   if [ -z "$adversarial" ] ||
     ! printf '%s\n' "$adversarial" |
       grep -F "\"status\": \"$adversarial_status\"" >/dev/null
   then
      echo "adversarial proof-path evidence missing: $route ($producer)" >&2
      echo "  expected $kind/$adversarial_status: $adversarial_operation" >&2
      echo "  note: $note" >&2
      exit 1
   fi
   if printf '%s\n' "$adversarial" |
     grep -F '"status": "proved-safe"' >/dev/null
   then
      echo "false-safe proof-path regression: $route ($producer)" >&2
      exit 1
   fi

   if [ "$unsupported_fixture" != - ]; then
      unsupported_output=$(run_fixture "$unsupported_fixture" normal)
      unsupported=$(matching_obligation \
        "$unsupported_output" "$kind" "$unsupported_operation")
      if ! printf '%s\n' "$unsupported" |
        grep -F '"status": "unproved"' |
        grep -E '"reasonCode": "[^"]+"' >/dev/null
      then
         echo "unsupported-boundary evidence missing: $route ($producer)" >&2
         exit 1
      fi
   fi

   if [ "$solver_required" = yes ]; then
      unavailable_output=$(run_fixture "$positive_fixture" unavailable)
      unavailable=$(matching_obligation \
        "$unavailable_output" "$kind" "$positive_operation")
      if ! printf '%s\n' "$unavailable" |
        grep -F '"status": "unproved"' >/dev/null
      then
         echo "solver-unavailable evidence missing: $route ($producer)" >&2
         exit 1
      fi
      if printf '%s\n' "$unavailable" |
        grep -E '"status": "proved-safe"|"method": "external-prover"' \
          >/dev/null
      then
         echo "unavailable solver proved path safe: $route ($producer)" >&2
         exit 1
      fi
   elif [ "$solver_required" != no ]; then
      echo "invalid solver_required value for $route: $solver_required" >&2
      exit 1
   fi

   routes=$((routes + 1))
done <"$manifest"

echo "proof-path evidence: $routes routes cover $producer_tags producers"
