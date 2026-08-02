--  AdaLang Analyzer
--
--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--
--  Derived from AdaCore's libadalang-tools and substantially extended,
--  integrated, validated, and maintained by Spazio IT as part of the
--  independent AdaLang Analyzer project.
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;  use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Subprogram_Summaries;
with Adalang_Analyzer.Text_Utils;

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
      --  An attribute designator ("Last" in "Data'Last", "First" in
      --  "Data'First", ...) is syntactically an identifier but never
      --  refers to a declaration -- Libadalang's own resolution correctly
      --  returns null for it, which would otherwise fall through to the
      --  spelling-based fallback below and get mistaken for an unrelated
      --  local variable of the same name. "First" and "Last" are also two
      --  of the most common variable names for tracking string/array
      --  bounds, the exact scenario this collides with; observed in the
      --  wild misclassifying "Last := Fixed.Index (Data (First .. Data
      --  'Last), ...);" -- Last's own initializing assignment -- as a
      --  read of Last because "Data'Last" was matched by spelling.
      --  Checking the node's own prefix identity (not just its Kind and
      --  parent's Kind) is required so a genuine reference used as an
      --  attribute prefix, e.g. "Last'Size" where Last really is the
      --  tracked variable, is not also excluded.
      if Node.Kind = Libadalang.Common.Ada_Identifier
        and then Node.Parent.Kind = Libadalang.Common.Ada_Attribute_Ref
        and then Libadalang.Analysis.Ada_Node
          (Node.Parent.As_Attribute_Ref.F_Attribute) =
            Libadalang.Analysis.Ada_Node (Node)
      then
         return False;
      end if;

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
      function Association_Reads_Actual
        (Assoc : Libadalang.Analysis.Param_Assoc) return Boolean
      is
         Found_Formal : Boolean := False;
      begin
         for Formal_Name of
           Assoc.P_Get_Params (Imprecise_Fallback => True)
         loop
            declare
               Ancestor : Libadalang.Analysis.Ada_Node := Formal_Name.Parent;
            begin
               while not Libadalang.Analysis.Is_Null (Ancestor)
                 and then Ancestor.Kind not in
                   Libadalang.Common.Ada_Param_Spec_Range
               loop
                  Ancestor := Ancestor.Parent;
               end loop;

               if not Libadalang.Analysis.Is_Null (Ancestor) then
                  Found_Formal := True;
                  if Ancestor.As_Param_Spec.F_Mode.Kind not in
                    Libadalang.Common.Ada_Mode_Out_Range
                  then
                     return True;
                  end if;
               end if;
            end;
         end loop;

         --  If resolution fails, retaining a possible read avoids creating a
         --  dead-store false positive on incomplete code.
         return not Found_Formal;
      exception
         when others =>
            return True;
      end Association_Reads_Actual;
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
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
         if Reads_Declaration (Node.As_Call_Expr.F_Name, Decl) then
            return True;
         end if;

         for I in 1 .. Node.As_Call_Expr.F_Suffix.Children_Count loop
            declare
               Child : constant Libadalang.Analysis.Ada_Node :=
                 Node.As_Call_Expr.F_Suffix.Child (I);
            begin
               if Child.Kind = Libadalang.Common.Ada_Param_Assoc
                 and then Child.As_Param_Assoc.F_R_Expr.Kind =
                   Libadalang.Common.Ada_Identifier
                 and then Matches_Declaration
                   (Child.As_Param_Assoc.F_R_Expr, Decl)
               then
                  if Association_Reads_Actual (Child.As_Param_Assoc) then
                     return True;
                  end if;
               elsif Reads_Declaration (Child, Decl) then
                  return True;
               end if;
            end;
         end loop;
         return False;
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

   --  Param's formal mode, found by walking up from its Defining_Name to
   --  the enclosing Param_Spec. Mirrors Adalang_Analyzer.SPARK_Readiness.
   --  Formal_Mode.
   function Formal_Mode
     (Param : Libadalang.Analysis.Defining_Name'Class)
      return Libadalang.Common.Ada_Node_Kind_Type
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Param);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return Current.As_Param_Spec.F_Mode.Kind;
         end if;
         Current := Current.Parent;
      end loop;
      return Libadalang.Common.Ada_Mode_Default;
   exception
      when others =>
         return Libadalang.Common.Ada_Mode_Default;
   end Formal_Mode;

   --  The Position'th formal (1-based, flattening multi-name Param_Specs
   --  like "A, B : out Integer" into two positions) of Call's callee,
   --  resolved leniently: only the callee name itself needs to resolve,
   --  not which exact overload was selected. Valid only for a purely
   --  positional actual at that position. Mirrors Adalang_Analyzer.
   --  SPARK_Readiness.Callee_Formal_At_Position -- duplicated rather than
   --  shared, consistent with this project's existing style of small,
   --  explicit per-module helpers over cross-module reuse for this kind
   --  of narrow, leaf-level function.
   function Callee_Formal_At_Position
     (Call     : Libadalang.Analysis.Call_Expr'Class;
      Position : Positive) return Libadalang.Analysis.Defining_Name
   is
      Callee : constant Libadalang.Analysis.Basic_Decl :=
        Call.F_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      Spec   : Libadalang.Analysis.Base_Subp_Spec;
      Index  : Natural := 0;
   begin
      if Libadalang.Analysis.Is_Null (Callee) then
         return Libadalang.Analysis.No_Defining_Name;
      end if;
      Spec := Callee.P_Subp_Spec_Or_Null;
      if Libadalang.Analysis.Is_Null (Spec) then
         return Libadalang.Analysis.No_Defining_Name;
      end if;
      for Formal of Spec.P_Params loop
         for Id of Formal.F_Ids loop
            Index := Index + 1;
            if Index = Position then
               return Id.As_Defining_Name;
            end if;
         end loop;
      end loop;
      return Libadalang.Analysis.No_Defining_Name;
   exception
      when others =>
         return Libadalang.Analysis.No_Defining_Name;
   end Callee_Formal_At_Position;

   --  The callee's formal (of any name) whose own name matches
   --  Designator_Name (already normalized), resolved as leniently as
   --  Callee_Formal_At_Position. Mirrors Adalang_Analyzer.SPARK_Readiness.
   --  Callee_Formal_By_Name.
   function Callee_Formal_By_Name
     (Call            : Libadalang.Analysis.Call_Expr'Class;
      Designator_Name : String) return Libadalang.Analysis.Defining_Name
   is
      Callee : constant Libadalang.Analysis.Basic_Decl :=
        Call.F_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      Spec   : Libadalang.Analysis.Base_Subp_Spec;
   begin
      if Libadalang.Analysis.Is_Null (Callee) then
         return Libadalang.Analysis.No_Defining_Name;
      end if;
      Spec := Callee.P_Subp_Spec_Or_Null;
      if Libadalang.Analysis.Is_Null (Spec) then
         return Libadalang.Analysis.No_Defining_Name;
      end if;
      for Formal of Spec.P_Params loop
         for Id of Formal.F_Ids loop
            if Text_Utils.Normalize_Rule_Name (Node_Text (Id)) =
              Designator_Name
            then
               return Id.As_Defining_Name;
            end if;
         end loop;
      end loop;
      return Libadalang.Analysis.No_Defining_Name;
   exception
      when others =>
         return Libadalang.Analysis.No_Defining_Name;
   end Callee_Formal_By_Name;

   --  Whether Assoc (the Position'th positional or named actual, matched
   --  as writing Decl) is passed to an out/in-out formal, per Assoc.
   --  P_Get_Params's own precise per-actual resolution when that
   --  resolves at least one formal, or else -- since P_Get_Params can
   --  fail entirely (return an empty result) even for an otherwise-
   --  unambiguous call, the same Libadalang resolution fragility already
   --  documented for Statement_Writes_Parameter (SPARK_Readiness,
   --  Uninitialized_Output's own write detection): heavily overloaded
   --  callees, or a formal typed Ada.Calendar.Time, are both confirmed
   --  triggers -- the same lenient fallback used there: resolving just
   --  the callee name and pairing by position or designator.
   function Association_Writes_Actual
     (Call     : Libadalang.Analysis.Call_Expr;
      Assoc    : Libadalang.Analysis.Param_Assoc;
      Position : Positive) return Boolean
   is
      Found_Formal : Boolean := False;
   begin
      for Formal_Name of
        Assoc.P_Get_Params (Imprecise_Fallback => True)
      loop
         declare
            Ancestor : Libadalang.Analysis.Ada_Node := Formal_Name.Parent;
         begin
            while not Libadalang.Analysis.Is_Null (Ancestor)
              and then Ancestor.Kind not in
                Libadalang.Common.Ada_Param_Spec_Range
            loop
               Ancestor := Ancestor.Parent;
            end loop;

            if not Libadalang.Analysis.Is_Null (Ancestor) then
               Found_Formal := True;
               if
                 (if Adalang_Analyzer.Subprogram_Summaries
                       .Callee_State_Effects_Known (Call)
                  then Adalang_Analyzer.Subprogram_Summaries
                    .Callee_Formal_May_Write (Call, Formal_Name)
                  else Ancestor.As_Param_Spec.F_Mode.Kind in
                    Libadalang.Common.Ada_Mode_Out_Range
                      | Libadalang.Common.Ada_Mode_In_Out_Range)
               then
                  return True;
               end if;
            end if;
         end;
      end loop;

      if Found_Formal then
         return False;
      end if;

      declare
         Formal : constant Libadalang.Analysis.Defining_Name :=
           (if Libadalang.Analysis.Is_Null (Assoc.F_Designator) then
               Callee_Formal_At_Position (Call, Position)
            else
               Callee_Formal_By_Name
                 (Call,
                  Text_Utils.Normalize_Rule_Name
                    (Node_Text (Assoc.F_Designator))));
      begin
         return not Libadalang.Analysis.Is_Null (Formal)
           and then
             (if Adalang_Analyzer.Subprogram_Summaries
                   .Callee_State_Effects_Known (Call)
              then Adalang_Analyzer.Subprogram_Summaries
                .Callee_Formal_May_Write (Call, Formal)
              else Formal_Mode (Formal) in
                Libadalang.Common.Ada_Mode_Out_Range
                  | Libadalang.Common.Ada_Mode_In_Out_Range);
      end;
   exception
      when others =>
         return False;
   end Association_Writes_Actual;

   --  The read-side counterpart to Association_Writes_Actual, with the
   --  same fallback for the same reason.
   function Association_Reads_Simple_Actual
     (Call     : Libadalang.Analysis.Call_Expr;
      Assoc    : Libadalang.Analysis.Param_Assoc;
      Position : Positive) return Boolean
   is
      Found_Formal : Boolean := False;
   begin
      for Formal_Name of
        Assoc.P_Get_Params (Imprecise_Fallback => True)
      loop
         declare
            Ancestor : Libadalang.Analysis.Ada_Node := Formal_Name.Parent;
         begin
            while not Libadalang.Analysis.Is_Null (Ancestor)
              and then Ancestor.Kind not in
                Libadalang.Common.Ada_Param_Spec_Range
            loop
               Ancestor := Ancestor.Parent;
            end loop;

            if not Libadalang.Analysis.Is_Null (Ancestor) then
               Found_Formal := True;
               if
                 (if Adalang_Analyzer.Subprogram_Summaries
                       .Callee_State_Effects_Known (Call)
                  then Adalang_Analyzer.Subprogram_Summaries
                    .Callee_Formal_May_Read (Call, Formal_Name)
                  else Ancestor.As_Param_Spec.F_Mode.Kind not in
                    Libadalang.Common.Ada_Mode_Out_Range)
               then
                  return True;
               end if;
            end if;
         end;
      end loop;

      if Found_Formal then
         return False;
      end if;

      declare
         Formal : constant Libadalang.Analysis.Defining_Name :=
           (if Libadalang.Analysis.Is_Null (Assoc.F_Designator) then
               Callee_Formal_At_Position (Call, Position)
            else
               Callee_Formal_By_Name
                 (Call,
                  Text_Utils.Normalize_Rule_Name
                    (Node_Text (Assoc.F_Designator))));
      begin
         return not Libadalang.Analysis.Is_Null (Formal)
           and then
             (if Adalang_Analyzer.Subprogram_Summaries
                   .Callee_State_Effects_Known (Call)
              then Adalang_Analyzer.Subprogram_Summaries
                .Callee_Formal_May_Read (Call, Formal)
              else Formal_Mode (Formal) not in
                Libadalang.Common.Ada_Mode_Out_Range);
      end;
   exception
      when others =>
         return False;
   end Association_Reads_Simple_Actual;

   function Call_Writes_Declaration
     (Node : Libadalang.Analysis.Call_Expr;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
      Position : Natural := 0;
   begin
      for I in 1 .. Node.F_Suffix.Children_Count loop
         declare
            Child : constant Libadalang.Analysis.Ada_Node :=
              Node.F_Suffix.Child (I);
         begin
            if Child.Kind = Libadalang.Common.Ada_Param_Assoc then
               Position := Position + 1;
               if Child.As_Param_Assoc.F_R_Expr.Kind =
                    Libadalang.Common.Ada_Identifier
                 and then Matches_Declaration
                   (Child.As_Param_Assoc.F_R_Expr, Decl)
                 and then Association_Writes_Actual
                   (Node, Child.As_Param_Assoc, Position)
               then
                  return True;
               end if;
            end if;
         end;
      end loop;

      return False;
   end Call_Writes_Declaration;

   function Call_Reads_Simple_Actual
     (Node : Libadalang.Analysis.Call_Expr;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
      Position : Natural := 0;
   begin
      for I in 1 .. Node.F_Suffix.Children_Count loop
         declare
            Child : constant Libadalang.Analysis.Ada_Node :=
              Node.F_Suffix.Child (I);
         begin
            if Child.Kind = Libadalang.Common.Ada_Param_Assoc then
               Position := Position + 1;
               if Child.As_Param_Assoc.F_R_Expr.Kind =
                    Libadalang.Common.Ada_Identifier
                 and then Matches_Declaration
                   (Child.As_Param_Assoc.F_R_Expr, Decl)
                 and then Association_Reads_Simple_Actual
                   (Node, Child.As_Param_Assoc, Position)
               then
                  return True;
               end if;
            end if;
         end;
      end loop;

      return False;
   exception
      when others =>
         return False;
   end Call_Reads_Simple_Actual;

   function Has_Simple_Actual
     (Node : Libadalang.Analysis.Call_Expr;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean
   is
   begin
      for I in 1 .. Node.F_Suffix.Children_Count loop
         declare
            Child : constant Libadalang.Analysis.Ada_Node :=
              Node.F_Suffix.Child (I);
         begin
            if Child.Kind = Libadalang.Common.Ada_Param_Assoc
              and then Child.As_Param_Assoc.F_R_Expr.Kind =
                Libadalang.Common.Ada_Identifier
              and then Matches_Declaration
                (Child.As_Param_Assoc.F_R_Expr, Decl)
            then
               return True;
            end if;
         end;
      end loop;

      return False;
   end Has_Simple_Actual;

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

   function Is_Trackable_Index
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return True;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier then
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Referenced_Declaration (Node);
         begin
            return not Libadalang.Analysis.Is_Null (Decl)
              and then Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
                | Libadalang.Common.Ada_Param_Spec_Range;
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
         --  Calls used as indices can mutate hidden state between textual
         --  occurrences, so only ordinary expressions are cacheable.
         return False;
      end if;

      for I in 1 .. Node.Children_Count loop
         if not Is_Trackable_Index (Node.Child (I)) then
            return False;
         end if;
      end loop;
      return True;
   end Is_Trackable_Index;

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
              and then Is_Trackable_Index (Dest.As_Call_Expr.F_Suffix));
      end;
   end Is_Trackable_Assignment;

   function Indices_Unchanged_Between
     (Assignment : Libadalang.Analysis.Assign_Stmt;
      Later      : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Dest : constant Libadalang.Analysis.Name := Assignment.F_Dest;

      function Is_Index_Declaration
        (Decl : Libadalang.Analysis.Basic_Decl;
         Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif Node.Kind = Libadalang.Common.Ada_Identifier
           and then Referenced_Declaration (Node) = Decl
         then
            return True;
         end if;

         for I in 1 .. Node.Children_Count loop
            if Is_Index_Declaration (Decl, Node.Child (I)) then
               return True;
            end if;
         end loop;
         return False;
      end Is_Index_Declaration;

      function Is_Strictly_Between
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
      begin
         return
           (Natural (Node.Sloc_Range.Start_Line) >
              Natural (Assignment.Sloc_Range.End_Line)
            or else
             (Natural (Node.Sloc_Range.Start_Line) =
                Natural (Assignment.Sloc_Range.End_Line)
              and then Natural (Node.Sloc_Range.Start_Column) >=
                Natural (Assignment.Sloc_Range.End_Column)))
           and then
           (Natural (Node.Sloc_Range.End_Line) <
              Natural (Later.Sloc_Range.Start_Line)
            or else
              (Natural (Node.Sloc_Range.End_Line) =
                Natural (Later.Sloc_Range.Start_Line)
              and then Natural (Node.Sloc_Range.End_Column) <=
                Natural (Later.Sloc_Range.Start_Column)));
      end Is_Strictly_Between;

      function Contains_Index_Write
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
         function References_An_Index
           (Candidate : Libadalang.Analysis.Ada_Node'Class) return Boolean
         is
         begin
            if Libadalang.Analysis.Is_Null (Candidate) then
               return False;
            elsif Candidate.Kind = Libadalang.Common.Ada_Identifier then
               declare
                  Referenced : constant Libadalang.Analysis.Basic_Decl :=
                    Referenced_Declaration (Candidate);
               begin
                  return not Libadalang.Analysis.Is_Null (Referenced)
                    and then Is_Index_Declaration
                      (Referenced, Dest.As_Call_Expr.F_Suffix);
               end;
            end if;

            for I in 1 .. Candidate.Children_Count loop
               if References_An_Index (Candidate.Child (I)) then
                  return True;
               end if;
            end loop;
            return False;
         end References_An_Index;
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt
           and then Is_Strictly_Between (Node)
         then
            declare
               Written : constant Libadalang.Analysis.Basic_Decl :=
                 Assigned_Declaration (Node);
            begin
               return not Libadalang.Analysis.Is_Null (Written)
                 and then Is_Index_Declaration
                   (Written, Dest.As_Call_Expr.F_Suffix);
            end;
         elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt
           and then Is_Strictly_Between (Node)
           and then References_An_Index (Node)
         then
            --  Without a fully resolved profile, a call mentioning an index
            --  might pass it as out or in out. Invalidating is conservative.
            return True;
         end if;

         for I in 1 .. Node.Children_Count loop
            if Contains_Index_Write (Node.Child (I)) then
               return True;
            end if;
         end loop;
         return False;
      end Contains_Index_Write;

      Root : Libadalang.Analysis.Ada_Node := Assignment.As_Ada_Node;
   begin
      if Dest.Kind /= Libadalang.Common.Ada_Call_Expr then
         return True;
      end if;

      while not Libadalang.Analysis.Is_Null (Root.Parent) loop
         Root := Root.Parent;
      end loop;
      return not Contains_Index_Write (Root);
   end Indices_Unchanged_Between;

   function Same_Assigned_Target
     (Left, Right : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      return Is_Trackable_Assignment (Left)
        and then Is_Trackable_Assignment (Right)
        and then Assigned_Declaration (Left) = Assigned_Declaration (Right)
        and then Canonical_Text (Left.As_Assign_Stmt.F_Dest) =
          Canonical_Text (Right.As_Assign_Stmt.F_Dest)
        and then Indices_Unchanged_Between
          (Left.As_Assign_Stmt, Right);
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
               return Indices_Unchanged_Between (Assignment, Candidate);
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

   function First_Access
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Decl  : Libadalang.Analysis.Basic_Decl;
      After : Libadalang.Analysis.Ada_Node'Class) return Access_Result
   is
      function Starts_At_Or_After
        (Candidate : Libadalang.Analysis.Ada_Node'Class) return Boolean is
      begin
         return Natural (Candidate.Sloc_Range.Start_Line) >
             Natural (After.Sloc_Range.End_Line)
           or else
             (Natural (Candidate.Sloc_Range.Start_Line) =
                Natural (After.Sloc_Range.End_Line)
              and then Natural (Candidate.Sloc_Range.Start_Column) >=
                Natural (After.Sloc_Range.End_Column));
      end Starts_At_Or_After;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return (Kind => No_Access, Node => Libadalang.Analysis.No_Ada_Node);
      end if;

      if Starts_At_Or_After (Node) then
         if Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
            declare
               Stmt    : constant Libadalang.Analysis.Assign_Stmt :=
                 Node.As_Assign_Stmt;
               --  Checked directly against the RHS/complex destination
               --  (not via Reads_Declaration's own Ada_Assign_Stmt case,
               --  which treats every mention in F_Expr as a read for
               --  Dead_Store's coarser purposes) so that passing Decl as a
               --  pure out actual -- itself a write, not a read of its
               --  prior value -- is correctly excluded via
               --  Association_Reads_Actual.
               Is_Read : constant Boolean :=
                 Reads_Declaration (Stmt.F_Expr, Decl)
                 or else
                   (Stmt.F_Dest.Kind /= Libadalang.Common.Ada_Identifier
                    and then Reads_Declaration (Stmt.F_Dest, Decl));
            begin
               if Is_Read then
                  return (Kind => Read_Access,
                           Node => Libadalang.Analysis.Ada_Node (Node));
               elsif Assigned_Declaration (Node) = Decl
                 and then Stmt.F_Dest.Kind = Libadalang.Common.Ada_Identifier
               then
                  return (Kind => Write_Access,
                           Node => Libadalang.Analysis.Ada_Node (Node));
               end if;
               return
                 (Kind => No_Access, Node => Libadalang.Analysis.No_Ada_Node);
            end;
         elsif Node.Kind = Libadalang.Common.Ada_Identifier
           and then Matches_Declaration (Node, Decl)
         then
            return (Kind => Read_Access,
                     Node => Libadalang.Analysis.Ada_Node (Node));
         elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
            if Has_Simple_Actual (Node.As_Call_Expr, Decl) then
               --  Reads_Declaration deliberately treats an unresolved formal
               --  as a possible read to avoid false Dead_Store reports.
               --  Uninitialized_Read needs the opposite policy: without a
               --  resolved mode there is not enough evidence to say that
               --  the incoming value is consumed.
               if Call_Reads_Simple_Actual (Node.As_Call_Expr, Decl) then
                  return (Kind => Read_Access,
                           Node => Libadalang.Analysis.Ada_Node (Node));
               elsif Call_Writes_Declaration (Node.As_Call_Expr, Decl) then
                  return (Kind => Write_Access,
                           Node => Libadalang.Analysis.Ada_Node (Node));
               end if;
               --  The actual is present but its formal mode remains
               --  unresolved. The call may initialize it, so continuing to a
               --  later read and reporting that read as definitely preceding
               --  every write is unsound. Preserve the uncertainty as a
               --  terminal first-access result.
               return (Kind => Unknown_Access,
                        Node => Libadalang.Analysis.Ada_Node (Node));
            elsif Reads_Declaration (Node, Decl) then
               return (Kind => Read_Access,
                        Node => Libadalang.Analysis.Ada_Node (Node));
            end if;
            return (Kind => No_Access, Node => Libadalang.Analysis.No_Ada_Node);
         end if;
      end if;

      for I in 1 .. Node.Children_Count loop
         declare
            Child : constant Libadalang.Analysis.Ada_Node := Node.Child (I);
         begin
            --  A nested subprogram or entry body is a declaration: it is
            --  elaborated, not executed, at its own textual position, so
            --  a read or write inside it does not happen "here" the way a
            --  statement does. This plain pre-order walk has no notion of
            --  actual call order, so without this exclusion a read deep
            --  inside a nested body declared earlier in the enclosing
            --  declarative part -- but only ever called later, after Decl
            --  is genuinely initialized by a statement of the enclosing
            --  subprogram itself -- would be mistaken for happening
            --  before that initialization (observed in the wild: AWS.
            --  Headers.Values.Split's nested To_Set calls Next_Value,
            --  whose out-mode formals initialize To_Set's own locals,
            --  before ever invoking its own nested Element, which reads
            --  them as up-level references; Element's declaration,
            --  though, textually precedes that Next_Value call). This
            --  trades away detecting a genuine read through a nested body
            --  invoked before Decl's initialization -- unrecognized here,
            --  not soundly ruled out -- for not flagging the common,
            --  correct case; consistent with this project's general bias
            --  toward fewer false positives.
            if Libadalang.Analysis.Is_Null (Child)
              or else Child.Kind not in Libadalang.Common.Ada_Subp_Body
                | Libadalang.Common.Ada_Entry_Body
            then
               declare
                  Result : constant Access_Result :=
                    First_Access (Child, Decl, After);
               begin
                  if Result.Kind /= No_Access then
                     return Result;
                  end if;
               end;
            end if;
         end;
      end loop;

      return (Kind => No_Access, Node => Libadalang.Analysis.No_Ada_Node);
   end First_Access;

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

   --  True when Sibling is "for <Decl's name>'Address use ...;": the
   --  pre-Ada-2012 attribute-definition-clause spelling of an address
   --  clause, written as its own declarative item rather than as part of
   --  Decl's declaration, so neither P_Has_Aspect nor P_Get_Aspect sees it
   --  from Decl alone.
   function Is_Address_Clause_For
     (Sibling   : Libadalang.Analysis.Ada_Node'Class;
      Decl_Name : String) return Boolean
   is
   begin
      if Sibling.Kind /= Libadalang.Common.Ada_Attribute_Def_Clause then
         return False;
      end if;

      declare
         Attribute_Expr : constant Libadalang.Analysis.Name :=
           Sibling.As_Attribute_Def_Clause.F_Attribute_Expr;
      begin
         return not Libadalang.Analysis.Is_Null (Attribute_Expr)
           and then Attribute_Expr.Kind = Libadalang.Common.Ada_Attribute_Ref
           and then Canonical_Text
             (Attribute_Expr.As_Attribute_Ref.F_Attribute) = "address"
           and then Canonical_Text
             (Attribute_Expr.As_Attribute_Ref.F_Prefix) = Decl_Name;
      end;
   end Is_Address_Clause_For;

   function Is_Externally_Observable
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      --  P_Has_Aspect only answers for boolean aspects (it always reports
      --  Address as absent, aspect-specification or attribute-clause form
      --  alike); P_Get_Aspect / Exists is the general form that covers a
      --  value aspect such as Address too -- but only its aspect-
      --  specification spelling ("with Address => ..."). Checked
      --  individually, not as one "or else" chain: resolving a
      --  representation-clause-form Address can raise a Libadalang
      --  property error on an otherwise unrelated declaration, and that
      --  must not suppress a Volatile/Atomic match already found, nor the
      --  attribute-definition-clause fallback below.
      function Has_Named_Aspect (Name : String) return Boolean is
      begin
         return Libadalang.Analysis.Exists
           (Decl.P_Get_Aspect
              (Langkit_Support.Text.To_Unbounded_Text
                 (Langkit_Support.Text.To_Text (Name))));
      exception
         when others =>
            return False;
      end Has_Named_Aspect;
   begin
      if Has_Named_Aspect ("Volatile")
        or else Has_Named_Aspect ("Atomic")
        or else Has_Named_Aspect ("Volatile_Full_Access")
        or else Has_Named_Aspect ("Address")
      then
         return True;
      end if;

      declare
         Decl_Name : constant String :=
           Canonical_Text (Decl.P_Defining_Name);
         Decl_List : constant Libadalang.Analysis.Ada_Node := Decl.Parent;
      begin
         if Decl_Name = "" or else Libadalang.Analysis.Is_Null (Decl_List)
         then
            return False;
         end if;

         for I in 1 .. Decl_List.Children_Count loop
            if Is_Address_Clause_For (Decl_List.Child (I), Decl_Name) then
               return True;
            end if;
         end loop;
      end;

      return False;
   exception
      when others =>
         --  Name resolution can legitimately fail for incomplete source.
         return False;
   end Is_Externally_Observable;

end Adalang_Analyzer.Checks.Data_Flow;
