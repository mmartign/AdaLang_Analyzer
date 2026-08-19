#!/usr/bin/awk -f
#
# Matches AdaLang Analyzer's rule findings (arg 1: a --format=json report,
# restricted to the checks in benchmarks/gnatcheck_rule_map.tsv) against
# GNATcheck's findings for the mapped rules (arg 2: a --show-rule text log,
# `file:line:col: rule violation: message [rule_name]`) using the rule
# pairs in arg 3 (benchmarks/gnatcheck_rule_map.tsv), keyed on
# (basename(file), line, rule pair).
#
# GNATcheck is treated as ground truth (AdaCore's own, mature, widely-used
# rule-based linter): an AdaLang finding with no corresponding GNATcheck
# finding at the same (file, line) under a mapped rule is a potential
# AdaLang false positive; a GNATcheck finding with no corresponding
# AdaLang finding is a potential AdaLang false negative (miss). Rule pairs
# are "direct"/"close" name-level matches, not proven semantic
# equivalence -- see GNATCHECK_RULE_COMPARISON.md and the per-corpus
# README for caveats.

function basename(path,    n, parts) {
   n = split(path, parts, "/")
   return parts[n]
}

function jsonstr(line, key,    re, s) {
   re = "\"" key "\": \"[^\"]*\""
   if (match(line, re)) {
      s = substr(line, RSTART, RLENGTH)
      sub("^\"" key "\": \"", "", s)
      sub("\"$", "", s)
      return s
   }
   return ""
}

function jsonnum(line, key,    re, s) {
   re = "\"" key "\": [0-9]+"
   if (match(line, re)) {
      s = substr(line, RSTART, RLENGTH)
      sub("^\"" key "\": ", "", s)
      return s + 0
   }
   return -1
}

BEGIN {
   adalang_json = ARGV[1]
   gnatcheck_log = ARGV[2]
   rule_map_tsv = ARGV[3]
   ARGV[1] = ARGV[2] = ARGV[3] = ""

   #  Load the rule map. gc_to_ada[gc_rule] / ada_to_gc[ada_rule] are
   #  space-separated lists (usually singletons) of the paired rule(s) on
   #  the other side; strength[ada,gc] is "direct" or "close".
   getline header < rule_map_tsv
   while ((getline mapline < rule_map_tsv) > 0) {
      split(mapline, f, "\t")
      ada = f[1]; gc = f[2]; str = f[3]
      gc_to_ada[gc] = gc_to_ada[gc] " " ada
      ada_to_gc[ada] = ada_to_gc[ada] " " gc
      strength[ada, gc] = str
      all_ada[ada] = 1
      all_gc[gc] = 1
   }
   close(rule_map_tsv)

   #  Load AdaLang findings into ada_present[file,line,rule].
   while ((getline line < adalang_json) > 0) {
      if (line !~ /"ruleId":/) continue
      rule = jsonstr(line, "ruleId")
      if (!(rule in all_ada)) continue
      file = basename(jsonstr(line, "file"))
      ln = jsonnum(line, "line")
      key = file SUBSEP ln SUBSEP rule
      if (!(key in ada_present)) ada_total[rule]++
      ada_present[key]++
   }
   close(adalang_json)

   #  Load GNATcheck findings into gc_present[file,line,rule].
   gc_re = "^[^:]+:[0-9]+:[0-9]+: rule violation: .* \\[[a-z0-9_]+\\]$"
   while ((getline line < gnatcheck_log) > 0) {
      if (line !~ gc_re) continue
      split(line, parts, ":")
      file = basename(parts[1])
      ln = parts[2] + 0
      rule_start = index(line, "[")
      gc_rule = substr(line, rule_start + 1, length(line) - rule_start - 1)
      if (!(gc_rule in all_gc)) continue
      key = file SUBSEP ln SUBSEP gc_rule
      if (!(key in gc_present)) gc_total[gc_rule]++
      gc_present[key]++
   }
   close(gnatcheck_log)

   #  For every AdaLang finding key, matched if ANY paired GNATcheck rule
   #  fired at the same (file, line).
   for (key in ada_present) {
      split(key, kp, SUBSEP)
      file = kp[1]; ln = kp[2]; ada_rule = kp[3]
      n = split(ada_to_gc[ada_rule], gcs, " ")
      hit = 0
      for (i = 1; i <= n; i++) {
         if (gcs[i] == "") continue
         if ((file SUBSEP ln SUBSEP gcs[i]) in gc_present) hit = 1
      }
      if (hit) ada_matched[ada_rule]++
      else     ada_only[ada_rule]++
   }

   #  Symmetric pass: for every GNATcheck finding key, matched if ANY
   #  paired AdaLang rule fired at the same (file, line).
   for (key in gc_present) {
      split(key, kp, SUBSEP)
      file = kp[1]; ln = kp[2]; gc_rule = kp[3]
      n = split(gc_to_ada[gc_rule], adas, " ")
      hit = 0
      for (i = 1; i <= n; i++) {
         if (adas[i] == "") continue
         if ((file SUBSEP ln SUBSEP adas[i]) in ada_present) hit = 1
      }
      if (hit) gc_matched[gc_rule]++
      else     gc_only[gc_rule]++
   }

   total_ada = 0; total_ada_matched = 0
   total_gc = 0; total_gc_matched = 0

   print "=== GNATcheck oracle comparison (per AdaLang rule) ==="
   printf "%-30s %-6s %10s %10s %10s\n", \
     "AdaLang rule", "Match", "AdaLang-N", "AdaOnly", "AdaMatch%"
   for (ada in all_ada) {
      n_total = ada_total[ada] + 0
      n_matched = ada_matched[ada] + 0
      n_only = ada_only[ada] + 0
      pct = (n_total > 0) ? sprintf("%.0f%%", 100.0 * n_matched / n_total) : "n/a"
      #  Pick a representative strength label (all mapped pairs for one
      #  AdaLang rule share the same strength in this rule map).
      n_gc = split(ada_to_gc[ada], gcs, " ")
      rep_strength = (n_gc >= 1) ? strength[ada, gcs[1]] : "?"
      printf "%-30s %-6s %10d %10d %10s\n", ada, rep_strength, n_total, n_only, pct
      total_ada += n_total
      total_ada_matched += n_matched
   }

   print ""
   print "=== GNATcheck oracle comparison (per GNATcheck rule) ==="
   printf "%-42s %10s %10s %10s\n", \
     "GNATcheck rule", "GC-N", "GCOnly", "GCMatch%"
   for (gc in all_gc) {
      n_total = gc_total[gc] + 0
      n_matched = gc_matched[gc] + 0
      n_only = gc_only[gc] + 0
      pct = (n_total > 0) ? sprintf("%.0f%%", 100.0 * n_matched / n_total) : "n/a"
      printf "%-42s %10d %10d %10s\n", gc, n_total, n_only, pct
      total_gc += n_total
      total_gc_matched += n_matched
   }

   print ""
   print "=== Totals ==="
   printf "AdaLang findings (mapped rules):   %d\n", total_ada
   printf "  matched by GNATcheck:            %d (%.1f%%)\n", \
     total_ada_matched, (total_ada > 0 ? 100.0*total_ada_matched/total_ada : 0)
   printf "  AdaLang-only (potential FP):      %d (%.1f%%)\n", \
     total_ada - total_ada_matched, \
     (total_ada > 0 ? 100.0*(total_ada-total_ada_matched)/total_ada : 0)
   printf "GNATcheck findings (mapped rules):  %d\n", total_gc
   printf "  matched by AdaLang:              %d (%.1f%%)\n", \
     total_gc_matched, (total_gc > 0 ? 100.0*total_gc_matched/total_gc : 0)
   printf "  GNATcheck-only (potential FN):    %d (%.1f%%)\n", \
     total_gc - total_gc_matched, \
     (total_gc > 0 ? 100.0*(total_gc-total_gc_matched)/total_gc : 0)
}
