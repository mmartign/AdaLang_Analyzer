#!/usr/bin/awk -f
#
# Sum the per-unit compare.awk reports produced by run.sh into one corpus
# total, split by manifest class (clean vs weak). First file argument is
# MANIFEST.tsv; the rest are benchmark-results/spark_testsuite/per-test/*.txt.
#
# compare.awk already did the (basename, line, kind) matching *within* each
# unit; this script only adds up its bucket counts, so cross-unit basename
# collisions are irrelevant here.

function tail_num(line,    n, a) {
   n = split(line, a, ":")
   gsub(/[^0-9-]/, "", a[n])
   return a[n] + 0
}

# --- pass 1: manifest (always the first file argument) -> class per unit ---
FNR == NR {
   if ($0 ~ /^#/ || $0 == "") next
   split($0, m, "\t")
   cls[m[1]] = m[2]
   next
}

FNR == 1 {
   unit = FILENAME
   sub(/.*\//, "", unit)
   sub(/\.txt$/, "", unit)
   c = (unit in cls) ? cls[unit] : "unknown"
   units[c]++
   total_units++
}

/^AdaLang proof obligations parsed:/       { ob[c]      += tail_num($0); ob_all      += tail_num($0) }
/^Matched 1:1 pairs \(file, line, kind\):/ { matched[c] += tail_num($0); matched_all += tail_num($0) }
/^  1\. Both safe /                        { b1[c] += tail_num($0); b1_all += tail_num($0) }
/^  2\. AdaLang conservative /             { b2[c] += tail_num($0); b2_all += tail_num($0) }
/^  3\. POSSIBLE ADALANG UNSOUNDNESS /     { b3[c] += tail_num($0); b3_all += tail_num($0); if (tail_num($0) > 0) flagged[unit] = flagged[unit] " unsound=" tail_num($0) }
/^  4\. AdaLang false positive /           { b4[c] += tail_num($0); b4_all += tail_num($0); if (tail_num($0) > 0) flagged[unit] = flagged[unit] " false-positive=" tail_num($0) }
/^  5\. Both flag a problem /              { b5[c] += tail_num($0); b5_all += tail_num($0) }
/^Count-mismatch keys /                    { mm[c] += tail_num($0); mm_all += tail_num($0) }
/^AdaLang-only obligations /               { ao[c] += tail_num($0); ao_all += tail_num($0) }
/^GNATprove-only obligations /             { go[c] += tail_num($0); go_all += tail_num($0) }

END {
   print "spark_testsuite / GNATprove agreement report (aggregate over " total_units " units)"
   print "========================================================================"
   print ""
   printf "Units run:                 %d  (clean %d, weak %d)\n", \
      total_units, units["clean"], units["weak"]
   print ""
   printf "%-42s %8s %8s %8s\n", "", "clean", "weak", "all"
   printf "%-42s %8d %8d %8d\n", "AdaLang proof obligations parsed",   ob["clean"], ob["weak"], ob_all
   printf "%-42s %8d %8d %8d\n", "Matched 1:1 pairs (file,line,kind)", matched["clean"], matched["weak"], matched_all
   printf "%-42s %8d %8d %8d\n", "  1. Both safe",                     b1["clean"], b1["weak"], b1_all
   printf "%-42s %8d %8d %8d\n", "  2. AdaLang conservative",          b2["clean"], b2["weak"], b2_all
   printf "%-42s %8d %8d %8d\n", "  3. POSSIBLE ADALANG UNSOUNDNESS",  b3["clean"], b3["weak"], b3_all
   printf "%-42s %8d %8d %8d\n", "  4. AdaLang false positive",        b4["clean"], b4["weak"], b4_all
   printf "%-42s %8d %8d %8d\n", "  5. Both flag a problem",           b5["clean"], b5["weak"], b5_all
   printf "%-42s %8d %8d %8d\n", "Count-mismatch keys (manual review)", mm["clean"], mm["weak"], mm_all
   printf "%-42s %8d %8d %8d\n", "AdaLang-only obligations",           ao["clean"], ao["weak"], ao_all
   printf "%-42s %8d %8d %8d\n", "GNATprove-only obligations",         go["clean"], go["weak"], go_all
   print ""
   #  Flat restatements grep'd by run.sh's pass/fail gate.
   printf "POSSIBLE ADALANG UNSOUNDNESS: %d\n", b3_all
   printf "AdaLang false positives: %d\n", b4_all
   print ""
   if (length(flagged) > 0) {
      print "--- units to inspect (bucket 3 / bucket 4 non-zero) ---"
      for (u in flagged) print "  " u ":" flagged[u] "  (see per-test/" u ".txt)"
   } else {
      print "No unit showed possible unsoundness or a false positive."
   }
}
