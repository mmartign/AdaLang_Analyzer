#!/usr/bin/awk -f
#
# Builds GNATcheck's rule arguments from benchmarks/gnatcheck_rule_map.tsv
# (the only argument). With -v part=rules: "-r <column 2>" for each plain
# rule. With -v part=options: one "-rules ..." line per extra GNATcheck pass
# for the column-4 options, the rule options that make GNATcheck report the
# column-2 tags (e.g. "+RWarnings:u" reports "[warnings:u]"), or nothing.
# Plain rules must stay on -r: a bare "+R<rule>" does not apply the rule's
# default parameter (min_identifier_length then reports nothing). The
# parts are separate GNATcheck runs: in one invocation, the options made
# this locally built GNATcheck's workers overflow their stack and drop
# findings on 8 of the 10 corpora (see benchmarks/README.md).
#
# GNATcheck accumulates repeated +RWarnings options but keeps only the last
# +RStyle_Checks one, so the parameters of both compound rules are merged
# into a single option each. recursive_subprograms is excluded: this
# locally-built gnatcheck's global call-graph analysis stack-overflows on
# it even with a raised ulimit (see RESULTS_gnatcheck_*.md).

BEGIN { FS = "\t" }

NR > 1 && $2 != "recursive_subprograms" {
   if ($4 == "") {
      plain[$2] = 1
      next
   }
   option = $4
   if (match(option, /^\+R(Warnings|Style_Checks):/)) {
      name = substr(option, 3, RLENGTH - 3)
      param = substr(option, RLENGTH + 1)
      if (index(merged[name], param) == 0) merged[name] = merged[name] param
   } else {
      options[option] = 1
   }
}

END {
   if (part == "rules") {
      separator = ""
      for (rule in plain) {
         printf "%s-r %s", separator, rule
         separator = " "
      }
      printf "\n"
   } else if (part == "options") {
      #  One line per GNATcheck pass: each LKQL option alone, so a worker
      #  crash on one rule cannot drop another's findings, and the
      #  compiler-driven Warnings and Style_Checks options together.
      for (option in options) printf "-rules %s\n", option
      line = ""
      for (name in merged) line = line " +R" name ":" merged[name]
      if (line != "") printf "-rules%s\n", line
   } else {
      print "gnatcheck_rule_args.awk: set -v part=rules or -v part=options" \
        > "/dev/stderr"
      exit 1
   }
}
