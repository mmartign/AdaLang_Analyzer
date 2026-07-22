--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Vectors;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;    use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Domain; use Adalang_Analyzer.Flow_Domain;
with Adalang_Analyzer.Flow_Eval;   use Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Report;      use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;       use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils;  use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.SPARK_Readiness is

   use type Ada.Containers.Count_Type;
   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   type Access_Info is record
      Key        : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Name       : Unbounded_String;
      Site       : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Is_Read    : Boolean := False;
      Is_Written : Boolean := False;
   end record;

   package Access_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Access_Info);

   function Contract_Expression
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Libadalang.Analysis.Expr
   is
      Result : Libadalang.Analysis.Expr;
   begin
      Result := Decl.P_Get_Aspect_Spec_Expr
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Name)));
      if Libadalang.Analysis.Is_Null (Result)
        and then Decl.Kind = Libadalang.Common.Ada_Subp_Body
      then
         declare
            Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
              Decl.As_Subp_Body.P_Decl_Part
                (Imprecise_Fallback => True);
         begin
            if not Libadalang.Analysis.Is_Null (Decl_Part) then
               Result := Decl_Part.P_Get_Aspect_Spec_Expr
                 (Langkit_Support.Text.To_Unbounded_Text
                    (Langkit_Support.Text.To_Text (Name)));
            end if;
         end;
      end if;
      return Result;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Contract_Expression;

   function Effective_SPARK_Enabled
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Aspect : Libadalang.Analysis.Aspect;
   begin
      Aspect := Decl.P_Get_Aspect
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text ("SPARK_Mode")));
      return not Libadalang.Analysis.Exists (Aspect)
        or else Libadalang.Analysis.Is_Null
          (Libadalang.Analysis.Value (Aspect))
        or else Normalize_Rule_Name
          (Node_Text (Libadalang.Analysis.Value (Aspect))) /= "off";
   exception
      when others =>
         return True;
   end Effective_SPARK_Enabled;

   function Is_Within
     (Decl : Libadalang.Analysis.Basic_Decl;
      Root : Libadalang.Analysis.Subp_Body) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Decl);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current = Libadalang.Analysis.Ada_Node (Root) then
            return True;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_Within;

   function Referenced_Object_Key
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Root : Libadalang.Analysis.Subp_Body)
      return Libadalang.Analysis.Ada_Node
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      Decl := Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind /= Libadalang.Common.Ada_Object_Decl
        or else Is_Within (Decl, Root)
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;
      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Referenced_Object_Key;

   function Is_Parameter_Key
     (Key : Libadalang.Analysis.Ada_Node) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Key;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return True;
         elsif Current.Kind = Libadalang.Common.Ada_Object_Decl then
            return False;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_Parameter_Key;

   function Equivalent_Keys
     (Left, Right : Libadalang.Analysis.Ada_Node) return Boolean is
     (Left = Right
      or else
        (Is_Parameter_Key (Left)
         and then Is_Parameter_Key (Right)
         and then Normalize_Rule_Name (Node_Text (Left)) =
           Normalize_Rule_Name (Node_Text (Right))));

   function Find
     (Items : Access_Vectors.Vector;
      Key   : Libadalang.Analysis.Ada_Node) return Natural
   is
   begin
      for I in Items.First_Index .. Items.Last_Index loop
         if Equivalent_Keys (Items (I).Key, Key) then
            return I;
         end if;
      end loop;
      return 0;
   exception
      when Constraint_Error =>
         return 0;
   end Find;

   procedure Include
     (Items      : in out Access_Vectors.Vector;
      Key        : Libadalang.Analysis.Ada_Node;
      Name       : String;
      Site       : Libadalang.Analysis.Ada_Node'Class;
      Is_Read    : Boolean;
      Is_Written : Boolean)
   is
      Index : constant Natural := Find (Items, Key);
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      elsif Index = 0 then
         Items.Append
           ((Key        => Key,
             Name       => To_Unbounded_String (Name),
             Site       => Libadalang.Analysis.Ada_Node (Site),
             Is_Read    => Is_Read,
             Is_Written => Is_Written));
      else
         Items (Index).Is_Read := Items (Index).Is_Read or else Is_Read;
         Items (Index).Is_Written :=
           Items (Index).Is_Written or else Is_Written;
      end if;
   end Include;

   procedure Include_Identifier
     (Items      : in out Access_Vectors.Vector;
      Node       : Libadalang.Analysis.Ada_Node'Class;
      Root       : Libadalang.Analysis.Subp_Body;
      Is_Read    : Boolean;
      Is_Written : Boolean)
   is
      Key : constant Libadalang.Analysis.Ada_Node :=
        Referenced_Object_Key (Node, Root);
   begin
      if not Libadalang.Analysis.Is_Null (Key) then
         Include
           (Items, Key, Node_Text (Node), Node, Is_Read, Is_Written);
      end if;
   end Include_Identifier;

   procedure Collect_Contract_Objects
     (Expr       : Libadalang.Analysis.Ada_Node'Class;
      Root       : Libadalang.Analysis.Subp_Body;
      Site       : Libadalang.Analysis.Ada_Node'Class;
      Is_Read    : Boolean;
      Is_Written : Boolean;
      Items      : in out Access_Vectors.Vector)
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr) then
         return;
      elsif Expr.Kind = Libadalang.Common.Ada_Identifier then
         declare
            Key : constant Libadalang.Analysis.Ada_Node :=
              Referenced_Object_Key (Expr, Root);
         begin
            if not Libadalang.Analysis.Is_Null (Key) then
               Include
                 (Items, Key, Node_Text (Expr), Site, Is_Read, Is_Written);
            end if;
         end;
         return;
      end if;

      for I in 1 .. Expr.Children_Count loop
         Collect_Contract_Objects
           (Expr.Child (I), Root, Site, Is_Read, Is_Written, Items);
      end loop;
   end Collect_Contract_Objects;

   procedure Parse_Global
     (Expr  : Libadalang.Analysis.Expr;
      Root  : Libadalang.Analysis.Subp_Body;
      Site  : Libadalang.Analysis.Ada_Node'Class;
      Items : in out Access_Vectors.Vector)
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind = Libadalang.Common.Ada_Null_Literal
      then
         return;
      elsif Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate then
         Collect_Contract_Objects
           (Expr, Root, Site, Is_Read => True, Is_Written => False,
            Items => Items);
         return;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            declare
               Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                 Item.As_Aggregate_Assoc;
               Mode  : constant String :=
                 (if Assoc.F_Designators.Children_Count = 0 then "input"
                  else Normalize_Rule_Name
                    (Node_Text (Assoc.F_Designators.Child (1))));
               Reads : constant Boolean :=
                 Mode = "input" or else Mode = "in-out"
                   or else Mode = "proof-in";
               Writes : constant Boolean :=
                 Mode = "output" or else Mode = "in-out";
            begin
               Collect_Contract_Objects
                 (Assoc.F_R_Expr, Root, Site, Reads, Writes, Items);
            end;
         end if;
      end loop;
   end Parse_Global;

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

   procedure Collect_Accesses
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      Root  : Libadalang.Analysis.Subp_Body;
      Items : in out Access_Vectors.Vector;
      As_Write : Boolean := False);

   --  One actual's canonical text and whether the formal it feeds is
   --  written, tracked so Collect_Call can flag a later actual that aliases
   --  an earlier one when at least one side is written. Backs
   --  Aliasing_Between_Parameters.
   type Actual_Alias_Info is record
      Text            : Unbounded_String;
      Node            : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Is_Written_Side : Boolean := False;
   end record;

   package Actual_Alias_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Actual_Alias_Info);

   procedure Check_Actual_Aliasing
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Actual  : Libadalang.Analysis.Expr'Class;
      Written : Boolean;
      Seen    : in out Actual_Alias_Vectors.Vector)
   is
      Text : constant String := Canonical_Text (Actual);
   begin
      if Text = ""
        or else Actual.Kind not in Libadalang.Common.Ada_Identifier
          | Libadalang.Common.Ada_Dotted_Name
      then
         return;
      end if;

      for Prior of Seen loop
         if To_String (Prior.Text) = Text
           and then (Prior.Is_Written_Side or else Written)
         then
            Report_Rule_Violation
              (Unit, Actual, Aliasing_Between_Parameters,
               "actual parameter aliases an earlier actual in the same " &
                 "call, and at least one of them is written");
         end if;
      end loop;

      Seen.Append
        ((Text            => To_Unbounded_String (Text),
          Node            => Libadalang.Analysis.Ada_Node (Actual),
          Is_Written_Side => Written));
   end Check_Actual_Aliasing;

   procedure Collect_Call
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Call  : Libadalang.Analysis.Name'Class;
      Root  : Libadalang.Analysis.Subp_Body;
      Items : in out Access_Vectors.Vector)
   is
      Decl  : Libadalang.Analysis.Basic_Decl;
      Seen  : Actual_Alias_Vectors.Vector;
      Check_Aliasing : constant Boolean :=
        Rule_States (Aliasing_Between_Parameters) = Enabled;
   begin
      for Pair of Call.P_Call_Params loop
         declare
            Mode : constant Libadalang.Common.Ada_Node_Kind_Type :=
              Formal_Mode (Libadalang.Analysis.Param (Pair));
         begin
            if Check_Aliasing then
               Check_Actual_Aliasing
                 (Unit, Libadalang.Analysis.Actual (Pair),
                  Mode in Libadalang.Common.Ada_Mode_Out
                    | Libadalang.Common.Ada_Mode_In_Out,
                  Seen);
            end if;

            if Mode = Libadalang.Common.Ada_Mode_Out then
               Collect_Accesses
                 (Unit, Libadalang.Analysis.Actual (Pair), Root, Items,
                  As_Write => True);
            elsif Mode = Libadalang.Common.Ada_Mode_In_Out then
               Collect_Accesses
                 (Unit, Libadalang.Analysis.Actual (Pair), Root, Items);
               Collect_Accesses
                 (Unit, Libadalang.Analysis.Actual (Pair), Root, Items,
                  As_Write => True);
            else
               Collect_Accesses
                 (Unit, Libadalang.Analysis.Actual (Pair), Root, Items);
            end if;
         end;
      end loop;

      begin
         if Call.Kind = Libadalang.Common.Ada_Call_Expr then
            Decl := Call.As_Call_Expr.F_Name.P_Referenced_Decl;
         else
            Decl := Call.P_Referenced_Decl;
         end if;
         if not Libadalang.Analysis.Is_Null (Decl) then
            declare
               Global : constant Libadalang.Analysis.Expr :=
                 Contract_Expression (Decl, "Global");
            begin
               Parse_Global (Global, Root, Call, Items);
            end;
         end if;
      exception
         when others =>
            null;
      end;
   exception
      when others =>
         --  Resolution failure loses precision but must never turn into a
         --  guessed contract violation.
         null;
   end Collect_Call;

   procedure Collect_Accesses
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      Root  : Libadalang.Analysis.Subp_Body;
      Items : in out Access_Vectors.Vector;
      As_Write : Boolean := False)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Subp_Body then
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         Collect_Accesses
           (Unit, Node.As_Assign_Stmt.F_Dest, Root, Items, As_Write => True);
         Collect_Accesses (Unit, Node.As_Assign_Stmt.F_Expr, Root, Items);
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
         Collect_Call (Unit, Node.As_Call_Expr.F_Name, Root, Items);
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt then
         Collect_Call (Unit, Node.As_Call_Stmt.F_Call, Root, Items);
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier then
         Include_Identifier
           (Items, Node, Root,
            Is_Read => not As_Write, Is_Written => As_Write);
         return;
      end if;

      for I in 1 .. Node.Children_Count loop
         Collect_Accesses (Unit, Node.Child (I), Root, Items, As_Write);
      end loop;
   end Collect_Accesses;

   function Same_Parameter
     (Node   : Libadalang.Analysis.Ada_Node'Class;
      Param  : Libadalang.Analysis.Param_Spec;
      Name   : String) return Boolean
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
        or else Normalize_Rule_Name (Node_Text (Node)) /= Name
      then
         return False;
      end if;
      Decl := Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      return Libadalang.Analysis.Is_Null (Decl)
        or else Decl = Libadalang.Analysis.Basic_Decl (Param);
   exception
      when others =>
         return True;
   end Same_Parameter;

   function Statement_Writes_Parameter
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Param : Libadalang.Analysis.Param_Spec;
      Name  : String) return Boolean
   is
   begin
      if Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         return Same_Parameter (Node.As_Assign_Stmt.F_Dest, Param, Name);
      elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt then
         for Pair of Node.As_Call_Stmt.F_Call.P_Call_Params loop
            if Formal_Mode (Libadalang.Analysis.Param (Pair)) =
                 Libadalang.Common.Ada_Mode_Out
              and then Same_Parameter
                (Libadalang.Analysis.Actual (Pair), Param, Name)
            then
               return True;
            end if;
         end loop;
      end if;
      return False;
   exception
      when others =>
         return False;
   end Statement_Writes_Parameter;

   type Init_Result is record
      Can_Fall_Through : Boolean := True;
      Initialized      : Boolean := False;
   end record;

   function Merge (Left, Right : Init_Result) return Init_Result is
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

   function Interpret_Initialization
     (Node        : Libadalang.Analysis.Ada_Node'Class;
      Param       : Libadalang.Analysis.Param_Spec;
      Name        : String;
      Initial     : Boolean;
      Bad_Return  : in out Boolean) return Init_Result;

   function Interpret_List
     (List        : Libadalang.Analysis.Ada_Node'Class;
      Param       : Libadalang.Analysis.Param_Spec;
      Name        : String;
      Initial     : Boolean;
      Bad_Return  : in out Boolean) return Init_Result
   is
      Result : Init_Result :=
        (Can_Fall_Through => True, Initialized => Initial);
   begin
      for I in 1 .. List.Children_Count loop
         exit when not Result.Can_Fall_Through;
         Result := Interpret_Initialization
           (List.Child (I), Param, Name, Result.Initialized, Bad_Return);
      end loop;
      return Result;
   end Interpret_List;

   function Interpret_Initialization
     (Node        : Libadalang.Analysis.Ada_Node'Class;
      Param       : Libadalang.Analysis.Param_Spec;
      Name        : String;
      Initial     : Boolean;
      Bad_Return  : in out Boolean) return Init_Result
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return (True, Initial);
      elsif Statement_Writes_Parameter (Node, Param, Name) then
         return (True, True);
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt =>
            Bad_Return := Bad_Return or else not Initial;
            return (False, Initial);

         when Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            return (False, Initial);

         when Libadalang.Common.Ada_If_Stmt =>
            declare
               Stmt   : constant Libadalang.Analysis.If_Stmt :=
                 Node.As_If_Stmt;
               Result : Init_Result := Interpret_List
                 (Stmt.F_Then_Stmts, Param, Name, Initial, Bad_Return);
            begin
               for Alt of Stmt.F_Alternatives loop
                  Result := Merge
                    (Result,
                     Interpret_List
                       (Alt.F_Stmts, Param, Name, Initial, Bad_Return));
               end loop;
               if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
                  Result := Merge (Result, (True, Initial));
               else
                  Result := Merge
                    (Result,
                     Interpret_List
                       (Stmt.F_Else_Part.F_Stmts, Param, Name, Initial,
                        Bad_Return));
               end if;
               return Result;
            end;

         when Libadalang.Common.Ada_Case_Stmt =>
            declare
               First  : Boolean := True;
               Result : Init_Result := (False, Initial);
            begin
               for Alt of Node.As_Case_Stmt.F_Alternatives loop
                  declare
                     Branch : constant Init_Result := Interpret_List
                       (Alt.F_Stmts, Param, Name, Initial, Bad_Return);
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
            return Interpret_List
              (Node.As_Decl_Block.F_Stmts.F_Stmts, Param, Name, Initial,
               Bad_Return);

         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            --  Inspect returns inside the body, but do not assume that a loop
            --  initializes an output: even a plain loop can leave through an
            --  exit before the assignment.
            declare
               Ignored : constant Init_Result := Interpret_List
                 (Node.As_Base_Loop_Stmt.F_Stmts, Param, Name, Initial,
                  Bad_Return);
               pragma Unreferenced (Ignored);
            begin
               return (True, Initial);
            end;

         when others =>
            return (True, Initial);
      end case;
   end Interpret_Initialization;

   procedure Collect_Depends_Outputs
     (Expr    : Libadalang.Analysis.Expr;
      Outputs : in out Access_Vectors.Vector)
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate
      then
         return;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            for Designator of Item.As_Aggregate_Assoc.F_Designators loop
               if Designator.Kind = Libadalang.Common.Ada_Identifier then
                  declare
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node
                         (Designator.As_Name.P_Referenced_Defining_Name);
                  begin
                     if not Libadalang.Analysis.Is_Null (Key) then
                        Include
                          (Outputs, Key, Node_Text (Designator), Designator,
                           Is_Read => False, Is_Written => True);
                     end if;
                  exception
                     when others =>
                        null;
                  end;
               end if;
            end loop;
         end if;
      end loop;
   end Collect_Depends_Outputs;

   --  True when Subprogram is declared directly in a protected body's
   --  declarative part, i.e. it is itself a protected operation. Stops at
   --  the first enclosing body of any kind, so a subprogram nested inside
   --  another subprogram that happens to live in a protected body is not
   --  treated as a protected operation itself -- the same conservative,
   --  direct-syntax-only scoping used elsewhere in this analyzer (compare
   --  No_Recursion, which only recognizes an explicit call syntax).
   function Is_Protected_Operation_Body
     (Subprogram : Libadalang.Analysis.Subp_Body) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Subprogram).Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         case Current.Kind is
            when Libadalang.Common.Ada_Protected_Body =>
               return True;
            when Libadalang.Common.Ada_Subp_Body
               | Libadalang.Common.Ada_Package_Body
               | Libadalang.Common.Ada_Task_Body =>
               return False;
            when others =>
               Current := Current.Parent;
         end case;
      end loop;
      return False;
   end Is_Protected_Operation_Body;

   --  True when Node's name resolves to an entry declaration, i.e. Node
   --  denotes an entry call.
   function Is_Entry_Call (Node : Libadalang.Analysis.Name'Class)
     return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Node.P_Referenced_Decl (Imprecise_Fallback => True);
   begin
      return not Libadalang.Analysis.Is_Null (Decl)
        and then Decl.Kind = Libadalang.Common.Ada_Entry_Decl;
   exception
      when others =>
         return False;
   end Is_Entry_Call;

   --  Reports Potentially_Blocking_Operation for every delay statement or
   --  entry call directly under Node, not descending into a nested
   --  subprogram body (its own blocking constructs, if any, are only
   --  reachable through a call this analyzer does not trace -- the same
   --  intraprocedural limit documented for the rest of this package).
   procedure Scan_For_Blocking_Operations
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Subp_Body =>
            return;

         when Libadalang.Common.Ada_Delay_Stmt =>
            Report_Rule_Violation
              (Unit, Node, Potentially_Blocking_Operation,
               "delay statement used inside a protected operation");
            return;

         when Libadalang.Common.Ada_Call_Expr =>
            if Is_Entry_Call (Node.As_Call_Expr.F_Name) then
               Report_Rule_Violation
                 (Unit, Node, Potentially_Blocking_Operation,
                  "entry call used inside a protected operation");
            end if;

         when Libadalang.Common.Ada_Call_Stmt =>
            if Is_Entry_Call (Node.As_Call_Stmt.F_Call) then
               Report_Rule_Violation
                 (Unit, Node, Potentially_Blocking_Operation,
                  "entry call used inside a protected operation");
            end if;

         when others =>
            null;
      end case;

      for I in 1 .. Node.Children_Count loop
         Scan_For_Blocking_Operations (Unit, Node.Child (I));
      end loop;
   end Scan_For_Blocking_Operations;

   procedure Check_Potentially_Blocking
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
   begin
      if Is_Protected_Operation_Body (Subprogram) then
         Scan_For_Blocking_Operations (Unit, Subprogram.F_Stmts);
      end if;
   exception
      when others =>
         null;
   end Check_Potentially_Blocking;

   --  True when Field is declared as a component directly in List (the
   --  fixed part, or one variant's own component list). Does not descend
   --  into a nested variant part inside List -- this check only models one
   --  level of variant nesting.
   function Component_Declared_In
     (List  : Libadalang.Analysis.Component_List;
      Field : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (List) then
         return False;
      end if;
      for Item of List.F_Components loop
         if Item.Kind = Libadalang.Common.Ada_Component_Decl then
            for Id of Item.As_Component_Decl.F_Ids loop
               if Normalize_Rule_Name (Node_Text (Id)) = Field then
                  return True;
               end if;
            end loop;
         end if;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Component_Declared_In;

   --  The variant in Part whose own component list declares Field, or
   --  No_Variant when Field belongs to the fixed part or cannot be found.
   function Owning_Variant
     (Part  : Libadalang.Analysis.Variant_Part;
      Field : String) return Libadalang.Analysis.Variant
   is
   begin
      for V of Part.F_Variant loop
         if Component_Declared_In (V.F_Components, Field) then
            return Libadalang.Analysis.Variant (V);
         end if;
      end loop;
      return Libadalang.Analysis.No_Variant;
   exception
      when others =>
         return Libadalang.Analysis.No_Variant;
   end Owning_Variant;

   --  True when Choice provably matches a known discriminant value: an
   --  integer choice/range containing Value_Int, or an identifier choice
   --  (enumeration literal) spelled exactly like Value_Text.
   function Choice_Matches_Known_Value
     (Choice     : Libadalang.Analysis.Ada_Node'Class;
      Value_Text : String;
      Value_Int  : Abstract_Int) return Boolean
   is
   begin
      if Value_Int.Known then
         declare
            Interval : constant Static_Interval := Choice_Interval (Choice);
         begin
            return Interval.Known
              and then Value_Int.Value >= Interval.Low
              and then Value_Int.Value <= Interval.High;
         end;
      end if;
      return Value_Text /= "" and then Canonical_Text (Choice) = Value_Text;
   end Choice_Matches_Known_Value;

   --  The variant Part selects for a known discriminant value, or No_Variant
   --  when no alternative can be proven to match. A non-"others" match
   --  always wins; "others" is only used as a fallback when no sibling
   --  alternative matches, mirroring how a case statement resolves choices.
   function Selected_Variant
     (Part       : Libadalang.Analysis.Variant_Part;
      Value_Text : String;
      Value_Int  : Abstract_Int) return Libadalang.Analysis.Variant
   is
      Fallback : Libadalang.Analysis.Variant := Libadalang.Analysis.No_Variant;
   begin
      for V of Part.F_Variant loop
         for Choice of V.F_Choices loop
            if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
               Fallback := Libadalang.Analysis.Variant (V);
            elsif Choice_Matches_Known_Value (Choice, Value_Text, Value_Int)
            then
               return Libadalang.Analysis.Variant (V);
            end if;
         end loop;
      end loop;
      return Fallback;
   exception
      when others =>
         return Libadalang.Analysis.No_Variant;
   end Selected_Variant;

   procedure Check_Discriminant_Access  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Dotted_Name'Class)
   is
      Suffix : constant Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Node.F_Suffix);
      Prefix : constant Libadalang.Analysis.Expr :=
        Libadalang.Analysis.Expr (Node.F_Prefix);
   begin
      if Libadalang.Analysis.Is_Null (Suffix)
        or else Suffix.Kind /= Libadalang.Common.Ada_Identifier
        or else Libadalang.Analysis.Is_Null (Prefix)
        or else Prefix.Kind /= Libadalang.Common.Ada_Identifier
      then
         return;
      end if;

      declare
         Field_Name     : constant String :=
           Normalize_Rule_Name (Node_Text (Suffix));
         Prefix_Type    : constant Libadalang.Analysis.Base_Type_Decl :=
           Prefix.P_Expression_Type;
         Part           : Libadalang.Analysis.Variant_Part :=
           Libadalang.Analysis.No_Variant_Part;
         Actual_Variant : Libadalang.Analysis.Variant :=
           Libadalang.Analysis.No_Variant;
         Decl           : Libadalang.Analysis.Basic_Decl;
         Constraint     : Libadalang.Analysis.Constraint :=
           Libadalang.Analysis.No_Constraint;
         Value          : Libadalang.Analysis.Expr :=
           Libadalang.Analysis.No_Expr;
      begin
         if Libadalang.Analysis.Is_Null (Prefix_Type)
           or else Prefix_Type.Kind not in Libadalang.Common.Ada_Type_Decl
           or else Prefix_Type.As_Type_Decl.F_Type_Def.Kind /=
             Libadalang.Common.Ada_Record_Type_Def
           or else Prefix_Type.As_Type_Decl.F_Type_Def.As_Record_Type_Def
             .F_Record_Def.Kind /= Libadalang.Common.Ada_Record_Def
         then
            return;
         end if;

         declare
            Components : constant Libadalang.Analysis.Component_List :=
              Prefix_Type.As_Type_Decl.F_Type_Def.As_Record_Type_Def
                .F_Record_Def.As_Record_Def.F_Components;
         begin
            if Libadalang.Analysis.Is_Null (Components) then
               return;
            end if;
            Part := Components.F_Variant_Part;
         end;

         if Libadalang.Analysis.Is_Null (Part) then
            return;
         end if;

         Actual_Variant := Owning_Variant (Part, Field_Name);
         if Libadalang.Analysis.Is_Null (Actual_Variant) then
            --  The fixed part or an unresolved shape: nothing provably
            --  wrong.
            return;
         end if;

         Decl :=
           Prefix.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
         if Libadalang.Analysis.Is_Null (Decl)
           or else Decl.Kind /= Libadalang.Common.Ada_Object_Decl
           or else Libadalang.Analysis.Is_Null
             (Decl.As_Object_Decl.F_Type_Expr)
           or else Decl.As_Object_Decl.F_Type_Expr.Kind /=
             Libadalang.Common.Ada_Subtype_Indication
         then
            return;
         end if;

         Constraint :=
           Decl.As_Object_Decl.F_Type_Expr.As_Subtype_Indication
             .F_Constraint;
         if Libadalang.Analysis.Is_Null (Constraint)
           or else Constraint.Kind /=
             Libadalang.Common.Ada_Composite_Constraint
           or else not Constraint.As_Composite_Constraint
             .P_Is_Discriminant_Constraint
         then
            return;
         end if;

         declare
            Discr_Text : constant String :=
              Normalize_Rule_Name (Node_Text (Part.F_Discr_Name));
         begin
            for Pair of
              Constraint.As_Composite_Constraint.P_Discriminant_Params
            loop
               if Normalize_Rule_Name
                    (Node_Text (Libadalang.Analysis.Param (Pair))) =
                  Discr_Text
               then
                  Value := Libadalang.Analysis.Expr
                    (Libadalang.Analysis.Actual (Pair));
                  exit;  --  adalang-analyzer: ignore No_Exit
               end if;
            end loop;
         end;

         if Libadalang.Analysis.Is_Null (Value) then
            return;
         end if;

         declare
            Value_Int  : constant Abstract_Int := Integer_Value (Value);
            Value_Text : constant String :=
              (if Value.Kind = Libadalang.Common.Ada_Identifier
               then Canonical_Text (Value)
               else "");
            Selected   : constant Libadalang.Analysis.Variant :=
              Selected_Variant (Part, Value_Text, Value_Int);
         begin
            if not Libadalang.Analysis.Is_Null (Selected)
              and then Libadalang.Analysis.Ada_Node (Selected) /=
                Libadalang.Analysis.Ada_Node (Actual_Variant)
            then
               Report_Rule_Violation
                 (Unit, Node, Known_Discriminant_Check_Failure,
                  "component '" & Node_Text (Suffix) &
                    "' belongs to a variant excluded by the object's " &
                    "discriminant constraint");
            end if;
         end;
      end;
   exception
      when others =>
         null;
   end Check_Discriminant_Access;

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Needs_Analysis : constant Boolean :=
        Rule_States (Missing_Global_Contract) = Enabled
        or else Rule_States (Global_Contract_Mismatch) = Enabled
        or else Rule_States (Missing_Depends_Contract) = Enabled
        or else Rule_States (Incomplete_Depends_Contract) = Enabled
        or else Rule_States (Uninitialized_Output) = Enabled
        or else Rule_States (Aliasing_Between_Parameters) = Enabled
        or else Rule_States (Potentially_Blocking_Operation) = Enabled;
      Actual_Global   : Access_Vectors.Vector;
      Declared_Global : Access_Vectors.Vector;
      Outputs         : Access_Vectors.Vector;
      Depends_Outputs : Access_Vectors.Vector;
      Global          : Libadalang.Analysis.Expr;
      Depends         : Libadalang.Analysis.Expr;
      Name_Node       : constant Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Subprogram.F_Subp_Spec.P_Name);
   begin
      if not Needs_Analysis or else not Effective_SPARK_Enabled (Subprogram)
      then
         return;
      end if;

      Global := Contract_Expression (Subprogram, "Global");
      Depends := Contract_Expression (Subprogram, "Depends");
      Collect_Accesses (Unit, Subprogram.F_Stmts, Subprogram, Actual_Global);

      if Rule_States (Potentially_Blocking_Operation) = Enabled then
         Check_Potentially_Blocking (Unit, Subprogram);
      end if;
      Parse_Global (Global, Subprogram, Name_Node, Declared_Global);

      if Rule_States (Missing_Global_Contract) = Enabled
        and then Actual_Global.Length > 0
        and then Libadalang.Analysis.Is_Null (Global)
      then
         Report_Rule_Violation
           (Unit, Name_Node, Missing_Global_Contract,
            "subprogram accesses global state but has no Global contract");
      end if;

      if Rule_States (Global_Contract_Mismatch) = Enabled
        and then not Libadalang.Analysis.Is_Null (Global)
      then
         for Actual of Actual_Global loop
            declare
               Index : constant Natural := Find (Declared_Global, Actual.Key);
               Missing_Read, Missing_Write : Boolean := False;
            begin
               if Index = 0 then
                  Missing_Read := Actual.Is_Read;
                  Missing_Write := Actual.Is_Written;
               else
                  Missing_Read := Actual.Is_Read
                    and then not Declared_Global (Index).Is_Read;
                  Missing_Write := Actual.Is_Written
                    and then not Declared_Global (Index).Is_Written;
               end if;

               if Missing_Read or else Missing_Write then
                  Report_Rule_Violation
                    (Unit, Actual.Site, Global_Contract_Mismatch,
                     "global '" & To_String (Actual.Name) & "' is " &
                       (if Missing_Read and then Missing_Write then
                           "read and written"
                        elsif Missing_Write then "written"
                        else "read") &
                       " but its Global contract mode does not allow it");
               end if;
            end;
         end loop;
      end if;

      --  Every out/in out formal is an output for Depends. In out values are
      --  already initialized on entry, so only mode out participates in the
      --  definite-initialization check below.
      for Param of Subprogram.F_Subp_Spec.P_Params loop
         if Param.F_Mode.Kind in Libadalang.Common.Ada_Mode_Out
           | Libadalang.Common.Ada_Mode_In_Out
         then
            for Id of Param.F_Ids loop
               Include
                 (Outputs, Libadalang.Analysis.Ada_Node (Id),
                  Node_Text (Id), Id, Is_Read => False, Is_Written => True);

               if Rule_States (Uninitialized_Output) = Enabled
                 and then Param.F_Mode.Kind = Libadalang.Common.Ada_Mode_Out
               then
                  declare
                     Bad_Return : Boolean := False;
                     Result : constant Init_Result := Interpret_List
                       (Subprogram.F_Stmts.F_Stmts, Param,
                        Normalize_Rule_Name (Node_Text (Id)), False,
                        Bad_Return);
                  begin
                     if Subprogram.F_Stmts.F_Exceptions.Children_Count > 0 then
                        for Handler of Subprogram.F_Stmts.F_Exceptions loop
                           declare
                              Handler_Result : constant Init_Result :=
                                Interpret_List
                                  (Handler.As_Exception_Handler.F_Stmts, Param,
                                   Normalize_Rule_Name (Node_Text (Id)),
                                   False, Bad_Return);
                           begin
                              if Handler_Result.Can_Fall_Through
                                and then not Handler_Result.Initialized
                              then
                                 Bad_Return := True;
                              end if;
                           end;
                        end loop;
                     end if;

                     if Bad_Return
                       or else
                         (Result.Can_Fall_Through
                          and then not Result.Initialized)
                     then
                        Report_Rule_Violation
                          (Unit, Id, Uninitialized_Output,
                           "out parameter '" & Node_Text (Id) &
                             "' is not initialized on every normal return " &
                             "path");
                     end if;
                  end;
               end if;
            end loop;
         end if;
      end loop;

      for Item of Declared_Global loop
         if Item.Is_Written then
            Include
              (Outputs, Item.Key, To_String (Item.Name), Item.Site,
               Is_Read => False, Is_Written => True);
         end if;
      end loop;

      if Rule_States (Missing_Depends_Contract) = Enabled
        and then Outputs.Length > 0
        and then Libadalang.Analysis.Is_Null (Depends)
      then
         Report_Rule_Violation
           (Unit, Name_Node, Missing_Depends_Contract,
            "subprogram has outputs but no Depends contract");
      elsif Rule_States (Incomplete_Depends_Contract) = Enabled
        and then not Libadalang.Analysis.Is_Null (Depends)
      then
         Collect_Depends_Outputs (Depends, Depends_Outputs);
         for Output of Outputs loop
            if Find (Depends_Outputs, Output.Key) = 0 then
               Report_Rule_Violation
                 (Unit, Output.Site, Incomplete_Depends_Contract,
                  "output '" & To_String (Output.Name) &
                    "' has no association in the Depends contract");
            end if;
         end loop;
      end if;
   exception
      when others =>
         --  Readiness checks are deliberately best effort: incomplete name
         --  resolution must not prevent the ordinary analyzer from running.
         null;
   end Analyze_Subprogram;

end Adalang_Analyzer.SPARK_Readiness;
