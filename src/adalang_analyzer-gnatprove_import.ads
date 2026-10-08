--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded;

with Adalang_Analyzer.Proof_Obligations;

--  The verdicts of GNATprove, read from the log of a run of it and set
--  beside AdaLang's own.
--
--  GNATprove is a separate tool, of AdaCore, which this package neither
--  contains nor runs: it reads the text GNATprove wrote when the user ran
--  it on the same sources with "--output=oneline --report=all". A verdict
--  read here is GNATprove's and is reported as such. It never changes the
--  status AdaLang gave an obligation: an obligation AdaLang left unproved
--  stays unproved, with what GNATprove said of the same check next to it.
--
--  Nothing in a log says which sources it was written for. A log of other
--  sources, or of an earlier state of these, pairs badly or not at all,
--  which the counts of checks without an obligation show; it is for the
--  user to give the log of the sources analyzed.
package Adalang_Analyzer.Gnatprove_Import is

   use Ada.Strings.Unbounded;

   package Proof renames Adalang_Analyzer.Proof_Obligations;

   --  In the order of a place checked for several instances of a generic
   --  unit: it is as good as the worst of them.
   type Verdict is (Proved, Justified, Not_Proved);

   type Outcome is
     (Paired,
      --  An obligation of AdaLang's stands for the check.
      No_Obligation_Here,
      --  AdaLang raises obligations of the kind, and none at the place.
      No_Such_Kind,
      --  AdaLang raises no obligation of the kind.
      File_Without_Obligation,
      --  No obligation is in a file of the name the log gives: the file
      --  was not analyzed, or has nothing AdaLang checks.
      File_Name_Not_Unique);
      --  Two analyzed files have the name the log gives, which is without
      --  its directory: the check could be of either.

   type Check is record
      Filename   : Unbounded_String;
      --  As the log gives it, without directories.
      Line       : Natural := 0;
      Column     : Natural := 0;
      Label      : Unbounded_String;
      --  What GNATprove calls the check: "overflow check", "precondition".
      Has_Kind   : Boolean := False;
      Kind       : Proof.Obligation_Kind := Proof.Assertion_Check;
      --  The kind of AdaLang obligation that stands for such a check, when
      --  there is one.
      Result     : Verdict := Not_Proved;
      Instances  : Positive := 1;
      --  The messages of the log that are this check.
      Pairing    : Outcome := No_Obligation_Here;
      Obligation : Natural := 0;
      --  When Paired: the registry index of the obligation or, for the
      --  initialization of an object, of the worst of those about it.
      Grouped    : Natural := 0;
      --  The obligations about the object, for such a check.
      Status     : Proof.Obligation_Status := Proof.Unproved;
      --  When Paired: the status of that obligation.
   end record;

   procedure Load (Filename : String);
   --  Reads the checks of a GNATprove log. A line that is not a check
   --  message is passed over. Several logs may be loaded, the flow and the
   --  proof run of one project for instance. Propagates the exception of
   --  Ada.Text_IO when the file cannot be read.

   function Active return Boolean;
   --  True once a log has been loaded.

   function Log_Count return Natural;
   function Log_Name (Index : Positive) return String;

   procedure Pair;
   --  Pairs each check with the obligations of the registry, as
   --  benchmarks/gnatprove_gap_ledger.py does: the obligations of the same
   --  file, line and kind are the candidates; the one at the check's column
   --  is taken, then the nearest not yet taken. GNATprove reports the
   --  initialization of an object once, at its declaration, where AdaLang
   --  checks each read: the obligations about one object are taken
   --  together and the object is as good as the worst of them. To be
   --  called once, when the analysis is over.

   function Check_Count return Natural;
   function Element (Index : Positive) return Check;

   function Has_Verdict (Obligation : Positive) return Boolean;
   function Verdict_Of (Obligation : Positive) return Verdict;
   --  What GNATprove said of the check the obligation at this registry
   --  index stands for. Verdict_Of is Not_Proved where there is none.

   function Verdict_Name (Item : Verdict) return String;
   --  "proved", "justified", "not-proved".

   function Outcome_Name (Item : Check) return String;
   --  The status of the obligation when the check is paired, and
   --  otherwise why it is not.

   type Summary is record
      Checks      : Natural := 0;
      Proved      : Natural := 0;
      Justified   : Natural := 0;
      Not_Proved  : Natural := 0;

      --  The checks GNATprove proved are, each of them, one of these four.
      Proved_By_Both      : Natural := 0;
      --  AdaLang proved the obligation too.
      On_Obligation       : Natural := 0;
      --  AdaLang has the obligation and did not decide it: GNATprove's
      --  verdict is all there is.
      Without_Obligation  : Natural := 0;
      --  AdaLang has no obligation for the check.
      Error_Where_Proved  : Natural := 0;
      --  AdaLang calls the obligation a definite error: one of the two
      --  tools is wrong, or the log is not of these sources.

      Proved_Where_Not_Proved : Natural := 0;
      --  AdaLang proved an obligation whose check GNATprove did not prove.
      --  GNATprove gives up where its provers run out of time, so this
      --  need not be a fault of either; it is what to look at first.

      Obligations_With_Verdict : Natural := 0;
   end record;

   function Totals return Summary;

   procedure Reset;
   --  Forgets the logs and the pairing.

end Adalang_Analyzer.Gnatprove_Import;
