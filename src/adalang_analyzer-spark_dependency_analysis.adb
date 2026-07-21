--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;   use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;     use Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;     use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.SPARK_Dependency_Analysis is

   use type Ada.Containers.Count_Type;
   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   subtype Key_Type is Libadalang.Analysis.Ada_Node;
   No_Key : Key_Type renames Libadalang.Analysis.No_Ada_Node;

   package Key_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Key_Type);

   type Dependency_Value is record
      Keys    : Key_Vectors.Vector;
      Precise : Boolean := True;
   end record;

   type Binding is record
      Key   : Key_Type := No_Key;
      Name  : Unbounded_String;
      Value : Dependency_Value;
   end record;

   package Binding_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Binding);

   subtype Dependency_State is Binding_Vectors.Vector;

   type Dependency_Association is record
      Output      : Key_Type := No_Key;
      Output_Name : Unbounded_String;
      Inputs      : Key_Vectors.Vector;
      Site        : Libadalang.Analysis.Ada_Node := No_Key;
   end record;

   package Association_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Dependency_Association);

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

   function Referenced_Key
     (Node : Libadalang.Analysis.Ada_Node'Class) return Key_Type
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return No_Key;
      end if;
      Decl := Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind not in Libadalang.Common.Ada_Object_Decl
          | Libadalang.Common.Ada_Param_Spec
      then
         return No_Key;
      end if;
      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return No_Key;
   end Referenced_Key;

   function Key_Name (Key : Key_Type) return String is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return "null";
      else
         return Node_Text (Key);
      end if;
   end Key_Name;

   function Is_Parameter_Key (Key : Key_Type) return Boolean
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

   function Equivalent_Keys (Left, Right : Key_Type) return Boolean is
     (Left = Right
      or else
        (Is_Parameter_Key (Left)
         and then Is_Parameter_Key (Right)
         and then Normalize_Rule_Name (Key_Name (Left)) =
           Normalize_Rule_Name (Key_Name (Right))));

   function Contains
     (Keys : Key_Vectors.Vector; Key : Key_Type) return Boolean
   is
   begin
      for Item of Keys loop
         if Equivalent_Keys (Item, Key) then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   procedure Include (Keys : in out Key_Vectors.Vector; Key : Key_Type) is
   begin
      if not Libadalang.Analysis.Is_Null (Key)
        and then not Contains (Keys, Key)
      then
         Keys.Append (Key);
      end if;
   end Include;

   function Union
     (Left, Right : Dependency_Value) return Dependency_Value
   is
      Result : Dependency_Value := Left;
   begin
      for Key of Right.Keys loop
         Include (Result.Keys, Key);
      end loop;
      Result.Precise := Left.Precise and then Right.Precise;
      return Result;
   end Union;

   function Same_Keys
     (Left, Right : Key_Vectors.Vector) return Boolean is
   begin
      if Left.Length /= Right.Length then
         return False;
      end if;
      for Key of Left loop
         if not Contains (Right, Key) then
            return False;
         end if;
      end loop;
      return True;
   end Same_Keys;

   function Same_Value (Left, Right : Dependency_Value) return Boolean is
     (Left.Precise = Right.Precise
      and then Same_Keys (Left.Keys, Right.Keys));

   function Find
     (State : Dependency_State; Key : Key_Type) return Natural
   is
   begin
      for I in State.First_Index .. State.Last_Index loop
         if Equivalent_Keys (State (I).Key, Key) then
            return I;
         end if;
      end loop;
      return 0;
   exception
      when Constraint_Error =>
         return 0;
   end Find;

   function Lookup
     (State : Dependency_State; Key : Key_Type) return Dependency_Value
   is
      Index : constant Natural := Find (State, Key);
   begin
      if Index = 0 then
         return (Keys => <>, Precise => False);
      else
         return State (Index).Value;
      end if;
   end Lookup;

   procedure Set_Value
     (State : in out Dependency_State;
      Key   : Key_Type;
      Name  : String;
      Value : Dependency_Value)
   is
      Index : constant Natural := Find (State, Key);
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      elsif Index = 0 then
         State.Append
           ((Key => Key, Name => To_Unbounded_String (Name), Value => Value));
      else
         State (Index).Value := Value;
      end if;
   end Set_Value;

   function Join
     (Left, Right : Dependency_State) return Dependency_State
   is
      Result : Dependency_State := Left;
   begin
      for Item of Right loop
         declare
            Index : constant Natural := Find (Result, Item.Key);
         begin
            if Index = 0 then
               Result.Append
                 ((Key   => Item.Key,
                   Name  => Item.Name,
                   Value =>
                     (Keys => Item.Value.Keys, Precise => False)));
            else
               Result (Index).Value :=
                 Union (Result (Index).Value, Item.Value);
            end if;
         end;
      end loop;
      return Result;
   end Join;

   function Same_State
     (Left, Right : Dependency_State) return Boolean
   is
   begin
      if Left.Length /= Right.Length then
         return False;
      end if;
      for Item of Left loop
         declare
            Index : constant Natural := Find (Right, Item.Key);
         begin
            if Index = 0
              or else not Same_Value (Item.Value, Right (Index).Value)
            then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Same_State;

   procedure Mark_Imprecise (State : in out Dependency_State) is
   begin
      for Item of State loop
         Item.Value.Precise := False;
      end loop;
   end Mark_Imprecise;

   procedure Add_Key_References
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Keys : in out Key_Vectors.Vector)
   is
      Key : Key_Type;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier then
         Key := Referenced_Key (Node);
         Include (Keys, Key);
         return;
      end if;
      for I in 1 .. Node.Children_Count loop
         Add_Key_References (Node.Child (I), Keys);
      end loop;
   end Add_Key_References;

   procedure Parse_Global
     (Expr     : Libadalang.Analysis.Expr;
      Inputs   : in out Key_Vectors.Vector;
      Outputs  : in out Key_Vectors.Vector;
      Proof_In : in out Key_Vectors.Vector)
   is
      procedure Add_Association
        (Node : Libadalang.Analysis.Ada_Node'Class;
         Readable, Writable, Is_Proof : Boolean)
      is
         Keys : Key_Vectors.Vector;
      begin
         Add_Key_References (Node, Keys);
         for Key of Keys loop
            if Readable then
               Include (Inputs, Key);
            end if;
            if Writable then
               Include (Outputs, Key);
            end if;
            if Is_Proof then
               Include (Proof_In, Key);
            end if;
         end loop;
      end Add_Association;
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind = Libadalang.Common.Ada_Null_Literal
      then
         return;
      elsif Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate then
         Add_Association (Expr, True, False, False);
         return;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            declare
               Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                 Item.As_Aggregate_Assoc;
               Mode : constant String :=
                 (if Assoc.F_Designators.Children_Count = 0 then "input"
                  else Normalize_Rule_Name
                    (Node_Text (Assoc.F_Designators.Child (1))));
            begin
               Add_Association
                 (Assoc.F_R_Expr,
                  Readable => Mode = "input" or else Mode = "in-out"
                    or else Mode = "proof-in",
                  Writable => Mode = "output" or else Mode = "in-out",
                  Is_Proof => Mode = "proof-in");
            end;
         end if;
      end loop;
   end Parse_Global;

   procedure Parse_Depends
     (Expr         : Libadalang.Analysis.Expr;
      Associations : in out Association_Vectors.Vector)
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind = Libadalang.Common.Ada_Null_Literal
        or else Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate
      then
         return;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            declare
               Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                 Item.As_Aggregate_Assoc;
               Inputs : Key_Vectors.Vector;
               Has_Plus : constant Boolean :=
                 Ada.Strings.Fixed.Index (Node_Text (Assoc), "=>+") /= 0
                 or else Ada.Strings.Fixed.Index
                   (Node_Text (Assoc), "=> +") /= 0;
            begin
               Add_Key_References (Assoc.F_R_Expr, Inputs);
               for Designator of Assoc.F_Designators loop
                  declare
                     Output : constant Key_Type :=
                       Referenced_Key (Designator);
                     Actual_Inputs : Key_Vectors.Vector := Inputs;
                  begin
                     if Has_Plus then
                        Include (Actual_Inputs, Output);
                     end if;
                     Associations.Append
                       ((Output      => Output,
                         Output_Name => To_Unbounded_String
                           (if Libadalang.Analysis.Is_Null (Output) then
                               "null"
                            else Node_Text (Designator)),
                         Inputs      => Actual_Inputs,
                         Site        =>
                           Libadalang.Analysis.Ada_Node (Designator)));
                  end;
               end loop;
            end;
         end if;
      end loop;
   end Parse_Depends;

   function Call_Declaration
     (Call : Libadalang.Analysis.Name'Class)
      return Libadalang.Analysis.Basic_Decl
   is
   begin
      if Call.Kind = Libadalang.Common.Ada_Call_Expr then
         return Call.As_Call_Expr.F_Name.P_Referenced_Decl;
      else
         return Call.P_Referenced_Decl;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Call_Declaration;

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

   function Expression_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Dependency_State) return Dependency_Value;

   function Translate_Input
     (Key   : Key_Type;
      Call  : Libadalang.Analysis.Name'Class;
      State : Dependency_State) return Dependency_Value
   is
   begin
      for Pair of Call.P_Call_Params loop
         if Equivalent_Keys
           (Libadalang.Analysis.Ada_Node (Libadalang.Analysis.Param (Pair)),
            Key)
         then
            return Expression_Value
              (Libadalang.Analysis.Actual (Pair), State);
         end if;
      end loop;
      return Lookup (State, Key);
   exception
      when others =>
         return (Keys => <>, Precise => False);
   end Translate_Input;

   function Function_Call_Value
     (Call  : Libadalang.Analysis.Name'Class;
      State : Dependency_State) return Dependency_Value
   is
      Result : Dependency_Value;
      Decl   : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      for Pair of Call.P_Call_Params loop
         Result := Union
           (Result,
            Expression_Value (Libadalang.Analysis.Actual (Pair), State));
      end loop;
      if not Libadalang.Analysis.Is_Null (Decl) then
         declare
            Inputs, Outputs, Proof : Key_Vectors.Vector;
            Global : constant Libadalang.Analysis.Expr :=
              Contract_Expression (Decl, "Global");
         begin
            Parse_Global (Global, Inputs, Outputs, Proof);
            for Key of Inputs loop
               Result := Union (Result, Lookup (State, Key));
            end loop;
            if Libadalang.Analysis.Is_Null
              (Contract_Expression (Decl, "Depends"))
            then
               Result.Precise := False;
            end if;
         end;
      else
         Result.Precise := False;
      end if;
      return Result;
   exception
      when others =>
         return (Keys => Result.Keys, Precise => False);
   end Function_Call_Value;

   function Expression_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Dependency_State) return Dependency_Value
   is
      Result : Dependency_Value;
      Key    : Key_Type;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Result;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier then
         Key := Referenced_Key (Node);
         if Libadalang.Analysis.Is_Null (Key) then
            return Result;
         elsif Find (State, Key) = 0 then
            Include (Result.Keys, Key);
            Result.Precise := False;
            return Result;
         else
            return Lookup (State, Key);
         end if;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
         return Function_Call_Value (Node.As_Call_Expr.F_Name, State);
      elsif Node.Kind = Libadalang.Common.Ada_Subp_Body then
         return (Keys => <>, Precise => False);
      end if;

      for I in 1 .. Node.Children_Count loop
         Result := Union
           (Result, Expression_Value (Node.Child (I), State));
      end loop;
      return Result;
   exception
      when others =>
         return (Keys => Result.Keys, Precise => False);
   end Expression_Value;

   function Exit_Control_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Dependency_State) return Dependency_Value
   is
      Result : Dependency_Value;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind = Libadalang.Common.Ada_Subp_Body
      then
         return Result;
      elsif Node.Kind = Libadalang.Common.Ada_Exit_Stmt then
         return Expression_Value (Node.As_Exit_Stmt.F_Cond_Expr, State);
      end if;
      for I in 1 .. Node.Children_Count loop
         Result := Union
           (Result, Exit_Control_Value (Node.Child (I), State));
      end loop;
      return Result;
   end Exit_Control_Value;

   function Actual_Target_Key
     (Node : Libadalang.Analysis.Ada_Node'Class) return Key_Type is
   begin
      if not Libadalang.Analysis.Is_Null (Node)
        and then Node.Kind = Libadalang.Common.Ada_Identifier
      then
         return Referenced_Key (Node);
      end if;
      return No_Key;
   end Actual_Target_Key;

   procedure Apply_Call
     (Call    : Libadalang.Analysis.Name'Class;
      Control : Dependency_Value;
      State   : in out Dependency_State)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
      All_Inputs : Dependency_Value;
      Applied_Outputs : Key_Vectors.Vector;
      Global_Inputs, Global_Outputs, Proof : Key_Vectors.Vector;
      Associations : Association_Vectors.Vector;

      function Output_Target (Key : Key_Type) return Key_Type is
      begin
         for Pair of Call.P_Call_Params loop
            if Equivalent_Keys
              (Libadalang.Analysis.Ada_Node
                 (Libadalang.Analysis.Param (Pair)),
               Key)
            then
               return Actual_Target_Key (Libadalang.Analysis.Actual (Pair));
            end if;
         end loop;
         return Key;
      exception
         when others =>
            return No_Key;
      end Output_Target;
   begin
      for Pair of Call.P_Call_Params loop
         if Formal_Mode (Libadalang.Analysis.Param (Pair)) /=
           Libadalang.Common.Ada_Mode_Out
         then
            All_Inputs := Union
              (All_Inputs,
               Expression_Value (Libadalang.Analysis.Actual (Pair), State));
         end if;
      end loop;

      if not Libadalang.Analysis.Is_Null (Decl) then
         Parse_Global
           (Contract_Expression (Decl, "Global"), Global_Inputs,
            Global_Outputs, Proof);
         for Key of Global_Inputs loop
            All_Inputs := Union (All_Inputs, Lookup (State, Key));
         end loop;
         Parse_Depends
           (Contract_Expression (Decl, "Depends"), Associations);
      end if;

      for Assoc of Associations loop
         if not Libadalang.Analysis.Is_Null (Assoc.Output) then
            declare
               Target : constant Key_Type := Output_Target (Assoc.Output);
               Value  : Dependency_Value := Control;
            begin
               for Input of Assoc.Inputs loop
                  Value := Union
                    (Value, Translate_Input (Input, Call, State));
               end loop;
               if Libadalang.Analysis.Is_Null (Target) then
                  Mark_Imprecise (State);
               else
                  Set_Value (State, Target, Key_Name (Target), Value);
                  Include (Applied_Outputs, Target);
               end if;
            end;
         end if;
      end loop;

      --  Missing summaries or incomplete output associations fall back to
      --  the SPARK default: every output may depend on every input.
      All_Inputs := Union (All_Inputs, Control);
      All_Inputs.Precise := False;
      for Pair of Call.P_Call_Params loop
         if Formal_Mode (Libadalang.Analysis.Param (Pair)) in
           Libadalang.Common.Ada_Mode_Out | Libadalang.Common.Ada_Mode_In_Out
         then
            declare
               Target : constant Key_Type :=
                 Actual_Target_Key (Libadalang.Analysis.Actual (Pair));
            begin
               if not Contains (Applied_Outputs, Target) then
                  if Libadalang.Analysis.Is_Null (Target) then
                     Mark_Imprecise (State);
                  else
                     Set_Value
                       (State, Target, Key_Name (Target), All_Inputs);
                  end if;
               end if;
            end;
         end if;
      end loop;
      for Target of Global_Outputs loop
         if not Contains (Applied_Outputs, Target) then
            Set_Value (State, Target, Key_Name (Target), All_Inputs);
         end if;
      end loop;
   exception
      when others =>
         null;
   end Apply_Call;

   type Flow_Result is record
      State : Dependency_State;
      Falls_Through : Boolean := True;
   end record;

   type Exit_Accumulator is record
      State : Dependency_State;
      Has_Exit : Boolean := False;
   end record;

   procedure Add_Exit
     (Exits : in out Exit_Accumulator; State : Dependency_State) is
   begin
      if Exits.Has_Exit then
         Exits.State := Join (Exits.State, State);
      else
         Exits.State := State;
         Exits.Has_Exit := True;
      end if;
   end Add_Exit;

   function Interpret_List
     (List    : Libadalang.Analysis.Ada_Node'Class;
      Initial : Dependency_State;
      Control : Dependency_Value;
      Exits   : in out Exit_Accumulator) return Flow_Result;

   function Interpret_Statement
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Initial : Dependency_State;
      Control : Dependency_Value;
      Exits   : in out Exit_Accumulator) return Flow_Result
   is
      State : Dependency_State := Initial;
   begin
      case Node.Kind is
         when Libadalang.Common.Ada_Assign_Stmt =>
            declare
               Target : constant Key_Type :=
                 Actual_Target_Key (Node.As_Assign_Stmt.F_Dest);
               Value : constant Dependency_Value := Union
                 (Expression_Value (Node.As_Assign_Stmt.F_Expr, Initial),
                  Control);
            begin
               if Libadalang.Analysis.Is_Null (Target) then
                  Mark_Imprecise (State);
               else
                  Set_Value (State, Target, Key_Name (Target), Value);
               end if;
            end;

         when Libadalang.Common.Ada_Call_Stmt =>
            Apply_Call (Node.As_Call_Stmt.F_Call, Control, State);

         when Libadalang.Common.Ada_If_Stmt =>
            declare
               Stmt : constant Libadalang.Analysis.If_Stmt := Node.As_If_Stmt;
               Branch_Control : Dependency_Value :=
                 Union (Control, Expression_Value (Stmt.F_Cond_Expr, Initial));
               Result : Flow_Result;
            begin
               --  Every branch is control-dependent on reaching its place in
               --  the complete if/elsif chain, including the false outcomes
               --  of all preceding conditions.
               for Alt of Stmt.F_Alternatives loop
                  Branch_Control := Union
                    (Branch_Control,
                     Expression_Value (Alt.F_Cond_Expr, Initial));
               end loop;
               Result := Interpret_List
                 (Stmt.F_Then_Stmts, Initial, Branch_Control, Exits);
               for Alt of Stmt.F_Alternatives loop
                  declare
                     Branch : constant Flow_Result := Interpret_List
                       (Alt.F_Stmts, Initial, Branch_Control, Exits);
                  begin
                     if Result.Falls_Through and then Branch.Falls_Through then
                        Result.State := Join (Result.State, Branch.State);
                     elsif Branch.Falls_Through then
                        Result := Branch;
                     end if;
                     Result.Falls_Through := Result.Falls_Through
                       or else Branch.Falls_Through;
                  end;
               end loop;
               if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
                  if Result.Falls_Through then
                     Result.State := Join (Result.State, Initial);
                  else
                     Result := (State => Initial, Falls_Through => True);
                  end if;
               else
                  declare
                     Branch : constant Flow_Result := Interpret_List
                       (Stmt.F_Else_Part.F_Stmts, Initial, Branch_Control,
                        Exits);
                  begin
                     if Result.Falls_Through and then Branch.Falls_Through then
                        Result.State := Join (Result.State, Branch.State);
                     elsif Branch.Falls_Through then
                        Result := Branch;
                     end if;
                     Result.Falls_Through := Result.Falls_Through
                       or else Branch.Falls_Through;
                  end;
               end if;
               return Result;
            end;

         when Libadalang.Common.Ada_Case_Stmt =>
            declare
               Case_Control : constant Dependency_Value := Union
                 (Control,
                  Expression_Value (Node.As_Case_Stmt.F_Expr, Initial));
               Result : Flow_Result;
               First : Boolean := True;
            begin
               for Alt of Node.As_Case_Stmt.F_Alternatives loop
                  declare
                     Branch : constant Flow_Result := Interpret_List
                       (Alt.F_Stmts, Initial, Case_Control, Exits);
                  begin
                     if First then
                        Result := Branch;
                        First := False;
                     elsif Result.Falls_Through
                       and then Branch.Falls_Through
                     then
                        Result.State := Join (Result.State, Branch.State);
                     elsif Branch.Falls_Through then
                        Result := Branch;
                     end if;
                     Result.Falls_Through := Result.Falls_Through
                       or else Branch.Falls_Through;
                  end;
               end loop;
               return Result;
            end;

         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            declare
               Loop_Control : Dependency_Value := Control;
               Current, Next : Dependency_State := Initial;
               Iterations : Natural := 0;
            begin
               Loop_Control := Union
                 (Loop_Control,
                  Exit_Control_Value
                    (Node.As_Base_Loop_Stmt.F_Stmts, Initial));
               if Node.Kind = Libadalang.Common.Ada_While_Loop_Stmt
                 and then not Libadalang.Analysis.Is_Null
                   (Node.As_While_Loop_Stmt.F_Spec)
               then
                  Loop_Control := Union
                    (Loop_Control,
                     Expression_Value
                       (Node.As_While_Loop_Stmt.F_Spec
                          .As_While_Loop_Spec.F_Expr,
                        Initial));
               elsif Node.Kind = Libadalang.Common.Ada_For_Loop_Stmt then
                  declare
                     Spec : constant Libadalang.Analysis.For_Loop_Spec :=
                       Node.As_For_Loop_Stmt.F_Spec.As_For_Loop_Spec;
                     Iter_Value : constant Dependency_Value :=
                       Expression_Value (Spec.F_Iter_Expr, Initial);
                  begin
                     Loop_Control := Union (Loop_Control, Iter_Value);
                     Set_Value
                       (Current,
                        Libadalang.Analysis.Ada_Node (Spec.F_Var_Decl.F_Id),
                        Node_Text (Spec.F_Var_Decl.F_Id), Iter_Value);
                  end;
               end if;
               loop
                  Next := Join
                    (Initial,
                     Interpret_List
                       (Node.As_Base_Loop_Stmt.F_Stmts, Current,
                        Loop_Control, Exits).State);
                  exit when Same_State (Current, Next)
                    or else Iterations > Natural (Current.Length) + 2;
                  Current := Next;
                  Iterations := Iterations + 1;
               end loop;
               return (State => Next, Falls_Through => True);
            end;

         when Libadalang.Common.Ada_Decl_Block =>
            return Interpret_List
              (Node.As_Decl_Block.F_Stmts.F_Stmts, State, Control, Exits);

         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt =>
            Add_Exit (Exits, State);
            return (State => State, Falls_Through => False);

         when Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            return (State => State, Falls_Through => False);

         when Libadalang.Common.Ada_Null_Stmt
            | Libadalang.Common.Ada_Label
            | Libadalang.Common.Ada_Pragma_Node
            | Libadalang.Common.Ada_Exit_Stmt =>
            null;

         when others =>
            Mark_Imprecise (State);
      end case;
      return (State => State, Falls_Through => True);
   exception
      when others =>
         return (State => Initial, Falls_Through => True);
   end Interpret_Statement;

   function Interpret_List
     (List    : Libadalang.Analysis.Ada_Node'Class;
      Initial : Dependency_State;
      Control : Dependency_Value;
      Exits   : in out Exit_Accumulator) return Flow_Result
   is
      Result : Flow_Result :=
        (State => Initial, Falls_Through => True);
   begin
      if Libadalang.Analysis.Is_Null (List) then
         return Result;
      end if;
      for I in 1 .. List.Children_Count loop
         exit when not Result.Falls_Through;
         Result := Interpret_Statement
           (List.Child (I), Result.State, Control, Exits);
      end loop;
      return Result;
   end Interpret_List;

   procedure Seed_Declarations
     (Subprogram : Libadalang.Analysis.Subp_Body;
      State      : in out Dependency_State)
   is
   begin
      for Item of Subprogram.F_Decls.F_Decls loop
         if Item.Kind = Libadalang.Common.Ada_Object_Decl then
            declare
               Decl : constant Libadalang.Analysis.Object_Decl :=
                 Item.As_Object_Decl;
               Value : Dependency_Value;
            begin
               if Libadalang.Analysis.Is_Null (Decl.F_Default_Expr) then
                  Value.Precise := False;
               else
                  Value := Expression_Value (Decl.F_Default_Expr, State);
               end if;
               for Id of Decl.F_Ids loop
                  Set_Value
                    (State, Libadalang.Analysis.Ada_Node (Id), Node_Text (Id),
                     Value);
               end loop;
            end;
         end if;
      end loop;
   end Seed_Declarations;

   function Find_Association
     (Associations : Association_Vectors.Vector;
      Output       : Key_Type) return Natural
   is
   begin
      for I in Associations.First_Index .. Associations.Last_Index loop
         if Equivalent_Keys (Associations (I).Output, Output) then
            return I;
         end if;
      end loop;
      return 0;
   exception
      when Constraint_Error =>
         return 0;
   end Find_Association;

   function Mentioned_Input
     (Associations : Association_Vectors.Vector;
      Input        : Key_Type) return Boolean
   is
   begin
      for Assoc of Associations loop
         if Contains (Assoc.Inputs, Input) then
            return True;
         end if;
      end loop;
      return False;
   end Mentioned_Input;

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Depends : constant Libadalang.Analysis.Expr :=
        Contract_Expression (Subprogram, "Depends");
      Global : constant Libadalang.Analysis.Expr :=
        Contract_Expression (Subprogram, "Global");
      Inputs, Outputs, Proof_In : Key_Vectors.Vector;
      Associations : Association_Vectors.Vector;
      State : Dependency_State;
      Exits : Exit_Accumulator;
      Body_Result : Flow_Result;
      Final_State : Dependency_State;
      Final_Has_State : Boolean := False;
      Empty_Control : Dependency_Value;
   begin
      if Rule_States (Depends_Contract_Mismatch) /= Enabled
        or else Libadalang.Analysis.Is_Null (Depends)
        or else not Effective_SPARK_Enabled (Subprogram)
      then
         return;
      end if;

      for Param of Subprogram.F_Subp_Spec.P_Params loop
         for Id of Param.F_Ids loop
            declare
               Key : constant Key_Type := Libadalang.Analysis.Ada_Node (Id);
               Value : Dependency_Value;
            begin
               if Param.F_Mode.Kind not in Libadalang.Common.Ada_Mode_Out then
                  Include (Inputs, Key);
                  Include (Value.Keys, Key);
               else
                  Value.Precise := False;
               end if;
               if Param.F_Mode.Kind in Libadalang.Common.Ada_Mode_Out
                 | Libadalang.Common.Ada_Mode_In_Out
               then
                  Include (Outputs, Key);
               end if;
               Set_Value (State, Key, Node_Text (Id), Value);
            end;
         end loop;
      end loop;

      Parse_Global (Global, Inputs, Outputs, Proof_In);
      for Key of Inputs loop
         if Find (State, Key) = 0 then
            declare
               Value : Dependency_Value;
            begin
               Include (Value.Keys, Key);
               Set_Value (State, Key, Key_Name (Key), Value);
            end;
         end if;
      end loop;
      for Key of Outputs loop
         if Find (State, Key) = 0 then
            Set_Value
              (State, Key, Key_Name (Key),
               (Keys => <>, Precise => False));
         end if;
      end loop;
      Seed_Declarations (Subprogram, State);
      Parse_Depends (Depends, Associations);

      Body_Result := Interpret_List
        (Subprogram.F_Stmts.F_Stmts, State, Empty_Control, Exits);
      if Body_Result.Falls_Through then
         Final_State := Body_Result.State;
         Final_Has_State := True;
         if Exits.Has_Exit then
            Final_State := Join (Final_State, Exits.State);
         end if;
      elsif Exits.Has_Exit then
         Final_State := Exits.State;
         Final_Has_State := True;
      end if;

      for Handler of Subprogram.F_Stmts.F_Exceptions loop
         declare
            Handler_Exits : Exit_Accumulator;
            Handler_Result : constant Flow_Result := Interpret_List
              (Handler.As_Exception_Handler.F_Stmts, State, Empty_Control,
               Handler_Exits);
         begin
            if Handler_Result.Falls_Through then
               if Final_Has_State then
                  Final_State := Join (Final_State, Handler_Result.State);
               else
                  Final_State := Handler_Result.State;
                  Final_Has_State := True;
               end if;
            end if;
            if Handler_Exits.Has_Exit then
               if Final_Has_State then
                  Final_State := Join (Final_State, Handler_Exits.State);
               else
                  Final_State := Handler_Exits.State;
                  Final_Has_State := True;
               end if;
            end if;
         end;
      end loop;

      if not Final_Has_State then
         return;
      end if;

      for Output of Outputs loop
         declare
            Index : constant Natural := Find_Association
              (Associations, Output);
            Inferred : constant Dependency_Value :=
              Lookup (Final_State, Output);
         begin
            if Index /= 0 then
               for Input of Inferred.Keys loop
                  if Contains (Inputs, Input)
                    and then not Contains (Associations (Index).Inputs, Input)
                  then
                     Report_Rule_Violation
                       (Unit, Associations (Index).Site,
                        Depends_Contract_Mismatch,
                        "output '" & Key_Name (Output) &
                          "' may depend on input '" & Key_Name (Input) &
                          "', which is missing from Depends");
                  end if;
                  if Contains (Proof_In, Input) then
                     Report_Rule_Violation
                       (Unit, Associations (Index).Site,
                        Depends_Contract_Mismatch,
                        "output '" & Key_Name (Output) &
                          "' depends on Proof_In global '" &
                          Key_Name (Input) & "'");
                  end if;
               end loop;

               if Inferred.Precise then
                  for Input of Associations (Index).Inputs loop
                     if Contains (Inputs, Input)
                       and then not Contains (Inferred.Keys, Input)
                     then
                        Report_Rule_Violation
                          (Unit, Associations (Index).Site,
                           Depends_Contract_Mismatch,
                           "input '" & Key_Name (Input) &
                             "' is declared for output '" &
                             Key_Name (Output) &
                             "' but no such flow is inferred");
                     end if;
                  end loop;
               end if;
            end if;
         end;
      end loop;

      --  Depends is complete over inputs as well as outputs. An unused input
      --  is represented by a null => Input association.
      for Input of Inputs loop
         if not Mentioned_Input (Associations, Input) then
            Report_Rule_Violation
              (Unit, Subprogram.F_Subp_Spec.P_Name,
               Depends_Contract_Mismatch,
               "input '" & Key_Name (Input) &
                 "' is missing from the Depends relation");
         end if;
      end loop;

      for Assoc of Associations loop
         for Input of Assoc.Inputs loop
            if not Contains (Inputs, Input) then
               Report_Rule_Violation
                 (Unit, Assoc.Site, Depends_Contract_Mismatch,
                  "'" & Key_Name (Input) &
                    "' is declared as a dependency but is not an input");
            elsif Libadalang.Analysis.Is_Null (Assoc.Output) then
               for Output of Outputs loop
                  if Contains (Lookup (Final_State, Output).Keys, Input) then
                     Report_Rule_Violation
                       (Unit, Assoc.Site, Depends_Contract_Mismatch,
                        "input '" & Key_Name (Input) &
                          "' is listed after null but influences output '" &
                          Key_Name (Output) & "'");
                     exit;
                  end if;
               end loop;
            end if;
         end loop;
      end loop;
   exception
      when others =>
         null;
   end Analyze_Subprogram;

end Adalang_Analyzer.SPARK_Dependency_Analysis;
