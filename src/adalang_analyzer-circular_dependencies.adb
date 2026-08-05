--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;
with Adalang_Analyzer.Report; use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;  use Adalang_Analyzer.Rules;

package body Adalang_Analyzer.Circular_Dependencies is

   use type Libadalang.Common.Ada_Node_Kind_Type;

   package Index_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Positive);

   type Node_Info is record
      Filename : Unbounded_String;
      Unit     : Libadalang.Analysis.Analysis_Unit;
      Anchor   : Libadalang.Analysis.Ada_Node;
      Edges    : Index_Vectors.Vector;
   end record;

   package Node_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => Node_Info);

   type Color_Kind is (White, Gray, Black);

   package Color_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Color_Kind);

   function Index_Of
     (Nodes : Node_Vectors.Vector; Filename : String) return Natural is
   begin
      for I in Nodes.First_Index .. Nodes.Last_Index loop
         if To_String (Nodes (I).Filename) = Filename then
            return I;
         end if;
      end loop;
      return 0;
   end Index_Of;

   --  The Compilation_Unit for Unit's root, or No_Compilation_Unit for an
   --  empty or unparseable file.
   function Root_Compilation_Unit
     (Unit : Libadalang.Analysis.Analysis_Unit)
      return Libadalang.Analysis.Compilation_Unit
   is
      Root : constant Libadalang.Analysis.Ada_Node := Unit.Root;
   begin
      if Libadalang.Analysis.Is_Null (Root)
        or else Root.Kind /= Libadalang.Common.Ada_Compilation_Unit
      then
         return Libadalang.Analysis.No_Compilation_Unit;
      end if;

      return Root.As_Compilation_Unit;
   exception
      when others =>
         return Libadalang.Analysis.No_Compilation_Unit;
   end Root_Compilation_Unit;

   --  The first With_Clause in CU's prelude, for a more useful caret
   --  position than the whole compilation unit, or CU itself if it has
   --  none (a body relying only on its own spec's visibility, for
   --  instance).
   function Report_Anchor
     (CU : Libadalang.Analysis.Compilation_Unit)
      return Libadalang.Analysis.Ada_Node is
   begin
      for Item of CU.F_Prelude loop
         if Item.Kind = Libadalang.Common.Ada_With_Clause then
            return Libadalang.Analysis.Ada_Node (Item);
         end if;
      end loop;
      return CU.As_Ada_Node;
   exception
      when others =>
         return CU.As_Ada_Node;
   end Report_Anchor;

   procedure Analyze
     (Ctx   : Libadalang.Analysis.Analysis_Context;
      Files : Adalang_Analyzer.Project_Files.File_Name_Vectors.Vector)
   is
      Nodes  : Node_Vectors.Vector;
      Colors : Color_Vectors.Vector;
      Path   : Index_Vectors.Vector;

      --  Reports the elementary cycle that runs from Back_To (still Gray,
      --  i.e. on the current path) forward through Path and back to
      --  Back_To, anchored on Back_To's own unit so the message reads as
      --  "this unit's dependency chain loops back to itself".
      procedure Report_Cycle (Back_To : Positive) is
         Start_Position : Positive := Path.First_Index;
         Message        : Unbounded_String :=
           To_Unbounded_String ("circular dependency: ");
      begin
         for P in Path.First_Index .. Path.Last_Index loop
            if Path (P) = Back_To then
               Start_Position := P;
               exit;
            end if;
         end loop;

         for P in Start_Position .. Path.Last_Index loop
            if P > Start_Position then
               Append (Message, " -> ");
            end if;
            Append
              (Message,
               Ada.Directories.Simple_Name
                 (To_String (Nodes (Path (P)).Filename)));
         end loop;
         Append (Message, " -> ");
         Append
           (Message,
            Ada.Directories.Simple_Name
              (To_String (Nodes (Back_To).Filename)));

         if not Libadalang.Analysis.Is_Null (Nodes (Back_To).Anchor) then
            Report_Rule_Violation
              (Nodes (Back_To).Unit, Nodes (Back_To).Anchor,
               Circular_Package_Dependency, To_String (Message));
         end if;
      end Report_Cycle;

      procedure Visit (I : Positive) is
      begin
         Colors (I) := Gray;
         Index_Vectors.Append (Path, I);

         for Edge of Nodes (I).Edges loop
            if Colors (Edge) = White then
               Visit (Edge);
            elsif Colors (Edge) = Gray then
               Report_Cycle (Edge);
            end if;
         end loop;

         Index_Vectors.Delete_Last (Path);
         Colors (I) := Black;
      end Visit;
   begin
      for F of Files loop
         declare
            Unit : constant Libadalang.Analysis.Analysis_Unit :=
              Ctx.Get_From_File (F);
         begin
            Node_Vectors.Append
              (Nodes,
               (Filename => To_Unbounded_String (Unit.Get_Filename),
                Unit     => Unit,
                Anchor   => Libadalang.Analysis.No_Ada_Node,
                Edges    => Index_Vectors.Empty_Vector));
         end;
      end loop;

      for I in Nodes.First_Index .. Nodes.Last_Index loop
         declare
            CU : constant Libadalang.Analysis.Compilation_Unit :=
              Root_Compilation_Unit (Nodes (I).Unit);
         begin
            if not Libadalang.Analysis.Is_Null (CU) then
               Nodes (I).Anchor := Report_Anchor (CU);

               --  Built from ordinary/private with clauses only, not
               --  P_Withed_Units (which does not distinguish a "limited
               --  with" from an ordinary one). A limited-with'd unit is
               --  visible only through its incomplete view and imposes no
               --  "elaborate before" requirement -- it is Ada's own
               --  sanctioned way to let two units name each other's types
               --  without a real circular elaboration dependency, so it
               --  must not contribute a graph edge here (see FP-042).
               for Item of CU.F_Prelude loop
                  if Item.Kind = Libadalang.Common.Ada_With_Clause then
                     declare
                        Clause : constant Libadalang.Analysis.With_Clause :=
                          Item.As_With_Clause;
                     begin
                        if not Clause.F_Has_Limited then
                           for Pkg_Name of Clause.F_Packages loop
                              declare
                                 Decl : constant
                                   Libadalang.Analysis.Basic_Decl :=
                                     Pkg_Name.P_Referenced_Decl
                                       (Imprecise_Fallback => True);
                              begin
                                 if not Libadalang.Analysis.Is_Null (Decl)
                                 then
                                    declare
                                       Target : constant Natural :=
                                         Index_Of
                                           (Nodes, Decl.Unit.Get_Filename);
                                    begin
                                       if Target /= 0 and then Target /= I
                                       then
                                          Index_Vectors.Append
                                            (Nodes (I).Edges, Target);
                                       end if;
                                    end;
                                 end if;
                              exception
                                 when others =>
                                    null;
                              end;
                           end loop;
                        end if;
                     end;
                  end if;
               end loop;
            end if;
         exception
            when E : others =>
               Adalang_Analyzer.Config.Report_Recoverable_Failure_Once
                 (Rule       => "Circular_Package_Dependency",
                  Operation  => "resolve compilation-unit dependencies",
                  Source     =>
                    Adalang_Analyzer.Ada_Text.Safe_Filename (Nodes (I).Unit),
                  Occurrence => E);
         end;
      end loop;

      Colors := Color_Vectors.To_Vector (White, Nodes.Length);

      for I in Nodes.First_Index .. Nodes.Last_Index loop
         if Colors (I) = White then
            Visit (I);
         end if;
      end loop;
   end Analyze;

end Adalang_Analyzer.Circular_Dependencies;
