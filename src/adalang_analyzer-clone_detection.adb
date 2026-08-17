--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;   use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;     use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Clone_Detection is

   use type Libadalang.Common.Ada_Node_Kind_Type;

   --  A trivial body ("null;", "return X;", a one-line accessor) is
   --  exempt: those coincide constantly without being a copy-paste risk,
   --  and would otherwise dominate the finding list with noise (see
   --  Adalang_Analyzer.Clone_Detection's spec). Measured on the
   --  whitespace-stripped signature text rather than a top-level
   --  statement count, since a single but large if/case/loop statement
   --  (structurally substantial, textually long) would otherwise count
   --  the same as a single trivial one.
   Minimum_Signature_Length : constant := 30;

   type Clone_Info is record
      Filename  : Unbounded_String;
      Unit      : Libadalang.Analysis.Analysis_Unit;
      Subp_Node : Libadalang.Analysis.Subp_Body;
      Name      : Unbounded_String;
      Signature : Unbounded_String;
   end record;

   package Clone_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Clone_Info);

   function Signature_Less (Left, Right : Clone_Info) return Boolean is
     (Left.Signature < Right.Signature);

   package Sorting is new Clone_Vectors.Generic_Sorting
     ("<" => Signature_Less);

   --  Recursively collects every eligible Ada_Subp_Body under Node into
   --  Clones, keyed by the whitespace/case-normalized text of its
   --  statement list. A resolution failure on one subprogram (Canonical_
   --  Text walks the whole statement subtree, which can raise on
   --  constructs Libadalang's semantic layer cannot fully resolve) is
   --  reported once and does not stop the walk from collecting its
   --  siblings, mirroring Checks.Has_Classwide_Operand's identically
   --  loose recursion.
   procedure Collect
     (Node     : Libadalang.Analysis.Ada_Node'Class;
      Filename : Unbounded_String;
      Unit     : Libadalang.Analysis.Analysis_Unit;
      Clones   : in out Clone_Vectors.Vector)
   is
   begin
      if Node.Kind = Libadalang.Common.Ada_Subp_Body then
         begin
            declare
               Subprogram : constant Libadalang.Analysis.Subp_Body :=
                 Node.As_Subp_Body;
               Signature  : constant String :=
                 Canonical_Text (Subprogram.F_Stmts);
            begin
               if Signature'Length >= Minimum_Signature_Length then
                  Clone_Vectors.Append
                    (Clones,
                     (Filename  => Filename,
                      Unit      => Unit,
                      Subp_Node => Subprogram,
                      Name      =>
                        To_Unbounded_String
                          (Node_Text (Subprogram.F_Subp_Spec.P_Name)),
                      Signature => To_Unbounded_String (Signature)));
               end if;
            end;
         exception
            when E : others =>
               Adalang_Analyzer.Config.Report_Recoverable_Failure_Once
                 (Rule       => "Duplicate_Subprogram",
                  Operation  => "collect subprogram body for clone detection",
                  Source     => Adalang_Analyzer.Ada_Text.Safe_Filename (Unit),
                  Occurrence => E);
         end;
      end if;

      for Index in 1 .. Node.Children_Count loop
         if not Libadalang.Analysis.Is_Null (Node.Child (Index)) then
            Collect (Node.Child (Index), Filename, Unit, Clones);
         end if;
      end loop;
   end Collect;

   procedure Analyze
     (Ctx   : Libadalang.Analysis.Analysis_Context;
      Files : Adalang_Analyzer.Project_Files.File_Name_Vectors.Vector)
   is
      Clones : Clone_Vectors.Vector;
   begin
      for F of Files loop
         declare
            Unit : constant Libadalang.Analysis.Analysis_Unit :=
              Ctx.Get_From_File (F);
         begin
            if not Libadalang.Analysis.Is_Null (Unit.Root) then
               Collect
                 (Unit.Root, To_Unbounded_String (Unit.Get_Filename), Unit,
                  Clones);
            end if;
         end;
      end loop;

      Sorting.Sort (Clones);

      --  Clones is now grouped into runs of equal Signature. Every body
      --  after the first in a run duplicates the first, so it is reported
      --  against that first occurrence; the first occurrence itself never
      --  gets a finding.
      declare
         I : Positive := Clones.First_Index;
      begin
         while I <= Clones.Last_Index loop
            declare
               J : Positive := I + 1;
            begin
               while J <= Clones.Last_Index
                 and then Clones (J).Signature = Clones (I).Signature
               loop
                  Report_Rule_Violation
                    (Clones (J).Unit, Clones (J).Subp_Node,
                     Duplicate_Subprogram,
                     "subprogram '" & To_String (Clones (J).Name) &
                       "' has a statement sequence identical to '" &
                       To_String (Clones (I).Name) & "'s at " &

                       --  The full filename, not just its simple name: two
                       --  files in different directories can share a
                       --  basename (e.g. a per-target board/chip variant
                       --  layout providing an alternate "stm32-crc.adb"
                       --  per directory, found on AdaCore/Ada_Drivers_
                       --  Library), and a simple name alone would then
                       --  read as if a body were reported as a duplicate
                       --  of itself.
                       To_String (Clones (I).Filename) & ":" &
                       To_Decimal
                         (Natural
                            (Clones (I).Subp_Node.Sloc_Range.Start_Line)) &
                       " (local declarations not compared -- they may " &
                       "still differ, e.g. a parameterizing constant)");
                  J := J + 1;
               end loop;
               I := J;
            end;
         end loop;
      end;
   end Analyze;

end Adalang_Analyzer.Clone_Detection;
