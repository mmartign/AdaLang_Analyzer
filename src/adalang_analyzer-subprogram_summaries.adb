--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Text;
with Libadalang.Common;

package body Adalang_Analyzer.Subprogram_Summaries is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   package Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   type Summary is record
      Name             : Unbounded_String;
      Callees          : Name_Vectors.Vector;
      Direct_May_Block : Boolean := False;
      Direct_May_Raise : Boolean := False;
      May_Block        : Boolean := False;
      May_Raise        : Boolean := False;
   end record;

   package Summary_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Summary);

   Summaries : Summary_Vectors.Vector;

   procedure Reset is
   begin
      Summaries.Clear;
   end Reset;

   function Declaration_Name
     (Decl : Libadalang.Analysis.Basic_Decl) return String
   is
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return "";
      end if;
      return Langkit_Support.Text.To_UTF8
        (Decl.P_Unique_Identifying_Name);
   exception
      when others =>
         return "";
   end Declaration_Name;

   function Call_Declaration
     (Call : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl
   is
   begin
      if Call.Kind = Libadalang.Common.Ada_Call_Expr then
         return Call.As_Call_Expr.F_Name.P_Referenced_Decl
           (Imprecise_Fallback => True);
      elsif Call.Kind = Libadalang.Common.Ada_Call_Stmt then
         return Call.As_Call_Stmt.F_Call.P_Referenced_Decl
           (Imprecise_Fallback => True);
      else
         return Libadalang.Analysis.No_Basic_Decl;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Call_Declaration;

   function Find (Name : String) return Natural is
   begin
      for Index in Summaries.First_Index .. Summaries.Last_Index loop
         if To_String (Summaries (Index).Name) = Name then
            return Index;
         end if;
      end loop;
      return 0;
   exception
      when Constraint_Error =>
         return 0;
   end Find;

   procedure Include (Names : in out Name_Vectors.Vector; Name : String) is
   begin
      if Name = "" then
         return;
      end if;
      for Existing of Names loop
         if Existing = Name then
            return;
         end if;
      end loop;
      Names.Append (Name);
   end Include;

   procedure Scan_Effects
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Root : Libadalang.Analysis.Subp_Body;
      Item : in out Summary)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Subp_Body
        and then Libadalang.Analysis.Ada_Node (Node) /=
          Libadalang.Analysis.Ada_Node (Root)
      then
         return;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Delay_Stmt =>
            Item.Direct_May_Block := True;

         when Libadalang.Common.Ada_Raise_Stmt =>
            Item.Direct_May_Raise := True;

         when Libadalang.Common.Ada_Call_Expr
            | Libadalang.Common.Ada_Call_Stmt =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Call_Declaration (Node);
            begin
               if not Libadalang.Analysis.Is_Null (Decl) then
                  if Decl.Kind = Libadalang.Common.Ada_Entry_Decl then
                     Item.Direct_May_Block := True;
                  else
                     Include (Item.Callees, Declaration_Name (Decl));
                  end if;
               end if;
            end;

         when others =>
            null;
      end case;

      for Index in 1 .. Node.Children_Count loop
         Scan_Effects (Node.Child (Index), Root, Item);
      end loop;
   end Scan_Effects;

   procedure Register_Body
     (Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Item     : Summary;
      Key_Decl : Libadalang.Analysis.Basic_Decl :=
        Libadalang.Analysis.Basic_Decl (Subprogram);
   begin
      declare
         Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
           Subprogram.P_Decl_Part (Imprecise_Fallback => True);
      begin
         if not Libadalang.Analysis.Is_Null (Decl_Part) then
            Key_Decl := Decl_Part;
         end if;
      exception
         when others =>
            null;
      end;

      Item.Name := To_Unbounded_String
        (Declaration_Name (Key_Decl));
      if Item.Name = Null_Unbounded_String
        or else Find (To_String (Item.Name)) /= 0
      then
         return;
      end if;

      Scan_Effects (Subprogram, Subprogram, Item);
      Item.May_Block := Item.Direct_May_Block;
      Item.May_Raise := Item.Direct_May_Raise;
      Summaries.Append (Item);
   exception
      when others =>
         null;
   end Register_Body;

   procedure Scan_Node (Node : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;
      if Node.Kind = Libadalang.Common.Ada_Subp_Body then
         Register_Body (Node.As_Subp_Body);
      end if;
      for Index in 1 .. Node.Children_Count loop
         Scan_Node (Node.Child (Index));
      end loop;
   end Scan_Node;

   procedure Scan_Unit (Unit : Libadalang.Analysis.Analysis_Unit) is
   begin
      if not Unit.Has_Diagnostics then
         Scan_Node (Unit.Root);
      end if;
   exception
      when others =>
         null;
   end Scan_Unit;

   procedure Complete is
      Changed : Boolean := True;
   begin
      while Changed loop
         Changed := False;
         for Index in Summaries.First_Index .. Summaries.Last_Index loop
            for Callee of Summaries (Index).Callees loop
               declare
                  Callee_Index : constant Natural := Find (Callee);
               begin
                  if Callee_Index /= 0 then
                     if Summaries (Callee_Index).May_Block
                       and then not Summaries (Index).May_Block
                     then
                        Summaries (Index).May_Block := True;
                        Changed := True;
                     end if;
                     if Summaries (Callee_Index).May_Raise
                       and then not Summaries (Index).May_Raise
                     then
                        Summaries (Index).May_Raise := True;
                        Changed := True;
                     end if;
                  end if;
               end;
            end loop;
         end loop;
      end loop;
   exception
      when Constraint_Error =>
         null;
   end Complete;

   function Callee_Index
     (Call : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
   begin
      return Find (Declaration_Name (Call_Declaration (Call)));
   end Callee_Index;

   function Callee_May_Block
     (Call : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Index : constant Natural := Callee_Index (Call);
   begin
      return Index /= 0 and then Summaries (Index).May_Block;
   end Callee_May_Block;

   function Callee_May_Raise
     (Call : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Index : constant Natural := Callee_Index (Call);
   begin
      return Index /= 0 and then Summaries (Index).May_Raise;
   end Callee_May_Raise;

   function Count return Natural is
   begin
      return Natural (Summaries.Length);
   end Count;

end Adalang_Analyzer.Subprogram_Summaries;
