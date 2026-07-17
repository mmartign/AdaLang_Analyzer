--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Common;

with Adalang_Analyzer.Ada_Text; use Adalang_Analyzer.Ada_Text;

package body Adalang_Analyzer.Checks.Data_Flow is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   function Referenced_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl
   is
      function Ultimate_Object
        (Decl : Libadalang.Analysis.Basic_Decl;
         Depth : Natural := 0) return Libadalang.Analysis.Basic_Decl
      is
      begin
         if Libadalang.Analysis.Is_Null (Decl)
           or else Depth >= 16
           or else Decl.Kind not in Libadalang.Common.Ada_Object_Decl_Range
         then
            return Decl;
         end if;

         declare
            Clause : constant Libadalang.Analysis.Renaming_Clause :=
              Decl.As_Object_Decl.F_Renaming_Clause;
         begin
            if Libadalang.Analysis.Is_Null (Clause)
              or else Clause.F_Renamed_Object.Kind /=
                Libadalang.Common.Ada_Identifier
            then
               return Decl;
            end if;

            return Ultimate_Object
              (Clause.F_Renamed_Object.P_Referenced_Decl
                 (Imprecise_Fallback => True),
               Depth + 1);
         end;
      exception
         when others =>
            return Decl;
      end Ultimate_Object;
   begin
      if not Libadalang.Analysis.Is_Null (Node)
        and then Node.Kind = Libadalang.Common.Ada_Identifier
      then
         return Ultimate_Object
           (Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True));
      end if;

      return Libadalang.Analysis.No_Basic_Decl;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Referenced_Declaration;

   function Matches_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
      Resolved : constant Libadalang.Analysis.Basic_Decl :=
        Referenced_Declaration (Node);
   begin
      if not Libadalang.Analysis.Is_Null (Resolved) then
         return Resolved = Decl;
      end if;

      --  Semantic resolution of a local identifier can fail when an outer
      --  call is unresolved. Fall back to its spelling so a possible read is
      --  retained. This may suppress a finding in shadowing-heavy incomplete
      --  code, which is preferable to reporting a false dead store.
      return Node.Kind = Libadalang.Common.Ada_Identifier
        and then Canonical_Text (Node) /= ""
        and then Canonical_Text (Node) =
          Canonical_Text (Decl.P_Defining_Name);
   exception
      when others =>
         return False;
   end Matches_Declaration;

   --  True when any identifier under Node resolves to Decl. Used as the
   --  "is this object mentioned at all" building block for Reads_Declaration.
   function References_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Libadalang.Analysis.Is_Null (Decl)
      then
         return False;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier
        and then Matches_Declaration (Node, Decl)
      then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if References_Declaration (Node.Child (I), Decl) then
            return True;
         end if;
      end loop;

      return False;
   end References_Declaration;

   function Reads_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         --  A simple assignment destination is a write, while expressions in
         --  the value (and in a complex destination) remain reads.
         declare
            Stmt : constant Libadalang.Analysis.Assign_Stmt :=
              Node.As_Assign_Stmt;
         begin
            return References_Declaration (Stmt.F_Expr, Decl)
              or else (Stmt.F_Dest.Kind /= Libadalang.Common.Ada_Identifier
                       and then References_Declaration (Stmt.F_Dest, Decl));
         end;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier
        and then Matches_Declaration (Node, Decl)
      then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if Reads_Declaration (Node.Child (I), Decl) then
            return True;
         end if;
      end loop;

      return False;
   end Reads_Declaration;

   function Assigned_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Assign_Stmt
      then
         return Libadalang.Analysis.No_Basic_Decl;
      end if;

      declare
         Dest : constant Libadalang.Analysis.Name :=
           Node.As_Assign_Stmt.F_Dest;
      begin
         if Dest.Kind = Libadalang.Common.Ada_Identifier then
            return Referenced_Declaration (Dest);
         elsif Dest.Kind = Libadalang.Common.Ada_Call_Expr
           and then Dest.As_Call_Expr.F_Name.Kind =
             Libadalang.Common.Ada_Identifier
         then
            return Referenced_Declaration (Dest.As_Call_Expr.F_Name);
         else
            return Libadalang.Analysis.No_Basic_Decl;
         end if;
      end;
   end Assigned_Declaration;

   function Contains_Identifier
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if Contains_Identifier (Node.Child (I)) then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Identifier;

   function Is_Trackable_Assignment
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      if Libadalang.Analysis.Is_Null (Assigned_Declaration (Node)) then
         return False;
      end if;

      declare
         Dest : constant Libadalang.Analysis.Name :=
           Node.As_Assign_Stmt.F_Dest;
      begin
         return Dest.Kind = Libadalang.Common.Ada_Identifier
           or else
             (Dest.Kind = Libadalang.Common.Ada_Call_Expr
              and then not Contains_Identifier
                (Dest.As_Call_Expr.F_Suffix));
      end;
   end Is_Trackable_Assignment;

   function Same_Assigned_Target
     (Left, Right : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      return Is_Trackable_Assignment (Left)
        and then Is_Trackable_Assignment (Right)
        and then Assigned_Declaration (Left) = Assigned_Declaration (Right)
        and then Canonical_Text (Left.As_Assign_Stmt.F_Dest) =
          Canonical_Text (Right.As_Assign_Stmt.F_Dest);
   end Same_Assigned_Target;

   function Reads_Assigned_Target
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Assignment : Libadalang.Analysis.Assign_Stmt) return Boolean
   is
      Target_Decl : constant Libadalang.Analysis.Basic_Decl :=
        Assigned_Declaration (Assignment);
      Target_Dest : constant Libadalang.Analysis.Name := Assignment.F_Dest;
      Target_Text : constant String := Canonical_Text (Target_Dest);

      function Reads_Component
        (Candidate : Libadalang.Analysis.Ada_Node'Class) return Boolean is
      begin
         if Libadalang.Analysis.Is_Null (Candidate) then
            return False;
         elsif Candidate.Kind = Libadalang.Common.Ada_Assign_Stmt then
            --  The destination is a write. Only its value can consume the
            --  component's previous value.
            return Reads_Component (Candidate.As_Assign_Stmt.F_Expr);
         elsif Candidate.Kind = Libadalang.Common.Ada_Call_Expr
           and then Candidate.As_Call_Expr.F_Name.Kind =
             Libadalang.Common.Ada_Identifier
           and then Matches_Declaration
             (Candidate.As_Call_Expr.F_Name, Target_Decl)
         then
            if Canonical_Text (Candidate) = Target_Text then
               return True;
            end if;

            --  A different component is not a read of this target. Its index
            --  expression can still contain a nested read, however.
            return Reads_Component (Candidate.As_Call_Expr.F_Suffix);
         elsif Candidate.Kind = Libadalang.Common.Ada_Identifier
           and then Matches_Declaration (Candidate, Target_Decl)
         then
            --  Reading the complete array consumes every component value.
            return True;
         end if;

         for I in 1 .. Candidate.Children_Count loop
            if Reads_Component (Candidate.Child (I)) then
               return True;
            end if;
         end loop;
         return False;
      end Reads_Component;
   begin
      if Target_Dest.Kind = Libadalang.Common.Ada_Identifier then
         return Reads_Declaration (Node, Target_Decl);
      else
         return Reads_Component (Node);
      end if;
   end Reads_Assigned_Target;

   function Has_Read_After
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Decl       : Libadalang.Analysis.Basic_Decl;
      Assignment : Libadalang.Analysis.Assign_Stmt) return Boolean
   is
      --  Whether Candidate starts at or after the end of Assignment, used
      --  to ignore reads that are the assignment's own destination/value.
      function Starts_After_Assignment
        (Candidate : Libadalang.Analysis.Ada_Node'Class) return Boolean is
      begin
         return Natural (Candidate.Sloc_Range.Start_Line) >
             Natural (Assignment.Sloc_Range.End_Line)
           or else
             (Natural (Candidate.Sloc_Range.Start_Line) =
                Natural (Assignment.Sloc_Range.End_Line)
              and then Natural (Candidate.Sloc_Range.Start_Column) >=
                Natural (Assignment.Sloc_Range.End_Column));
      end Starts_After_Assignment;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Libadalang.Analysis.Ada_Node (Node) =
        Libadalang.Analysis.Ada_Node (Assignment)
      then
         return False;
      elsif Starts_After_Assignment (Node) then
         --  Reads_Assigned_Target already walks this complete subtree. Do not
         --  descend again when it returns False: doing so would reinterpret
         --  the base name in a different component (Arr in Arr (3)) as a
         --  whole-array read of the tracked component Arr (2).
         return Reads_Assigned_Target (Node, Assignment);
      end if;

      for I in 1 .. Node.Children_Count loop
         if Has_Read_After (Node.Child (I), Decl, Assignment) then
            return True;
         end if;
      end loop;

      return False;
   end Has_Read_After;

   function Has_Read_After_Node
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Decl       : Libadalang.Analysis.Basic_Decl;
      Write_Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      function Starts_After_Write
        (Candidate : Libadalang.Analysis.Ada_Node'Class) return Boolean is
      begin
         return Natural (Candidate.Sloc_Range.Start_Line) >
             Natural (Write_Node.Sloc_Range.End_Line)
           or else
             (Natural (Candidate.Sloc_Range.Start_Line) =
                Natural (Write_Node.Sloc_Range.End_Line)
              and then Natural (Candidate.Sloc_Range.Start_Column) >=
                Natural (Write_Node.Sloc_Range.End_Column));
      end Starts_After_Write;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Libadalang.Analysis.Ada_Node (Node) =
        Libadalang.Analysis.Ada_Node (Write_Node)
      then
         return False;
      elsif Starts_After_Write (Node) then
         return Reads_Declaration (Node, Decl);
      end if;

      for I in 1 .. Node.Children_Count loop
         if Has_Read_After_Node (Node.Child (I), Decl, Write_Node) then
            return True;
         end if;
      end loop;
      return False;
   end Has_Read_After_Node;

   function Enclosing_Subprogram
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Subp_Body
   is
      Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         if Ancestor.Kind = Libadalang.Common.Ada_Subp_Body then
            return Ancestor.As_Subp_Body;
         end if;
         Ancestor := Ancestor.Parent;
      end loop;

      return Libadalang.Analysis.No_Subp_Body;
   end Enclosing_Subprogram;

   function Is_Direct_Recursive_Call
     (Call       : Libadalang.Analysis.Call_Expr;
      Subprogram : Libadalang.Analysis.Subp_Body) return Boolean
   is
      Referenced : constant Libadalang.Analysis.Basic_Decl :=
        Call.F_Name.P_Referenced_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Referenced) then
         return False;
      end if;

      return Referenced.P_Canonical_Part =
        Libadalang.Analysis.Basic_Decl (Subprogram).P_Canonical_Part;
   exception
      when others =>
         return False;
   end Is_Direct_Recursive_Call;

end Adalang_Analyzer.Checks.Data_Flow;
