#!/usr/bin/awk -f
#
# Matches AdaLang Analyzer's --verify proof obligations (arg 1: the
# --format=json report) against GNATprove's --mode=prove --output=oneline
# log (arg 2), by (basename(file), line, normalized check kind), and
# reports per-bucket agreement counts. See benchmarks/sparknacl/README.md
# for the matching design and its caveats.

function basename(path,    n, parts) {
   n = split(path, parts, "/")
   return parts[n]
}

# Render a SUBSEP-joined (file, line, kind) key as "file:line kind".
function fmt_key(key,    parts) {
   split(key, parts, SUBSEP)
   return parts[1] ":" parts[2] " " parts[3]
}

# Extract a "key": "value" string field from a single-line JSON object.
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

# Extract a "key": <integer> numeric field from a single-line JSON object.
function jsonnum(line, key,    re, s) {
   re = "\"" key "\": [0-9]+"
   if (match(line, re)) {
      s = substr(line, RSTART, RLENGTH)
      sub("^\"" key "\": ", "", s)
      return s + 0
   }
   return -1
}

# Map a GNATprove oneline message to the matching AdaLang Kind_Name string,
# or "" if this message has no AdaLang counterpart (e.g. a flow message).
function gp_kind(msg) {
   if (msg ~ /overflow check/)      return "integer-overflow"
   if (msg ~ /division check/)      return "division-by-zero"
   if (msg ~ /index check/)         return "index-check"
   if (msg ~ /range check/)         return "range-check"
   if (msg ~ /discriminant check/)  return "discriminant-check"
   if (msg ~ /loop invariant/) {
      if (msg ~ /initialization/ || msg ~ /first iteration/)
         return "loop-invariant-initialization"
      return "loop-invariant-preservation"
   }
   if (msg ~ /loop variant/)        return "loop-variant"
   if (msg ~ /postcondition/)       return "postcondition"
   if (msg ~ /precondition/)        return "precondition"
   if (msg ~ /assertion/)           return "assertion"
   return ""
}

BEGIN {
   FS = ""  # unused; parsing is done with match()/split() per line, not $n
}

# --- Pass over file 1: AdaLang's proofObligations JSON, one object/line ---
FNR == NR {
   if ($0 ~ /^    \{"id":/) {
      kind   = jsonstr($0, "kind")
      status = jsonstr($0, "status")
      file   = jsonstr($0, "file")
      line   = jsonnum($0, "line")
      key    = basename(file) SUBSEP line SUBSEP kind
      a_count[key]++
      a_status[key] = (a_count[key] == 1) ? status : a_status[key] SUBSEP status
      a_id[key] = (a_count[key] == 1) ? jsonstr($0, "id") : a_id[key]
      a_total++
   }
   next
}

# --- Pass over file 2: GNATprove's --output=oneline log ---
{
   if (match($0, /^[^:]+:[0-9]+:[0-9]+: (info|low|medium|high): /)) {
      n = split($0, f, ":")
      gfile = f[1]
      gline = f[2] + 0
      rest = $0
      sub(/^[^:]+:[0-9]+:[0-9]+: /, "", rest)
      colon = index(rest, ": ")
      sev = substr(rest, 1, colon - 1)
      msg = substr(rest, colon + 2)
      g_total++
      g_sev_count[sev]++

      k = gp_kind(msg)
      if (k == "") {
         label = msg
         sub(/,.*/, "", label)         # keep just the lead clause
         g_unmapped[label]++
         g_unmapped_total++
         next
      }

      key = basename(gfile) SUBSEP gline SUBSEP k
      g_count[key]++
      verdict = (sev == "info") ? "proved" : "not-proved"
      g_verdict[key] = (g_count[key] == 1) ? verdict : g_verdict[key] SUBSEP verdict
      g_example[key] = (g_count[key] == 1) ? $0 : g_example[key]
      all_keys[key] = 1
   }
}

END {
   for (key in a_count) all_keys[key] = 1

   both = 0; conservative = 0; unsound = 0; false_positive = 0; both_flag = 0
   mismatch = 0
   adalang_only_total = 0
   gnatprove_only_total = 0
   delete adalang_only_kind
   delete gnatprove_only_kind

   for (key in all_keys) {
      ac = a_count[key] + 0
      gc = g_count[key] + 0

      if (ac == 0 && gc > 0) {
         split(key, parts, SUBSEP)
         gnatprove_only_kind[parts[3]]++
         gnatprove_only_total++
         gnatprove_only_list[gnatprove_only_total] = fmt_key(key) " :: " g_example[key]
         continue
      }
      if (ac > 0 && gc == 0) {
         split(key, parts, SUBSEP)
         adalang_only_kind[parts[3]]++
         adalang_only_total++
         continue
      }
      if (ac != 1 || gc != 1) {
         mismatch++
         mismatch_list[mismatch] = fmt_key(key) ": adalang=" ac " gnatprove=" gc
         continue
      }

      astat = a_status[key]
      gverd = g_verdict[key]
      safe_ada = (astat == "proved-safe")
      proved_gp = (gverd == "proved")

      if (safe_ada && proved_gp) {
         both++
      } else if (!safe_ada && proved_gp && (astat == "unproved" || astat == "unsupported")) {
         conservative++
      } else if (safe_ada && !proved_gp) {
         unsound++
         unsound_list[unsound] = fmt_key(key) " id=" a_id[key] " :: " g_example[key]
      } else if (astat == "definite-error" && proved_gp) {
         false_positive++
         fp_list[false_positive] = fmt_key(key) " id=" a_id[key] " :: " g_example[key]
      } else {
         both_flag++
         both_flag_list[both_flag] = fmt_key(key) " adalang=" astat " :: " g_example[key]
      }
   }

   print "SPARKNaCl / GNATprove agreement report"
   print "======================================="
   print ""
   printf "AdaLang proof obligations parsed:      %d\n", a_total
   printf "GNATprove prove-mode messages parsed:  %d\n", g_total
   for (sev in g_sev_count)
      printf "  %-8s %d\n", sev, g_sev_count[sev]
   print ""
   printf "Matched 1:1 pairs (file, line, kind):  %d\n", (both + conservative + unsound + false_positive + both_flag)
   printf "  1. Both safe (AdaLang proved-safe, GNATprove proved):            %d\n", both
   printf "  2. AdaLang conservative (unproved/unsupported, GNATprove proved): %d\n", conservative
   printf "  3. POSSIBLE ADALANG UNSOUNDNESS (proved-safe, GNATprove NOT proved): %d\n", unsound
   printf "  4. AdaLang false positive (definite-error, GNATprove proved):    %d\n", false_positive
   printf "  5. Both flag a problem (non-safe, GNATprove NOT proved):         %d\n", both_flag
   print ""
   printf "Count-mismatch keys (not auto-paired, needs manual review): %d\n", mismatch
   for (i = 1; i <= mismatch; i++) print "  " mismatch_list[i]
   print ""
   printf "AdaLang-only obligations (no GNATprove --mode=prove counterpart for this kind): %d\n", adalang_only_total
   for (k in adalang_only_kind) printf "  %-30s %d\n", k, adalang_only_kind[k]
   print ""
   printf "GNATprove-only obligations (mapped kind, no AdaLang obligation at this location): %d\n", gnatprove_only_total
   for (k in gnatprove_only_kind) printf "  %-30s %d\n", k, gnatprove_only_kind[k]
   print ""
   printf "GNATprove messages with no AdaLang kind mapping: %d\n", g_unmapped_total
   for (k in g_unmapped) printf "  %-50s %d\n", k, g_unmapped[k]
   print ""

   if (gnatprove_only_total > 0) {
      print "--- GNATprove-only detail (AdaLang recorded no obligation here at all) ---"
      for (i = 1; i <= gnatprove_only_total; i++) print "  " gnatprove_only_list[i]
      print ""
   }
   if (unsound > 0) {
      print "--- Bucket 3 detail (verify each against source before trusting it) ---"
      for (i = 1; i <= unsound; i++) print "  " unsound_list[i]
      print ""
   }
   if (false_positive > 0) {
      print "--- Bucket 4 detail ---"
      for (i = 1; i <= false_positive; i++) print "  " fp_list[i]
      print ""
   }
   if (both_flag > 0) {
      print "--- Bucket 5 detail ---"
      for (i = 1; i <= both_flag; i++) print "  " both_flag_list[i]
      print ""
   }
}
