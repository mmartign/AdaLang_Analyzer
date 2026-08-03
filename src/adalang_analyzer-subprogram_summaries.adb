--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Config; use Adalang_Analyzer.Config;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Subprogram_Summaries is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;

   package Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type => Positive, Element_Type => String);

   type Formal_Effect is record
      Name              : Unbounded_String;
      May_Read          : Boolean := False;
      May_Write         : Boolean := False;
      Definitely_Writes : Boolean := False;
   end record;

   package Formal_Effect_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Formal_Effect);

   type Summary is record
      Name             : Unbounded_String;
      Callees          : Name_Vectors.Vector;
      Global_Writes    : Name_Vectors.Vector;
      Formals          : Formal_Effect_Vectors.Vector;
      Effects_Complete : Boolean := True;
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
      elsif Call.Kind in Libadalang.Common.Ada_Name then
         return Call.As_Name.P_Referenced_Decl
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

   function Normalized_Name
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      return Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
        (Langkit_Support.Text.To_UTF8 (Node.Text));
   exception
      when others =>
         return "";
   end Normalized_Name;

   function Object_Key
     (Decl : Libadalang.Analysis.Basic_Decl;
      Name : String) return String is
   begin
      return Declaration_Name (Decl) & ":" & Name;
   end Object_Key;

   function Is_Within
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Root : Libadalang.Analysis.Subp_Body) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Node);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current = Libadalang.Analysis.Ada_Node (Root) then
            return True;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Is_Within;

   function Written_Declaration
     (Dest : Libadalang.Analysis.Name'Class)
      return Libadalang.Analysis.Basic_Decl
   is
      function Ultimate_Object
        (Decl  : Libadalang.Analysis.Basic_Decl;
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
      case Dest.Kind is
         when Libadalang.Common.Ada_Identifier =>
            return Ultimate_Object
              (Dest.P_Referenced_Decl (Imprecise_Fallback => True));
         when Libadalang.Common.Ada_Dotted_Name =>
            return Written_Declaration (Dest.As_Dotted_Name.F_Prefix);
         when Libadalang.Common.Ada_Call_Expr =>
            if Dest.As_Call_Expr.P_Kind = Libadalang.Common.Call then
               return Libadalang.Analysis.No_Basic_Decl;
            end if;
            return Written_Declaration (Dest.As_Call_Expr.F_Name);
         when others =>
            return Libadalang.Analysis.No_Basic_Decl;
      end case;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Written_Declaration;

   procedure Mark_Formal_Write
     (Item : in out Summary;
      Name : String)
   is
   begin
      for Index in Item.Formals.First_Index .. Item.Formals.Last_Index loop
         if To_String (Item.Formals (Index).Name) = Name then
            declare
               Effect : Formal_Effect := Item.Formals (Index);
            begin
               Effect.May_Write := True;
               Item.Formals.Replace_Element (Index, Effect);
            end;
            return;
         end if;
      end loop;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping formal-write marking: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Mark_Formal_Write;

   function Ultimate_Written_Name
     (Dest  : Libadalang.Analysis.Name'Class;
      Depth : Natural := 0) return String
   is
   begin
      if Depth >= 16 then
         return "";
      end if;
      case Dest.Kind is
         when Libadalang.Common.Ada_Identifier =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Dest.P_Referenced_Decl (Imprecise_Fallback => True);
            begin
               if not Libadalang.Analysis.Is_Null (Decl)
                 and then Decl.Kind in
                   Libadalang.Common.Ada_Object_Decl_Range
               then
                  declare
                     Clause : constant Libadalang.Analysis.Renaming_Clause :=
                       Decl.As_Object_Decl.F_Renaming_Clause;
                  begin
                     if not Libadalang.Analysis.Is_Null (Clause)
                       and then Clause.F_Renamed_Object.Kind in
                         Libadalang.Common.Ada_Name
                     then
                        return Ultimate_Written_Name
                          (Clause.F_Renamed_Object.As_Name, Depth + 1);
                     end if;
                  end;
               end if;
               return Normalized_Name (Dest);
            end;
         when Libadalang.Common.Ada_Dotted_Name =>
            return Ultimate_Written_Name
              (Dest.As_Dotted_Name.F_Prefix, Depth);
         when Libadalang.Common.Ada_Call_Expr =>
            if Dest.As_Call_Expr.P_Kind = Libadalang.Common.Call then
               return "";
            end if;
            return Ultimate_Written_Name
              (Dest.As_Call_Expr.F_Name, Depth);
         when others =>
            return "";
      end case;
   exception
      when others =>
         return "";
   end Ultimate_Written_Name;

   function Formal_Is_Writable
     (Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Formal);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return Current.As_Param_Spec.F_Mode.Kind in
              Libadalang.Common.Ada_Mode_Out_Range
                | Libadalang.Common.Ada_Mode_In_Out_Range;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Formal_Is_Writable;

   function Formal_May_Read_Incoming
     (Formal : Libadalang.Analysis.Param_Spec) return Boolean is
   begin
      return Formal.F_Mode.Kind not in Libadalang.Common.Ada_Mode_Out_Range;
   exception
      when others =>
         return True;
   end Formal_May_Read_Incoming;

   procedure Scan_Call_Actual_Writes
     (Call : Libadalang.Analysis.Name'Class;
      Root : Libadalang.Analysis.Subp_Body;
      Item : in out Summary)
   is
   begin
      for Pair of Call.P_Call_Params loop
         if Formal_Is_Writable (Libadalang.Analysis.Param (Pair))
           and then Libadalang.Analysis.Actual (Pair).Kind in
             Libadalang.Common.Ada_Name
         then
            declare
               Actual : constant Libadalang.Analysis.Name :=
                 Libadalang.Analysis.Actual (Pair).As_Name;
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Written_Declaration (Actual);
            begin
               if Libadalang.Analysis.Is_Null (Decl) then
                  Item.Effects_Complete := False;
               elsif Decl.Kind in Libadalang.Common.Ada_Param_Spec_Range then
                  Mark_Formal_Write (Item, Ultimate_Written_Name (Actual));
               elsif not Is_Within (Decl, Root) then
                  Include
                    (Item.Global_Writes,
                     Object_Key (Decl, Ultimate_Written_Name (Actual)));
               end if;
            end;
         end if;
      end loop;
   exception
      when others =>
         Item.Effects_Complete := False;
   end Scan_Call_Actual_Writes;

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

         when Libadalang.Common.Ada_Assign_Stmt =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Written_Declaration (Node.As_Assign_Stmt.F_Dest);
            begin
               if Libadalang.Analysis.Is_Null (Decl) then
                  Item.Effects_Complete := False;
               elsif Decl.Kind in Libadalang.Common.Ada_Param_Spec_Range then
                  Mark_Formal_Write
                    (Item,
                     Ultimate_Written_Name (Node.As_Assign_Stmt.F_Dest));
               elsif not Is_Within (Decl, Root) then
                  Include
                    (Item.Global_Writes,
                     Object_Key
                       (Decl,
                        Ultimate_Written_Name
                          (Node.As_Assign_Stmt.F_Dest)));
               end if;
            end;

         when Libadalang.Common.Ada_Call_Expr
            | Libadalang.Common.Ada_Call_Stmt =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Call_Declaration (Node);
            begin
               if Node.Kind = Libadalang.Common.Ada_Call_Expr
                 and then Node.As_Call_Expr.P_Kind /= Libadalang.Common.Call
               then
                  null;
               elsif Node.Kind = Libadalang.Common.Ada_Call_Expr
                 and then Node.As_Call_Expr.F_Name.P_Is_Dispatching_Call
               then
                  Item.Effects_Complete := False;
               elsif not Libadalang.Analysis.Is_Null (Decl) then
                  if Decl.Kind = Libadalang.Common.Ada_Entry_Decl then
                     Item.Direct_May_Block := True;
                     Item.Effects_Complete := False;
                  else
                     Include (Item.Callees, Declaration_Name (Decl));
                  end if;
                  if Node.Kind = Libadalang.Common.Ada_Call_Expr then
                     Scan_Call_Actual_Writes
                       (Node.As_Call_Expr, Root, Item);
                  else
                     Scan_Call_Actual_Writes
                       (Node.As_Call_Stmt.F_Call, Root, Item);
                  end if;
               else
                  Item.Effects_Complete := False;
               end if;
            end;

         when others =>
            null;
      end case;

      for Index in 1 .. Node.Children_Count loop
         Scan_Effects (Node.Child (Index), Root, Item);
      end loop;
   end Scan_Effects;

   function Body_Definitely_Writes
     (Subprogram : Libadalang.Analysis.Subp_Body;
      Formal     : Libadalang.Analysis.Defining_Name) return Boolean;

   procedure Register_Body
     (Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Item     : Summary;
      Key_Decl : Libadalang.Analysis.Basic_Decl :=
        Libadalang.Analysis.Basic_Decl (Subprogram);
   begin
      declare
         --  Decl_Part is assigned here rather than initialized in the
         --  declarative part above: a Property_Error raised while
         --  elaborating a declare block's own declarative part is not
         --  handled by that block's own handlers (RM 11.2), so with
         --  Decl_Part as a constant initializer, a failing P_Decl_Part
         --  bypassed this block's handler entirely and was instead caught
         --  by Register_Body's own outer handler below, which discards the
         --  whole summary instead of falling back to Subprogram. This
         --  restores the intended narrow fallback for P_Decl_Part failures
         --  in general; it does not, by itself, close FP-029, whose
         --  reduced case still fails one step later when Declaration_Name
         --  (also needing to resolve the same externally defined subtype
         --  to build a mangled name) hits the identical upstream defect.
         Decl_Part : Libadalang.Analysis.Basic_Decl :=
           Libadalang.Analysis.No_Basic_Decl;
      begin
         Decl_Part := Subprogram.P_Decl_Part (Imprecise_Fallback => True);
         if not Libadalang.Analysis.Is_Null (Decl_Part) then
            Key_Decl := Decl_Part;
         end if;
      exception
         when Exc : others =>
            Log_Verbose_Once
              ("skipping subprogram declaration-part resolution: " &
               Ada.Exceptions.Exception_Message (Exc));
      end;

      Item.Name := To_Unbounded_String
        (Declaration_Name (Key_Decl));
      if Item.Name = Null_Unbounded_String
        or else Find (To_String (Item.Name)) /= 0
      then
         return;
      end if;

      for Param of Subprogram.F_Subp_Spec.P_Params loop
         for Id of Param.F_Ids loop
            Item.Formals.Append
              ((Name => To_Unbounded_String (Normalized_Name (Id)),
                May_Read => Formal_May_Read_Incoming (Param),
                May_Write => False,
                Definitely_Writes => False));
         end loop;
      end loop;

      Scan_Effects (Subprogram, Subprogram, Item);
      declare
         Index : Positive := Item.Formals.First_Index;
      begin
         for Param of Subprogram.F_Subp_Spec.P_Params loop
            for Id of Param.F_Ids loop
               if Body_Definitely_Writes (Subprogram, Id.As_Defining_Name) then
                  declare
                     Effect : Formal_Effect := Item.Formals (Index);
                  begin
                     Effect.Definitely_Writes := True;
                     Item.Formals.Replace_Element (Index, Effect);
                  end;
               end if;
               Index := Index + 1;
            end loop;
         end loop;
      end;
      Item.May_Block := Item.Direct_May_Block;
      Item.May_Raise := Item.Direct_May_Raise;
      Summaries.Append (Item);
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping subprogram summary registration: " &
            Ada.Exceptions.Exception_Message (Exc));
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
      when Exc : others =>
         Log_Verbose_Once
           ("skipping unit summary scan: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Scan_Unit;

   function Callee_Index
     (Call : Libadalang.Analysis.Ada_Node'Class) return Natural;

   function Formal_Index
     (Summary_Index : Positive;
      Formal        : Libadalang.Analysis.Defining_Name'Class) return Natural;

   type Initialization_Result is record
      Can_Fall_Through : Boolean := True;
      Initialized      : Boolean := False;
   end record;

   function Merge
     (Left, Right : Initialization_Result) return Initialization_Result is
   begin
      if not Left.Can_Fall_Through then
         return Right;
      elsif not Right.Can_Fall_Through then
         return Left;
      else
         return
           (Can_Fall_Through => True,
            Initialized => Left.Initialized and then Right.Initialized);
      end if;
   end Merge;

   function Statement_Initialization
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Formal     : Libadalang.Analysis.Defining_Name;
      Initial    : Boolean;
      Bad_Return : in out Boolean) return Initialization_Result;

   function List_Initialization
     (List       : Libadalang.Analysis.Ada_Node'Class;
      Formal     : Libadalang.Analysis.Defining_Name;
      Initial    : Boolean;
      Bad_Return : in out Boolean) return Initialization_Result
   is
      Result : Initialization_Result :=
        (Can_Fall_Through => True, Initialized => Initial);
   begin
      if Libadalang.Analysis.Is_Null (List) then
         return Result;
      end if;
      for Index in 1 .. List.Children_Count loop
         exit when not Result.Can_Fall_Through;
         Result := Statement_Initialization
           (List.Child (Index), Formal, Result.Initialized, Bad_Return);
      end loop;
      return Result;
   end List_Initialization;

   function Call_Definitely_Writes
     (Call   : Libadalang.Analysis.Name'Class;
      Formal : Libadalang.Analysis.Defining_Name) return Boolean
   is
      Summary_Index : constant Natural := Callee_Index (Call);
   begin
      if Summary_Index = 0
        or else not Summaries (Summary_Index).Effects_Complete
      then
         return False;
      end if;

      for Pair of Call.P_Call_Params loop
         if Libadalang.Analysis.Actual (Pair).Kind =
              Libadalang.Common.Ada_Identifier
           and then Written_Declaration
             (Libadalang.Analysis.Actual (Pair).As_Name) = Formal.P_Basic_Decl
           and then Ultimate_Written_Name
             (Libadalang.Analysis.Actual (Pair).As_Name) =
               Normalized_Name (Formal)
         then
            declare
               Index : constant Natural := Formal_Index
                 (Summary_Index, Libadalang.Analysis.Param (Pair));
            begin
               if Index /= 0
                 and then Summaries (Summary_Index).Formals (Index)
                   .Definitely_Writes
               then
                  return True;
               end if;
            end;
         end if;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Call_Definitely_Writes;

   function Statement_Initialization
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Formal     : Libadalang.Analysis.Defining_Name;
      Initial    : Boolean;
      Bad_Return : in out Boolean) return Initialization_Result
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return (True, Initial);
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Assign_Stmt =>
            return
              (True,
               Initial or else
                 (Node.As_Assign_Stmt.F_Dest.Kind =
                    Libadalang.Common.Ada_Identifier
                  and then Written_Declaration
                    (Node.As_Assign_Stmt.F_Dest) = Formal.P_Basic_Decl
                  and then Ultimate_Written_Name
                    (Node.As_Assign_Stmt.F_Dest) =
                    Normalized_Name (Formal)));

         when Libadalang.Common.Ada_Call_Stmt =>
            return
              (True,
               Initial or else Call_Definitely_Writes
                 (Node.As_Call_Stmt.F_Call, Formal));

         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt =>
            Bad_Return := Bad_Return or else not Initial;
            return (False, Initial);

         when Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            return (False, Initial);

         when Libadalang.Common.Ada_If_Stmt =>
            declare
               Stmt : constant Libadalang.Analysis.If_Stmt :=
                 Node.As_If_Stmt;
               Result : Initialization_Result := List_Initialization
                 (Stmt.F_Then_Stmts, Formal, Initial, Bad_Return);
            begin
               for Alternative of Stmt.F_Alternatives loop
                  Result := Merge
                    (Result,
                     List_Initialization
                       (Alternative.F_Stmts, Formal, Initial, Bad_Return));
               end loop;
               if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
                  Result := Merge (Result, (True, Initial));
               else
                  Result := Merge
                    (Result,
                     List_Initialization
                       (Stmt.F_Else_Part.F_Stmts, Formal, Initial,
                        Bad_Return));
               end if;
               return Result;
            end;

         when Libadalang.Common.Ada_Case_Stmt =>
            declare
               First : Boolean := True;
               Result : Initialization_Result := (False, Initial);
            begin
               for Alternative of Node.As_Case_Stmt.F_Alternatives loop
                  declare
                     Branch : constant Initialization_Result :=
                       List_Initialization
                         (Alternative.F_Stmts, Formal, Initial, Bad_Return);
                  begin
                     if First then
                        Result := Branch;
                        First := False;
                     else
                        Result := Merge (Result, Branch);
                     end if;
                  end;
               end loop;
               return Result;
            end;

         when Libadalang.Common.Ada_Decl_Block =>
            return List_Initialization
              (Node.As_Decl_Block.F_Stmts.F_Stmts, Formal, Initial,
               Bad_Return);

         when others =>
            return (True, Initial);
      end case;
   exception
      when others =>
         return (True, Initial);
   end Statement_Initialization;

   function Body_Definitely_Writes
     (Subprogram : Libadalang.Analysis.Subp_Body;
      Formal     : Libadalang.Analysis.Defining_Name) return Boolean
   is
      Bad_Return : Boolean := False;
      Result : constant Initialization_Result := List_Initialization
        (Subprogram.F_Stmts.F_Stmts, Formal, False, Bad_Return);
   begin
      --  Starting handlers from uninitialized is conservative: an exception
      --  can be raised before the first ordinary-body write.
      for Handler of Subprogram.F_Stmts.F_Exceptions loop
         declare
            Handler_Result : constant Initialization_Result :=
              List_Initialization
                (Handler.As_Exception_Handler.F_Stmts, Formal, False,
                 Bad_Return);
         begin
            if Handler_Result.Can_Fall_Through
              and then not Handler_Result.Initialized
            then
               Bad_Return := True;
            end if;
         end;
      end loop;
      return not Bad_Return
        and then (not Result.Can_Fall_Through or else Result.Initialized);
   exception
      when others =>
         return False;
   end Body_Definitely_Writes;

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
                     if not Summaries (Callee_Index).Effects_Complete
                       and then Summaries (Index).Effects_Complete
                     then
                        Summaries (Index).Effects_Complete := False;
                        Changed := True;
                     end if;
                     for Written of Summaries (Callee_Index).Global_Writes loop
                        declare
                           Before : constant Natural :=
                             Natural (Summaries (Index).Global_Writes.Length);
                        begin
                           Include
                             (Summaries (Index).Global_Writes, Written);
                           if Natural
                             (Summaries (Index).Global_Writes.Length) /= Before
                           then
                              Changed := True;
                           end if;
                        end;
                     end loop;
                  elsif Summaries (Index).Effects_Complete then
                     Summaries (Index).Effects_Complete := False;
                     Changed := True;
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

   function Formal_Index
     (Summary_Index : Positive;
      Formal        : Libadalang.Analysis.Defining_Name'Class) return Natural
   is
      Name : constant String := Normalized_Name (Formal);
   begin
      for Index in Summaries (Summary_Index).Formals.First_Index ..
        Summaries (Summary_Index).Formals.Last_Index
      loop
         if To_String (Summaries (Summary_Index).Formals (Index).Name) = Name
         then
            return Index;
         end if;
      end loop;
      return 0;
   exception
      when others =>
         return 0;
   end Formal_Index;

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

   function Callee_State_Effects_Known
     (Call : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Index : constant Natural := Callee_Index (Call);
   begin
      return Index /= 0 and then Summaries (Index).Effects_Complete;
   end Callee_State_Effects_Known;

   function Callee_Global_Write_Count
     (Call : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Index : constant Natural := Callee_Index (Call);
   begin
      return
        (if Index = 0 then 0
         else Natural (Summaries (Index).Global_Writes.Length));
   end Callee_Global_Write_Count;

   function Callee_Global_Write
     (Call  : Libadalang.Analysis.Ada_Node'Class;
      Index : Positive) return String
   is
      Summary_Index : constant Natural := Callee_Index (Call);
   begin
      if Summary_Index = 0
        or else Index > Natural (Summaries (Summary_Index).Global_Writes.Length)
      then
         return "";
      end if;
      return Summaries (Summary_Index).Global_Writes (Index);
   end Callee_Global_Write;

   function Callee_Formal_May_Write
     (Call   : Libadalang.Analysis.Ada_Node'Class;
      Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean
   is
      Summary_Index : constant Natural := Callee_Index (Call);
      Index : constant Natural :=
        (if Summary_Index = 0 then 0
         else Formal_Index (Summary_Index, Formal));
   begin
      return Index /= 0 and then Summaries (Summary_Index).Formals (Index).May_Write;
   end Callee_Formal_May_Write;

   function Callee_Formal_May_Read
     (Call   : Libadalang.Analysis.Ada_Node'Class;
      Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean
   is
      Summary_Index : constant Natural := Callee_Index (Call);
      Index : constant Natural :=
        (if Summary_Index = 0 then 0
         else Formal_Index (Summary_Index, Formal));
   begin
      return Index /= 0
        and then Summaries (Summary_Index).Formals (Index).May_Read;
   end Callee_Formal_May_Read;

   function Callee_Formal_Definitely_Writes
     (Call   : Libadalang.Analysis.Ada_Node'Class;
      Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean
   is
      Summary_Index : constant Natural := Callee_Index (Call);
      Index : constant Natural :=
        (if Summary_Index = 0 then 0
         else Formal_Index (Summary_Index, Formal));
   begin
      return Index /= 0
        and then Summaries (Summary_Index).Effects_Complete
        and then Summaries (Summary_Index).Formals (Index).Definitely_Writes;
   end Callee_Formal_Definitely_Writes;

   function Count return Natural is
   begin
      return Natural (Summaries.Length);
   end Count;

end Adalang_Analyzer.Subprogram_Summaries;
