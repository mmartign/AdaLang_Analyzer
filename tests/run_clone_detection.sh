#!/bin/sh
set -eu

analyzer=${ANALYZER:-./bin/adalang_analyzer}
output=$(mktemp "${TMPDIR:-/tmp}/adalang-clone-detection.XXXXXX")
trap 'rm -f "$output"' EXIT HUP INT TERM

#  Duplicate_Subprogram is a whole-project pass, like Circular_Package_
#  Dependency: the duplication only exists across every analyzed file's own
#  subprogram bodies, so it must be exercised with both files of a pair
#  given on the same command line (a single-file run can never see it).
#
#  This pair also reproduces FP-052: two files in different directories
#  that share a simple name (a per-target board/chip variant layout, e.g.
#  AdaCore/Ada_Drivers_Library's "stm32-crc.adb" appearing once per chip
#  family directory, is the real corpus shape that found this). Before the
#  fix, the "matches X at Y" half of the message dropped the directory via
#  Ada.Directories.Simple_Name, so the two same-named files read as if a
#  body were reported as a duplicate of itself. The earlier occurrence's
#  file:line moved from the message into a separate Evidence line (see the
#  fingerprint-stability fix below), so this now checks the evidence line.
if "$analyzer" -checks='Duplicate_Subprogram' \
     tests/duplicate_subprogram_cross_file/variant_a/shared_body.adb \
     tests/duplicate_subprogram_cross_file/variant_b/shared_body.adb \
     >"$output" 2>&1
then
   echo "expected the cross-file duplicate body pair to produce a violation" >&2
   cat "$output" >&2
   exit 1
fi

if [ "$(grep -c '\[Duplicate_Subprogram\]' "$output")" -ne 1 ]
then
   echo "expected exactly one Duplicate_Subprogram finding" >&2
   cat "$output" >&2
   exit 1
fi

if ! grep -F "variant_b/shared_body.adb:1:1: warning:" "$output" >/dev/null \
  || ! grep -F "identical to 'Shared_Body' (" "$output" >/dev/null \
  || ! grep -F \
       "evidence: earlier occurrence: " "$output" >/dev/null \
  || ! grep -F "variant_a/shared_body.adb:1" "$output" >/dev/null
then
   echo "FP-052 regression: the earlier-occurrence evidence no longer" >&2
   echo "disambiguates variant_a from variant_b by directory" >&2
   cat "$output" >&2
   exit 1
fi

#  Fingerprint stability (the bug found and fixed 2026-08-24 while adding
#  Empty_Then_Body/Empty_Else_Body): the earlier occurrence's file:line must
#  live in Evidence, not Message, since Stable_Fingerprint hashes Message
#  verbatim and a raw line number there would shift -- and desync
#  --baseline -- whenever unrelated code is inserted above that occurrence
#  in its own file.
if grep -F "'s at" "$output" >/dev/null
then
   echo "message text still embeds a location (\"'s at ...\"), which" >&2
   echo "would make this finding's baseline fingerprint unstable against" >&2
   echo "unrelated line insertions above the earlier occurrence" >&2
   cat "$output" >&2
   exit 1
fi

#  A cross-file pair given without its clone partner on the command line
#  cannot possibly be flagged: the comparison set is only the files
#  actually being analyzed in this run.
if ! "$analyzer" -q -checks='Duplicate_Subprogram' \
     tests/duplicate_subprogram_cross_file/variant_a/shared_body.adb
then
   echo "single clone-pair member analyzed alone unexpectedly produced a violation" >&2
   exit 1
fi

echo "clone-detection tests passed"
