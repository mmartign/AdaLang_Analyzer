#!/bin/sh
set -eu

#  Regression coverage for the Alire-toolchain PATH fallback in
#  Adalang_Analyzer_CLI.Locate_Alire_Gnatls_Dir (see known_analysis_issues.tsv,
#  FP-029): when "gnatls" is not on bare PATH but an Alire-managed toolchain
#  is selected in the user's settings.toml, the CLI is meant to self-augment
#  PATH from the toolchain cache instead of emitting the "no gnatls found"
#  warning -- and to still emit that warning when no such toolchain can be
#  found at all. Both directions were previously confirmed only by hand
#  (see the FP-029 entry); this script automates both so a future change to
#  Locate_Alire_Gnatls_Dir cannot silently regress either one.

analyzer_rel=${ANALYZER:-./bin/adalang_analyzer}
analyzer=$(cd "$(dirname "$analyzer_rel")" && pwd)/$(basename "$analyzer_rel")
fixture=$(cd tests && pwd)/external_subtype_signature_match_robustness.adb
output=$(mktemp "${TMPDIR:-/tmp}/adalang-alire-fallback.XXXXXX")
empty_home=$(mktemp -d "${TMPDIR:-/tmp}/adalang-alire-fallback-home.XXXXXX")
trap 'rm -f "$output"; rm -rf "$empty_home"' EXIT HUP INT TERM

if [ -z "${HOME:-}" ] || [ ! -f "$HOME/.config/alire/settings.toml" ]; then
   echo "run_alire_gnatls_fallback.sh: no \$HOME/.config/alire/settings.toml" \
        "in this environment; skipping" >&2
   exit 0
fi

#  A PATH with every directory that provides "gnatls" removed, so the bare
#  Locate_Exec_On_Path lookup in the CLI is guaranteed to fail regardless of
#  the invoking environment's own toolchain setup, forcing both cases below
#  to actually exercise Locate_Alire_Gnatls_Dir rather than the plain PATH
#  lookup succeeding first.
stripped_path=""
old_ifs=$IFS
IFS=:
for dir in $PATH; do
   if [ ! -x "$dir/gnatls" ]; then
      stripped_path="${stripped_path:+$stripped_path:}$dir"
   fi
done
IFS=$old_ifs

#  Positive case: PATH stripped, but the real $HOME (and therefore its real
#  Alire settings.toml / toolchains cache) is visible, so
#  Locate_Alire_Gnatls_Dir should find the selected toolchain's gnatls,
#  self-augment PATH with it, and let resolution succeed -- no warning, and
#  no "skipping subprogram summary registration" fallback log line either.
env -i PATH="$stripped_path" HOME="$HOME" \
   "$analyzer" -v --recommended "$fixture" >"$output" 2>&1 || true
if grep -F "no 'gnatls' found on PATH" "$output" >/dev/null; then
   echo "Alire-toolchain PATH fallback did not resolve gnatls from a real \$HOME" >&2
   cat "$output" >&2
   exit 1
fi
if grep -F "skipping subprogram summary registration" "$output" >/dev/null; then
   echo "external-subtype resolution still failed despite the Alire PATH fallback" >&2
   cat "$output" >&2
   exit 1
fi

#  Negative case: PATH stripped and $HOME pointing at a directory with no
#  Alire settings at all, so the fallback has nothing to find and the
#  pre-existing "no gnatls" warning must still fire.
env -i PATH="$stripped_path" HOME="$empty_home" \
   "$analyzer" -v --recommended "$fixture" >"$output" 2>&1 || true
if ! grep -F "no 'gnatls' found on PATH" "$output" >/dev/null; then
   echo "missing-toolchain warning did not fire with no Alire settings present" >&2
   cat "$output" >&2
   exit 1
fi

echo "Alire gnatls PATH-fallback tests passed"
