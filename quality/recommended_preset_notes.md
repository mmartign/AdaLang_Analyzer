# Notes on the `--recommended` preset and its baseline

Engineering notes on the checks that joined `--recommended` and on the
regenerations of `recommended.baseline`, most recent first. Each entry
records why a check was admitted, what its self-analysis and
external-corpus validation found, and what was fixed on the way. They were
moved here from `README.md`, which describes the artifacts of this
directory as they are now; the baseline has 147 findings today, and the
counts below are those of the date each entry gives.

`Double_Free` joined `--recommended` on 2026-09-04, `Use_After_Free`'s
direct sibling in the same flow-sensitive defect family: where
`Use_After_Free` reports a *read* of a local access object after it was
passed to `Ada.Unchecked_Deallocation`, `Double_Free` reports a *second*
such call on the same object instead, with no intervening assignment.
Both share `Analyze_Deallocation_Call`'s single `Data_Flow.First_Access`
walk rather than each running its own traversal. This required correcting
an initial design assumption: since `Ada.Unchecked_Deallocation`'s formal
is `in out`, `First_Access` (via `Call_Reads_Simple_Actual`) classifies a
second `Free (P)` call as a *read* of `P`, not a write -- `in out` modes
are read-checked before they are ever considered a write, and that read
check wins. A second free is therefore indistinguishable from an ordinary
use-after-free by `Access_Kind` alone; only the read site's own identity
(is it itself a call recognized by the same
`Adalang_Analyzer.Checks.Is_Ada_Unchecked_Deallocation` primitive
`Use_After_Free` already used to recognize the original free?) separates
the two outcomes. Each rule's report is independently gated by its own
`Rule_States` entry, so `-checks=-*,Double_Free` and
`-checks=-*,Use_After_Free` each fire only their own finding on the
relevant fixture. Self-analysis against this project's own source is
clean at this check (`tests/run_recommended_gate.sh`); no baseline
addition was needed.

`Use_After_Free`, `Unclosed_File_Handle`, and `Unused_With_Clause` joined
`--recommended` on 2026-08-24: three new checks in the flow-sensitive
defect/hygiene family this project's
`docs/src/gnatcheck-rule-comparison.md`
identifies as its actual differentiator (GNATcheck's own unmatched
catalog is mostly deliberate-scope style/naming/OOP-metric rules, not
gaps to close). `Use_After_Free` reuses `Data_Flow.First_Access`
(the same primitive behind `Uninitialized_Read`) anchored on a call to
the procedure an `Ada.Unchecked_Deallocation` instantiation introduces,
rather than a declaration. `Unclosed_File_Handle` is a new structural
interpreter over `Ada.Text_IO`/`Ada.Streams.Stream_IO` `Open`/`Create`/
`Close` calls, modeled directly on `Uninitialized_Output`'s
all-paths-including-exception-handlers `Interpret_Initialization`
pattern (`Spark_Readiness`/`Subprogram_Summaries`). `Unused_With_Clause`
reuses `Duplicate_With_Clause`'s context-clause walk together with a new
semantic "was anything from unit U referenced" primitive
(`Declarations.Any_Reference_To_Unit`), deliberately resolving each name
rather than matching spelling, so a reference reached only through a
`use` clause still counts.

Running the new checks against this project's own self-analysis gate
(`tests/run_recommended_gate.sh`) before release, per this project's
established practice, found and fixed two real false positives in
`Unclosed_File_Handle`, both in the idiomatic "close a file that might
already be closed" pattern -- logged as `FP-060` in
`known_analysis_issues.tsv`: (1) `if Ada.Text_IO.Is_Open (File) then
Ada.Text_IO.Close (File); end if;` (seen in this project's own
`Report.Load_Baseline`), where the interpreter's missing-`else` merge
pessimistically assumed the untaken branch left the file open; and (2)
the more general "opened and closed behind the identical boolean guard"
idiom (seen in `Report.Write_Compliance_Report`'s `if To_File then ...
end if;` pairs), the same defect for a plain condition instead of an
`Is_Open` call. Both are now recognized: the first via a dedicated
`Guards_Is_Open` predicate, the second via a threaded `Open_Guard`
condition-text comparison, so a Close reachable only through the same
textual guard that gated the Open is credited as safe on both branches.
Self-analysis is otherwise clean for all three checks; the two `Merge`/
helper-function `Swappable_Parameters` findings the new code itself
triggers are baselined, consistent with the identical `Merge (Left,
Right : ...)` shape already accepted elsewhere in this codebase (e.g.
`Spark_Readiness`'s own `Init_Result` merge).

`Unclosed_File_Handle`'s v1 scope was deliberately narrow, matching this
project's habit of shipping a check narrow and widening it later
(`Address_Clause`'s `FP-054`/`FP-055` history is the precedent): only
`Ada.Text_IO`/`Ada.Streams.Stream_IO`; an `Open`/`Create` call lexically
inside a loop was skipped entirely (mirroring `Dead_Store`'s own loop
bailout); and a loop appearing *after* the open credited a `Close`
found anywhere in its body without proving the loop executes -- a
false-negative-biased simplification rather than `Uninitialized_
Output`'s heavier array-coverage loop proofs. Both loop gaps were
closed on 2026-08-28: `Interpret_Closure`'s loop case now runs the body
through the same interpreter as a normal statement list, using the
result of one application as the entry state for a second to find a
genuine two-state fixed point (sound here because nothing besides the
single "currently open" flag threads between statements, and `Open_At`
-- the only thing that can force it back to unsafe -- is reached the
same way regardless of the incoming flag), then merges that
"one-or-more-iterations" outcome with the unchanged "zero-iterations"
outcome for `while`/`for` loops (a bare, unconditional `loop` has no
such outcome to merge, since without an internal `exit` its own body
completing normally only repeats it forever). An `exit` statement
anywhere in the body (`Contains_Exit_Statement`) still falls back to
the older, purely textual heuristic rather than reasoning about where
control actually goes. Closing the loop-scoped-open bailout let a
`Direct_IO`/`Sequential_IO` follow-up mentioned in an earlier revision
of this section land too (`Ada.Text_IO`/`Ada.Streams.Stream_IO`'s
generic, per-element-type siblings, resolved the same way
`Ada.Unchecked_Deallocation` is).

Both gaps opened by that same 2026-08-28 pass were closed the same day
after further investigation, rather than left standing. `FP-062` (a
generic package instantiated via a bare name reached only through a
`use Ada.Direct_IO;`/`use Ada.Sequential_IO;` clause) turned out to be
two independent Libadalang `Property_Error`s, not one: resolving the
call itself fails (the gap first found), and separately, resolving just
the instantiation object's own name and asking its designated generic
decl for its own defining name *also* raises "dereferencing a null
access" for this same bare-name shape. Fixed by resolving the call's
dotted prefix instead of the whole name when the first resolution
fails, and by reading the generic name's own syntactic spelling at the
instantiation site (accepting either the qualified or bare form) when
even that second, narrower resolution raises -- an accepted precision
tradeoff in that last fallback specifically, since no semantic
confirmation is possible there against an unrelated, identically-named
generic also in scope. `FP-063` (every `while`/`for` loop conservatively
assumed able to run zero iterations) was closed by reusing
`Flow_Eval.Choice_Interval` -- the same static-bounds proof
`Spark_Readiness`'s own `Uninitialized_Output` for-loop coverage check
already uses for the identical purpose -- to recognize a numeric
for-loop whose `Low .. High` range is statically known non-empty, and
treating it the same as a bare, unconditional loop. Deliberately still
limited to the same literal-bounds scope `Choice_Interval` already has
elsewhere in this codebase: a range bounded by a variable or an
untracked subtype's own declared lower bound is not proven non-empty
and still conservatively fires.

Adding `Empty_Then_Body`/`Empty_Else_Body` on 2026-08-24 (see
`precision_corpus_notes.md`) required
regenerating `recommended.baseline` even though neither new check produced an
unsuppressed self-analysis finding: `Duplicate_Subprogram`'s own message text
embeds the sibling occurrence's file:line (e.g. "...identical to
'Handles_Others's at src/adalang_analyzer-checks-control_flow.adb:1235"), and
`Stable_Fingerprint` hashes the message verbatim, so inserting the ~19 new
lines above that pair's earlier occurrence in `control_flow.adb` shifted the
referenced line number and therefore the fingerprint -- one baseline entry
changed, none added or removed (confirmed: `--write-baseline` before and
after this change produce baselines of the same length, differing in exactly
one hash). This narrowly contradicted this project's own documented guarantee
(README.md: "Fingerprints exclude line and column numbers, so inserting
unrelated lines does not turn an existing finding into a new one") for the
one check whose message text itself contained a location string. Fixed the
same day in `Adalang_Analyzer.Clone_Detection.Analyze`: the earlier
occurrence's file:line moved out of `Message` (hashed by
`Stable_Fingerprint`) and into `Report_Rule_Violation`'s `Evidence`
parameter (displayed identically, in its own "evidence:" line, but
deliberately excluded from the fingerprint -- the same mechanism every
other check's supplementary detail already uses). Verified directly, not
just by inspection: inserting three unrelated comment lines directly above
the `Handles_Others` pair's earlier occurrence in `control_flow.adb` (so its
reported line moved from 1235 to 1238) reproduced the original bug before
the fix (one baseline mismatch, `Violations : 1`) and produced zero
mismatches after it (`Violations : 0`, `Baseline matches: 138`), toggled
both ways on the same input. `run_clone_detection.sh` now asserts the
location lives in the evidence line, not the message, so this cannot
regress silently again. `recommended.baseline` needed a second regeneration
for this fix itself (same-day, same file-count-unchanged shape as above):
the message wording change ("identical to 'Y's at ..." to "identical to
'Y' ...", with the location now separate) altered the fingerprint of all
17 `Duplicate_Subprogram` self-findings at once, not just the one that
motivated the fix. Logged as `FP-058` in `quality/known_analysis_issues.tsv`
despite not being a check-correctness issue in that file's usual sense (the
underlying finding was always correct) -- a baseline fingerprint-stability
bug that makes an unchanged finding present as if it were new is
functionally a false "new finding" the same way an unbaselined regression
would look, so it is tracked there rather than left undocumented.

`Duplicate_Subprogram` joined `--recommended` on 2026-08-17, growing the
baseline from 121 to 138. External-corpus validation first (all ten
benchmark corpora in `benchmarks/`, ~950 files, run in isolation via
`-checks="-*,Duplicate_Subprogram"`): 394 findings across nine of the ten
corpora, no false-positive class found on inspection anywhere
(cross-platform duplicate implementations, generated protocol code, and a
real "same statement shape, differing only in an uncompared local
declaration" pattern, all genuine). That run also found
and fixed `FP-052`, a message-clarity bug the check's very first external
corpus (AdaCore/Ada_Drivers_Library's per-chip-family driver layout)
happened to trigger. The 17 findings on this project's own source --
unchanged from the count already reviewed and confirmed genuine when the
check was first added (`Effective_SPARK_Enabled`, `Contract_Expression`,
`Formal_Mode`, `Formal_At`, `Is_Parameter_Key`, and others independently
reimplemented, identically, across `SPARK_Readiness`,
`SPARK_Dependency_Analysis`, `Flow_Interp`, and `Checks.Data_Flow`) -- are
baselined rather than extracted, the same call the project made when the
check was first self-analyzed.

`Swappable_Parameters` joined `--recommended` on 2026-08-15, growing the
baseline from 22 to 121 in one jump: 107 of the addition is that one check.
External-corpus validation first (benchmarks against gnatcoll-core and AWS,
~1,700 files combined) showed the check's parameter-name pairs are not
dominated by the trivially-safe `Left`/`Right` idiom this project's own
smaller, keyword-argument-heavy source had suggested -- real risky pairs
turned up (`User`/`Pwd`, `Stdin`/`Stdout`/`Stderr`, `Src`/`Dst`). Reviewing
this project's own 107 before baselining them found one category worth
naming specifically: `Adalang_Analyzer.Control_Flow_Graph`'s `Build_List`/
`Build_Handled`/`Build_Else_Chain` family takes 2-3 same-typed, same-mode
`Continuation`/`Exception_Target`/`Return_Target`/`Outer_Exception`
parameters and is called positionally throughout -- exactly the shape the
check exists to catch, in the CFG builder the bounded verifier depends on.
No misordering was found there on review, so it's baselined rather than
reordered, but it is the strongest real-world confirmation yet that the
check earns its place in `--recommended` rather than just adding volume.
The rest of the 107 fall into two lower-risk, still-legitimate categories:
conventional commutative/comparison-idiom pairs (`Left`/`Right`, `X`/`Y`)
and long keyword-style helper signatures (`Explanation`, `Evidence`,
`Abstract_State`, ...) that are, in this codebase, always called with named
association already, confirmed by spot-checking call sites rather than
assumed.
