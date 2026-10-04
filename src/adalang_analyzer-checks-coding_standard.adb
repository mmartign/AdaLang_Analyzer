--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text; use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Config;   use Adalang_Analyzer.Config;
with Adalang_Analyzer.Rules;    use Adalang_Analyzer.Rules;

package body Adalang_Analyzer.Checks.Coding_Standard is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   --  The innermost loop statement enclosing Node, or a null node.
   function Enclosing_Loop
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Base_Loop_Stmt then
            return Current;
         end if;
         Current := Current.Parent;
      end loop;
      return Libadalang.Analysis.No_Ada_Node;
   end Enclosing_Loop;

   --  True when a loop statement occurs anywhere below Node.
   function Contains_Loop
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      for I in 1 .. Node.Children_Count loop
         declare
            Child : constant Libadalang.Analysis.Ada_Node := Node.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Child)
              and then (Child.Kind in Libadalang.Common.Ada_Base_Loop_Stmt
                        or else Contains_Loop (Child))
            then
               return True;
            end if;
         end;
      end loop;
      return False;
   end Contains_Loop;

   --  True when Node is an identifier that names a type or subtype. A
   --  resolution failure counts as "not a type".
   function Names_A_Type
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Node.Kind /= Libadalang.Common.Ada_Identifier then
         return False;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Node.As_Identifier.P_Referenced_Decl;
      begin
         return not Libadalang.Analysis.Is_Null (Decl)
           and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl;
      end;
   exception
      when others =>
         return False;
   end Names_A_Type;

   --  True when the others choice of association Assoc is reported by
   --  Others_In_Aggregate: the aggregate has more than two associations,
   --  is (or is nested in) an extension aggregate, or its one other
   --  association covers several values (a choice list, a range, or a
   --  subtype name). "(others => X)" and "(A => X, others => Y)" are the
   --  two accepted shapes.
   function Is_Reportable_Aggregate_Others
     (Assoc : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      List    : constant Libadalang.Analysis.Ada_Node := Assoc.Parent;
      Current : Libadalang.Analysis.Ada_Node := List.Parent;
   begin
      if List.Children_Count > 2 then
         return True;
      end if;

      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Aggregate
              | Libadalang.Common.Ada_Bracket_Aggregate
           and then not Libadalang.Analysis.Is_Null
                          (Current.As_Base_Aggregate.F_Ancestor_Expr)
         then
            return True;
         end if;
         Current := Current.Parent;
      end loop;

      for I in 1 .. List.Children_Count loop
         declare
            Other : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if Other.Kind = Libadalang.Common.Ada_Aggregate_Assoc
              and then Other /= Assoc.As_Ada_Node
            then
               declare
                  Choices : constant Libadalang.Analysis.Alternatives_List :=
                    Other.As_Aggregate_Assoc.F_Designators;
               begin
                  if Choices.Children_Count > 1 then
                     return True;
                  elsif Choices.Children_Count = 1 then
                     declare
                        Choice : constant Libadalang.Analysis.Ada_Node :=
                          Choices.Child (1);
                     begin
                        if (Choice.Kind = Libadalang.Common.Ada_Bin_Op
                            and then Choice.As_Bin_Op.F_Op.Kind =
                                       Libadalang.Common.Ada_Op_Double_Dot)
                          or else Names_A_Type (Choice)
                        then
                           return True;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
      return False;
   end Is_Reportable_Aggregate_Others;

   --  The three checks on an others choice, told apart by the construct
   --  the choice list belongs to.
   procedure Analyze_Others_Choice
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Choices : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Owner   : Libadalang.Analysis.Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Choices)
        or else Choices.Kind /= Libadalang.Common.Ada_Alternatives_List
        or else Libadalang.Analysis.Is_Null (Choices.Parent)
      then
         return;
      end if;
      Owner := Choices.Parent;

      if Owner.Kind = Libadalang.Common.Ada_Case_Stmt_Alternative then
         if Rule_States (Others_In_Case_Statement) = Enabled then
            Report_Finding
              (Unit, Node, Others_In_Case_Statement,
               "others choice in case statement");
         end if;
      elsif Owner.Kind = Libadalang.Common.Ada_Exception_Handler then
         if Rule_States (Others_In_Exception_Handler) = Enabled then
            Report_Finding
              (Unit, Node, Others_In_Exception_Handler,
               "others choice in exception handler");
         end if;
      elsif Owner.Kind = Libadalang.Common.Ada_Aggregate_Assoc
        and then Rule_States (Others_In_Aggregate) = Enabled
        and then Is_Reportable_Aggregate_Others (Owner)
      then
         Report_Finding
           (Unit, Node, Others_In_Aggregate, "others choice in aggregate");
      end if;
   end Analyze_Others_Choice;

   --  The five checks on an exit statement.
   procedure Analyze_Exit
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Stmt      : constant Libadalang.Analysis.Exit_Stmt := Node.As_Exit_Stmt;
      Loop_Name : constant Libadalang.Analysis.Name := Stmt.F_Loop_Name;
      Named     : constant Boolean :=
        not Libadalang.Analysis.Is_Null (Loop_Name);
      Target    : constant Libadalang.Analysis.Ada_Node :=
        Enclosing_Loop (Node);
      In_Loop   : constant Boolean :=
        not Libadalang.Analysis.Is_Null (Target);
      Target_Is_Named : constant Boolean :=
        In_Loop
        and then not Libadalang.Analysis.Is_Null
                       (Target.As_Base_Loop_Stmt.F_End_Name);
   begin
      if Rule_States (Unnamed_Exit) = Enabled
        and then not Named
        and then Target_Is_Named
      then
         Report_Finding
           (Unit, Node, Unnamed_Exit,
            "exit statement does not name the loop it leaves");
      end if;

      if Rule_States (Exit_Without_Loop_Name) = Enabled and then not Named then
         Report_Finding
           (Unit, Node, Exit_Without_Loop_Name,
            "exit statement has no loop name");
      end if;

      if Rule_States (Unconditional_Exit) = Enabled
        and then Libadalang.Analysis.Is_Null (Stmt.F_Cond_Expr)
      then
         Report_Finding
           (Unit, Node, Unconditional_Exit,
            "exit statement has no condition");
      end if;

      if Rule_States (Exit_From_Conditional_Loop) = Enabled
        and then In_Loop
        and then Target.Kind in Libadalang.Common.Ada_For_Loop_Stmt
                   | Libadalang.Common.Ada_While_Loop_Stmt
      then
         Report_Finding
           (Unit, Node, Exit_From_Conditional_Loop,
            "exit from a for or while loop");
      end if;

      if Rule_States (Expanded_Loop_Exit_Name) = Enabled
        and then Named
        and then Loop_Name.Kind = Libadalang.Common.Ada_Dotted_Name
      then
         Report_Finding
           (Unit, Node, Expanded_Loop_Exit_Name,
            "exit statement uses an expanded loop name");
      end if;

      --  A named exit leaves an outer loop unless the innermost enclosing
      --  loop carries that very name.
      if Rule_States (Outer_Loop_Exit) = Enabled
        and then Named
        and then Loop_Name.Kind = Libadalang.Common.Ada_Identifier
        and then In_Loop
        and then not (Target_Is_Named
                      and then Canonical_Text
                                 (Target.As_Base_Loop_Stmt.F_End_Name.F_Name) =
                               Canonical_Text (Loop_Name))
      then
         Report_Finding
           (Unit, Node, Outer_Loop_Exit,
            "exit statement leaves an outer loop");
      end if;
   end Analyze_Exit;

   procedure Analyze_Compound_Statement_Name
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind = Libadalang.Common.Ada_Named_Stmt
      then
         return;
      end if;

      if Node.Kind in Libadalang.Common.Ada_Block_Stmt then
         Report_Finding
           (Unit, Node, Unnamed_Block_Or_Loop, "block statement has no name");
      elsif Contains_Loop (Node) then
         Report_Finding
           (Unit, Node, Unnamed_Block_Or_Loop,
            "loop that contains another loop has no name");
      elsif not Libadalang.Analysis.Is_Null (Enclosing_Loop (Node)) then
         Report_Finding
           (Unit, Node, Unnamed_Block_Or_Loop,
            "loop nested in another loop has no name");
      end if;
   end Analyze_Compound_Statement_Name;

   procedure Analyze_Parameter_Mode
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Spec      : constant Libadalang.Analysis.Param_Spec := Node.As_Param_Spec;
      Type_Expr : constant Libadalang.Analysis.Type_Expr := Spec.F_Type_Expr;
   begin
      if Spec.F_Mode.Kind /= Libadalang.Common.Ada_Mode_Default then
         return;
      end if;

      --  An access parameter has no mode to write.
      if Type_Expr.Kind = Libadalang.Common.Ada_Anonymous_Type
        and then Type_Expr.As_Anonymous_Type.F_Type_Decl.F_Type_Def.Kind
                   in Libadalang.Common.Ada_Access_Def
      then
         return;
      end if;

      Report_Finding
        (Unit, Node, Implicit_In_Mode,
         "parameter relies on the default in mode");
   end Analyze_Parameter_Mode;

   --  Reports a function with an out or in out parameter once, on its
   --  declaration: a body is reported only when it has no separate
   --  declaration or stub.
   procedure Analyze_Function_Profile
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Spec : Libadalang.Analysis.Subp_Spec;
   begin
      if Node.Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Expr_Function
      then
         Spec := Node.As_Base_Subp_Body.F_Subp_Spec;
      elsif Node.Kind = Libadalang.Common.Ada_Subp_Body_Stub then
         Spec := Node.As_Subp_Body_Stub.F_Subp_Spec;
      elsif Node.Kind = Libadalang.Common.Ada_Generic_Subp_Internal then
         Spec := Node.As_Generic_Subp_Internal.F_Subp_Spec;
      else
         Spec := Node.As_Classic_Subp_Decl.F_Subp_Spec;
      end if;

      if Spec.F_Subp_Kind.Kind /= Libadalang.Common.Ada_Subp_Kind_Function
        or else Libadalang.Analysis.Is_Null (Spec.F_Subp_Params)
      then
         return;
      end if;

      if Node.Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Expr_Function
           | Libadalang.Common.Ada_Subp_Body_Stub
        and then not Libadalang.Analysis.Is_Null
                       (Node.As_Body_Node.P_Previous_Part)
      then
         return;
      end if;

      declare
         Params : constant Libadalang.Analysis.Param_Spec_List :=
           Spec.F_Subp_Params.F_Params;
      begin
         for I in 1 .. Params.Children_Count loop
            if Params.Child (I).As_Param_Spec.F_Mode.Kind in
                 Libadalang.Common.Ada_Mode_Out
                 | Libadalang.Common.Ada_Mode_In_Out
            then
               Report_Finding
                 (Unit, Node, Function_Out_Parameter,
                  "function has an out or in out parameter");
               return;
            end if;
         end loop;
      end;
   end Analyze_Function_Profile;

   procedure Analyze_Raise
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Name : constant Libadalang.Analysis.Name :=
        Node.As_Raise_Stmt.F_Exception_Name;
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Name) then
         return;
      end if;

      --  Follow exception renamings to the exception actually raised. The
      --  bound only guards against a malformed renaming cycle.
      Decl := Name.P_Referenced_Decl;
      for Step in 1 .. 16 loop
         exit when Libadalang.Analysis.Is_Null (Decl)
           or else Decl.Kind /= Libadalang.Common.Ada_Exception_Decl
           or else Libadalang.Analysis.Is_Null
                     (Decl.As_Exception_Decl.F_Renames);
         Decl := Decl.As_Exception_Decl.F_Renames.F_Renamed_Object
                   .P_Referenced_Decl;
      end loop;

      if Libadalang.Analysis.Is_Null (Decl) then
         return;
      end if;

      declare
         Full_Name : constant String := Ada.Characters.Handling.To_Lower
           (Langkit_Support.Text.To_UTF8
              (Decl.P_Canonical_Fully_Qualified_Name));
      begin
         if Full_Name = "standard.constraint_error"
           or else Full_Name = "standard.program_error"
           or else Full_Name = "standard.storage_error"
           or else Full_Name = "standard.tasking_error"
           or else Full_Name = "standard.numeric_error"
         then
            Report_Finding
              (Unit, Node, Raising_Predefined_Exception,
               "predefined exception " & Node_Text (Name)
               & " raised explicitly");
         end if;
      end;
   end Analyze_Raise;

   procedure Analyze_Anonymous_Type
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      if Node.As_Anonymous_Type_Decl.F_Type_Def.Kind /=
           Libadalang.Common.Ada_Array_Type_Def
      then
         return;
      end if;

      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Object_Decl_Range then
            Report_Finding
              (Unit, Node, Anonymous_Array_Type,
               "object declared with an anonymous array type");
            return;
         end if;
         Current := Current.Parent;
      end loop;
   end Analyze_Anonymous_Type;

   --  Reports a variable declared directly in the visible or private part
   --  of a package specification that is not itself nested in another
   --  package specification.
   procedure Analyze_Global_Variable
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Part    : Libadalang.Analysis.Ada_Node;
      Current : Libadalang.Analysis.Ada_Node;
   begin
      if Node.As_Object_Decl.F_Has_Constant.Kind /=
           Libadalang.Common.Ada_Constant_Absent
        or else Libadalang.Analysis.Is_Null (Node.Parent)
      then
         return;
      end if;

      --  A renaming of a constant, such as an enumeration literal, is not
      --  a variable either. The query needs name resolution, so it is
      --  made only for renamings.
      if not Libadalang.Analysis.Is_Null
               (Node.As_Object_Decl.F_Renaming_Clause)
        and then Node.As_Basic_Decl.P_Is_Constant_Object
      then
         return;
      end if;

      Part := Node.Parent.Parent;
      if Libadalang.Analysis.Is_Null (Part)
        or else Part.Kind not in Libadalang.Common.Ada_Public_Part
                  | Libadalang.Common.Ada_Private_Part
        or else Libadalang.Analysis.Is_Null (Part.Parent)
        or else Part.Parent.Kind not in
                  Libadalang.Common.Ada_Base_Package_Decl
      then
         return;
      end if;

      Current := Part.Parent.Parent;
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Base_Package_Decl then
            return;
         end if;
         Current := Current.Parent;
      end loop;

      Report_Finding
        (Unit, Node, Global_Variable,
         "variable declared in a package specification");
   end Analyze_Global_Variable;

   function Is_Predefined_Numeric_Name (Name : String) return Boolean is
   begin
      return Name = "integer"
        or else Name = "natural"
        or else Name = "positive"
        or else Name = "short_short_integer"
        or else Name = "short_integer"
        or else Name = "long_integer"
        or else Name = "long_long_integer"
        or else Name = "long_long_long_integer"
        or else Name = "short_float"
        or else Name = "float"
        or else Name = "long_float"
        or else Name = "long_long_float"
        or else Name = "duration";
   end Is_Predefined_Numeric_Name;

   procedure Analyze_Identifier
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Name : constant String :=
        Ada.Characters.Handling.To_Lower (Node_Text (Node));
   begin
      --  A reference to a declaration is spelled like that declaration, so
      --  the spelling test spares resolving every other identifier.
      if not Is_Predefined_Numeric_Name (Name) then
         return;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Node.As_Identifier.P_Referenced_Decl;
      begin
         if not Libadalang.Analysis.Is_Null (Decl)
           and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
           and then Ada.Characters.Handling.To_Lower
                      (Langkit_Support.Text.To_UTF8
                         (Decl.P_Canonical_Fully_Qualified_Name)) =
                    "standard." & Name
         then
            Report_Finding
              (Unit, Node, Predefined_Numeric_Type,
               "predefined numeric subtype " & Node_Text (Node)
               & " referenced");
         end if;
      end;
   end Analyze_Identifier;

   function Is_Subprogram_Body
     (Kind : Libadalang.Common.Ada_Node_Kind_Type) return Boolean
   is (Kind in Libadalang.Common.Ada_Base_Subp_Body);

   function Is_Generic_Package
     (Kind : Libadalang.Common.Ada_Node_Kind_Type) return Boolean
   is (Kind = Libadalang.Common.Ada_Generic_Package_Decl);

   function Is_Package_Declaration
     (Kind : Libadalang.Common.Ada_Node_Kind_Type) return Boolean
   is (Kind in Libadalang.Common.Ada_Package_Decl
         | Libadalang.Common.Ada_Generic_Package_Decl);

   function Is_Package_Body
     (Kind : Libadalang.Common.Ada_Node_Kind_Type) return Boolean
   is (Kind = Libadalang.Common.Ada_Package_Body);

   function Is_Object_Or_Component
     (Kind : Libadalang.Common.Ada_Node_Kind_Type) return Boolean
   is (Kind in Libadalang.Common.Ada_Object_Decl_Range
         | Libadalang.Common.Ada_Component_Decl);

   function Is_Representation_Item
     (Kind : Libadalang.Common.Ada_Node_Kind_Type) return Boolean
   is (Kind in Libadalang.Common.Ada_Attribute_Def_Clause
         | Libadalang.Common.Ada_Aspect_Spec);

   --  True when Node is declared directly in the visible or private part
   --  of a package specification.
   function Is_Package_Level_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Part : Libadalang.Analysis.Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Node.Parent) then
         return False;
      end if;
      Part := Node.Parent.Parent;
      return not Libadalang.Analysis.Is_Null (Part)
        and then Part.Kind in Libadalang.Common.Ada_Public_Part
                   | Libadalang.Common.Ada_Private_Part
        and then not Libadalang.Analysis.Is_Null (Part.Parent)
        and then Part.Parent.Kind in Libadalang.Common.Ada_Base_Package_Decl;
   end Is_Package_Level_Declaration;

   procedure Analyze_Abstract_Type
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Is_Abstract : Boolean;
   begin
      if Node.Kind = Libadalang.Common.Ada_Record_Type_Def then
         Is_Abstract := Node.As_Record_Type_Def.F_Has_Abstract.P_As_Bool;
      elsif Node.Kind = Libadalang.Common.Ada_Derived_Type_Def then
         Is_Abstract := Node.As_Derived_Type_Def.F_Has_Abstract.P_As_Bool;
      else
         Is_Abstract := Node.As_Private_Type_Def.F_Has_Abstract.P_As_Bool;
      end if;

      if Is_Abstract then
         Report_Finding
           (Unit, Node, Abstract_Type_Declaration, "abstract type declared");
      end if;
   end Analyze_Abstract_Type;

   procedure Analyze_Derived_Type
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Def : constant Libadalang.Analysis.Derived_Type_Def :=
        Node.As_Derived_Type_Def;
   begin
      if Libadalang.Analysis.Is_Null (Def.F_Record_Extension)
        and then Def.F_Has_With_Private.Kind =
                   Libadalang.Common.Ada_With_Private_Absent
      then
         Report_Finding
           (Unit, Node, Non_Tagged_Derived_Type,
            "derived type is not a type extension");
      end if;
   end Analyze_Derived_Type;

   procedure Analyze_Generic_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Has_Ancestor (Node, Is_Subprogram_Body'Access)
        and then not Has_Ancestor (Node, Is_Generic_Package'Access)
      then
         --  Reported at the unit itself, past its generic formal part.
         Report_Finding
           (Unit,
            (if Node.Kind = Libadalang.Common.Ada_Generic_Subp_Decl
             then Node.As_Generic_Subp_Decl.F_Subp_Decl.As_Ada_Node
             else Node.As_Generic_Package_Decl.F_Package_Decl.As_Ada_Node),
            Generic_In_Subprogram,
            "generic unit declared in a subprogram body");
      end if;
   end Analyze_Generic_Declaration;

   procedure Analyze_Entry
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Siblings : constant Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      if Libadalang.Analysis.Is_Null (Siblings) then
         return;
      end if;

      for I in 1 .. Siblings.Children_Count loop
         declare
            Sibling : constant Libadalang.Analysis.Ada_Node :=
              Siblings.Child (I);
         begin
            exit when Sibling = Node.As_Ada_Node;
            if not Libadalang.Analysis.Is_Null (Sibling)
              and then Sibling.Kind = Libadalang.Common.Ada_Entry_Decl
            then
               Report_Finding
                 (Unit, Node, Multiple_Protected_Entries,
                  "more than one entry in a protected definition");
               return;
            end if;
         end;
      end loop;
   end Analyze_Entry;

   --  Reports a program unit whose end carries no name.
   procedure Analyze_Closing_Name
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind    : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
      Missing : Boolean := False;
   begin
      if Kind = Libadalang.Common.Ada_Subp_Body then
         Missing := Libadalang.Analysis.Is_Null (Node.As_Subp_Body.F_End_Name);
      elsif Kind = Libadalang.Common.Ada_Package_Body then
         Missing :=
           Libadalang.Analysis.Is_Null (Node.As_Package_Body.F_End_Name);
      elsif Kind in Libadalang.Common.Ada_Base_Package_Decl then
         Missing :=
           Libadalang.Analysis.Is_Null (Node.As_Base_Package_Decl.F_End_Name);
      elsif Kind = Libadalang.Common.Ada_Task_Body then
         Missing := Libadalang.Analysis.Is_Null (Node.As_Task_Body.F_End_Name);
      elsif Kind = Libadalang.Common.Ada_Protected_Body then
         Missing :=
           Libadalang.Analysis.Is_Null (Node.As_Protected_Body.F_End_Name);
      elsif Kind in Libadalang.Common.Ada_Task_Type_Decl
              | Libadalang.Common.Ada_Single_Task_Type_Decl
      then
         declare
            Def : constant Libadalang.Analysis.Task_Def :=
              Node.As_Task_Type_Decl.F_Definition;
         begin
            Missing := not Libadalang.Analysis.Is_Null (Def)
              and then Libadalang.Analysis.Is_Null (Def.F_End_Name);
         end;
      elsif Kind = Libadalang.Common.Ada_Protected_Type_Decl then
         Missing := Libadalang.Analysis.Is_Null
           (Node.As_Protected_Type_Decl.F_Definition.F_End_Name);
      else
         Missing := Libadalang.Analysis.Is_Null
           (Node.As_Single_Protected_Decl.F_Definition.F_End_Name);
      end if;

      if Missing then
         Report_Finding
           (Unit, Node, No_Closing_Name,
            "program unit end does not repeat the unit name");
      end if;
   end Analyze_Closing_Name;

   procedure Analyze_Operator_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind        : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
      Is_Operator : Boolean;
   begin
      if Kind = Libadalang.Common.Ada_Generic_Subp_Instantiation then
         Is_Operator :=
           Node.As_Generic_Subp_Instantiation.F_Subp_Name.P_Is_Operator_Name;
      else
         Is_Operator := Node.As_Basic_Decl.P_Defining_Name.P_Is_Operator_Name;
      end if;

      if Is_Operator
        and then (Kind not in Libadalang.Common.Ada_Base_Subp_Body
                  or else Libadalang.Analysis.Is_Null
                            (Node.As_Base_Subp_Body.P_Decl_Part))
      then
         Report_Finding
           (Unit, Node, Overloaded_Operator, "operator symbol overloaded");
      end if;
   end Analyze_Operator_Declaration;

   procedure Analyze_Operator_Renaming
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Renamed : constant Libadalang.Analysis.Name :=
        Node.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object;
   begin
      if not Libadalang.Analysis.Is_Null (Renamed)
        and then Renamed.P_Is_Operator_Name
      then
         Report_Finding
           (Unit, Node, Operator_Renaming, "operator renamed");
      end if;
   end Analyze_Operator_Renaming;

   procedure Analyze_Array_Type
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Owner : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      if Node.As_Array_Type_Def.F_Indices.Kind /=
           Libadalang.Common.Ada_Unconstrained_Array_Indices
      then
         return;
      end if;

      --  A generic formal array type is not a definition of its own.
      for Level in 1 .. 2 loop
         exit when Libadalang.Analysis.Is_Null (Owner);
         if Owner.Kind = Libadalang.Common.Ada_Generic_Formal_Type_Decl then
            return;
         end if;
         Owner := Owner.Parent;
      end loop;

      Report_Finding
        (Unit, Node, Unconstrained_Array_Type,
         "unconstrained array type defined");
   end Analyze_Array_Type;

   procedure Analyze_Case_Shape
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Alternatives : constant Libadalang.Analysis.Case_Stmt_Alternative_List :=
        Node.As_Case_Stmt.F_Alternatives;
   begin
      if Alternatives.Children_Count /= 2 then
         return;
      end if;

      for I in 1 .. 2 loop
         if Alternatives.Child (I).As_Case_Stmt_Alternative.F_Choices
              .Children_Count /= 1
         then
            return;
         end if;
      end loop;

      Report_Finding
        (Unit, Node, Binary_Case_Statement,
         "case statement with two single-choice alternatives can be an " &
         "if statement");
   end Analyze_Case_Shape;

   --  Reports a choice list of a case statement over an enumeration type
   --  that covers values through a range, a subtype name or a 'Range.
   procedure Analyze_Case_Choices
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Alternative : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Has_Range   : Boolean := False;
   begin
      if Libadalang.Analysis.Is_Null (Alternative)
        or else Alternative.Kind /= Libadalang.Common.Ada_Case_Stmt_Alternative
      then
         return;
      end if;

      for I in 1 .. Node.Children_Count loop
         declare
            Choice : constant Libadalang.Analysis.Ada_Node := Node.Child (I);
         begin
            if (Choice.Kind = Libadalang.Common.Ada_Bin_Op
                and then Choice.As_Bin_Op.F_Op.Kind =
                           Libadalang.Common.Ada_Op_Double_Dot)
              or else (Choice.Kind = Libadalang.Common.Ada_Attribute_Ref
                       and then Canonical_Text
                                  (Choice.As_Attribute_Ref.F_Attribute) =
                                "range")
              or else Names_A_Type (Choice)
            then
               Has_Range := True;
            end if;
         end;
      end loop;

      if not Has_Range then
         return;
      end if;

      declare
         Selector_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Alternative.Parent.Parent.As_Case_Stmt.F_Expr.P_Expression_Type;
      begin
         if not Libadalang.Analysis.Is_Null (Selector_Type)
           and then Selector_Type.P_Is_Enum_Type
         then
            Report_Finding
              (Unit, Node, Enumeration_Range_In_Case_Statement,
               "enumeration range used as a case statement choice");
         end if;
      end;
   end Analyze_Case_Choices;

   procedure Analyze_Anonymous_Access
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Node.As_Anonymous_Type_Decl.F_Type_Def.Kind =
           Libadalang.Common.Ada_Type_Access_Def
        and then Has_Ancestor (Node, Is_Object_Or_Component'Access)
      then
         Report_Finding
           (Unit, Node, Anonymous_Access_Type,
            "object or component declared with an anonymous access type");
      end if;
   end Analyze_Anonymous_Access;

   procedure Analyze_Slice
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Node.As_Call_Expr.P_Is_Array_Slice then
         Report_Finding (Unit, Node, Array_Slice, "array slice used");
      end if;
   end Analyze_Slice;

   procedure Analyze_Local_Package
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Has_Ancestor (Node, Is_Package_Declaration'Access)
        and then not Has_Ancestor (Node, Is_Package_Body'Access)
      then
         Report_Finding
           (Unit, Node, Local_Package,
            "package declared inside a package specification");
      end if;
   end Analyze_Local_Package;

   --  Reports a block that declares something. A declarative part that is
   --  empty or holds only pragmas and use clauses is not reported: that is
   --  the scope GNATcheck documents for Declarations_In_Blocks, although
   --  its implementation reports every declare block.
   procedure Analyze_Block_Declarations
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Decls : constant Libadalang.Analysis.Ada_Node_List :=
        Node.As_Decl_Block.F_Decls.F_Decls;
   begin
      for I in 1 .. Decls.Children_Count loop
         declare
            Item : constant Libadalang.Analysis.Ada_Node := Decls.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Item)
              and then Item.Kind not in
                         Libadalang.Common.Ada_Use_Package_Clause
                         | Libadalang.Common.Ada_Use_Type_Clause
                         | Libadalang.Common.Ada_Pragma_Node
            then
               Report_Finding
                 (Unit, Node, Declaration_In_Block,
                  "block statement has local declarations");
               return;
            end if;
         end;
      end loop;
   end Analyze_Block_Declarations;

   procedure Analyze_Size_Attribute
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Ref : constant Libadalang.Analysis.Attribute_Ref :=
        Node.As_Attribute_Ref;
   begin
      if Canonical_Text (Ref.F_Attribute) /= "size"
        or else Has_Ancestor (Node, Is_Representation_Item'Access)
      then
         return;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Ref.F_Prefix.P_Referenced_Decl;
      begin
         if not Libadalang.Analysis.Is_Null (Decl)
           and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
         then
            Report_Finding
              (Unit, Node, Size_Attribute_For_Type,
               "Size attribute applied to a type");
         end if;
      end;
   end Analyze_Size_Attribute;

   --  Reports a construct whose mere presence a check restricts.
   procedure Restrict
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Rule    : Rule_Kind;
      Message : String)
   is
   begin
      if Rule_States (Rule) = Enabled then
         Report_Finding (Unit, Node, Rule, Message);
      end if;
   end Restrict;

   --  Checks keyed on a statement kind.
   procedure Analyze_Statement
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
   begin
      if Kind = Libadalang.Common.Ada_Exit_Stmt then
         begin
            Analyze_Exit (Unit, Node);
         exception
            when Exc : others =>
               Note_Skipped_Check (Node, Exc);
         end;
      elsif Kind in Libadalang.Common.Ada_Block_Stmt
              | Libadalang.Common.Ada_Base_Loop_Stmt
      then
         if Kind in Libadalang.Common.Ada_Block_Stmt then
            Restrict (Unit, Node, No_Block_Statement, "block statement used");
         end if;
         if Kind = Libadalang.Common.Ada_Decl_Block then
            Guarded
              (Unit, Node, On (Declaration_In_Block),
               Analyze_Block_Declarations'Access);
         end if;
         Guarded
           (Unit, Node, On (Unnamed_Block_Or_Loop),
            Analyze_Compound_Statement_Name'Access);
      elsif Kind = Libadalang.Common.Ada_Raise_Stmt then
         Guarded
           (Unit, Node, On (Raising_Predefined_Exception), Analyze_Raise'Access);
      elsif Kind = Libadalang.Common.Ada_Delay_Stmt then
         if Node.As_Delay_Stmt.F_Has_Until.Kind =
              Libadalang.Common.Ada_Until_Absent
         then
            Restrict
              (Unit, Node, Relative_Delay, "relative delay statement used");
         end if;
      elsif Kind = Libadalang.Common.Ada_Case_Stmt then
         Guarded
           (Unit, Node, On (Binary_Case_Statement), Analyze_Case_Shape'Access);
      end if;
   end Analyze_Statement;

   --  Checks keyed on an expression or name kind.
   procedure Analyze_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
   begin
      if Kind = Libadalang.Common.Ada_Identifier then
         Guarded
           (Unit, Node, On (Predefined_Numeric_Type), Analyze_Identifier'Access);
      elsif Kind = Libadalang.Common.Ada_Others_Designator then
         begin
            Analyze_Others_Choice (Unit, Node);
         exception
            when Exc : others =>
               Note_Skipped_Check (Node, Exc);
         end;
      elsif Kind = Libadalang.Common.Ada_Alternatives_List then
         Guarded
           (Unit, Node, On (Enumeration_Range_In_Case_Statement),
            Analyze_Case_Choices'Access);
      elsif Kind in Libadalang.Common.Ada_If_Expr
              | Libadalang.Common.Ada_Case_Expr
      then
         Restrict
           (Unit, Node, Conditional_Expression,
            "conditional expression used");
      elsif Kind = Libadalang.Common.Ada_Quantified_Expr then
         Restrict
           (Unit, Node, Quantified_Expression, "quantified expression used");
      elsif Kind = Libadalang.Common.Ada_Membership_Expr then
         Restrict (Unit, Node, Membership_Test, "membership test used");
      elsif Kind = Libadalang.Common.Ada_Call_Expr then
         Guarded (Unit, Node, On (Array_Slice), Analyze_Slice'Access);
      elsif Kind = Libadalang.Common.Ada_Attribute_Ref then
         Guarded
           (Unit, Node, On (Size_Attribute_For_Type),
            Analyze_Size_Attribute'Access);
      end if;
   end Analyze_Expression;

   --  Checks keyed on a type definition kind.
   procedure Analyze_Type_Definition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Record_Type_Def
           | Libadalang.Common.Ada_Derived_Type_Def
           | Libadalang.Common.Ada_Private_Type_Def
      then
         Guarded
           (Unit, Node, On (Abstract_Type_Declaration),
            Analyze_Abstract_Type'Access);
      end if;

      if Kind = Libadalang.Common.Ada_Derived_Type_Def then
         Guarded
           (Unit, Node, On (Non_Tagged_Derived_Type), Analyze_Derived_Type'Access);
      elsif Kind = Libadalang.Common.Ada_Array_Type_Def then
         Guarded
           (Unit, Node, On (Unconstrained_Array_Type), Analyze_Array_Type'Access);
      elsif Kind = Libadalang.Common.Ada_Enum_Type_Def then
         if Node.As_Enum_Type_Def.F_Enum_Literals.Children_Count < 2 then
            Restrict
              (Unit, Node, Single_Value_Enumeration_Type,
               "enumeration type has a single literal");
         end if;
      elsif Kind in Libadalang.Common.Ada_Interface_Kind_Synchronized
              | Libadalang.Common.Ada_Interface_Kind_Task
              | Libadalang.Common.Ada_Interface_Kind_Protected
      then
         Restrict
           (Unit, Node, Concurrent_Interface, "concurrent interface declared");
      elsif Kind = Libadalang.Common.Ada_Anonymous_Type_Decl then
         Guarded
           (Unit, Node, On (Anonymous_Array_Type), Analyze_Anonymous_Type'Access);
         Guarded
           (Unit, Node, On (Anonymous_Access_Type),
            Analyze_Anonymous_Access'Access);
      end if;
   end Analyze_Type_Definition;

   --  Checks keyed on a subprogram declaration, body or instantiation.
   procedure Analyze_Subprogram_Unit
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Expr_Function
           | Libadalang.Common.Ada_Subp_Body_Stub
           | Libadalang.Common.Ada_Generic_Subp_Internal
           | Libadalang.Common.Ada_Classic_Subp_Decl
      then
         Guarded
           (Unit, Node, On (Function_Out_Parameter),
            Analyze_Function_Profile'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Base_Subp_Body
           | Libadalang.Common.Ada_Classic_Subp_Decl
           | Libadalang.Common.Ada_Generic_Subp_Instantiation
      then
         Guarded
           (Unit, Node, On (Overloaded_Operator),
            Analyze_Operator_Declaration'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Base_Subp_Body
           | Libadalang.Common.Ada_Generic_Subp_Instantiation
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind = Libadalang.Common.Ada_Library_Item
      then
         Restrict
           (Unit, Node, Library_Level_Subprogram,
            "subprogram declared at library level");
      end if;

      if Kind = Libadalang.Common.Ada_Subp_Renaming_Decl then
         Guarded
           (Unit, Node, On (Operator_Renaming), Analyze_Operator_Renaming'Access);
      elsif Kind = Libadalang.Common.Ada_Expr_Function
        and then (Is_Package_Level_Declaration (Node)
                  or else Node.Parent.Kind =
                            Libadalang.Common.Ada_Library_Item)
      then
         Restrict
           (Unit, Node, Expression_Function,
            "expression function declared in a package specification or as a "
            & "library unit");
      end if;
   end Analyze_Subprogram_Unit;

   --  Checks keyed on any other declaration or clause kind.
   procedure Analyze_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Use_Package_Clause
           | Libadalang.Common.Ada_Use_Type_Clause
      then
         if Kind = Libadalang.Common.Ada_Use_Package_Clause then
            Restrict
              (Unit, Node, No_Use_Package_Clause, "use clause for a package");
         end if;
         if not Libadalang.Analysis.Is_Null (Node.Parent)
           and then not Libadalang.Analysis.Is_Null (Node.Parent.Parent)
           and then Node.Parent.Parent.Kind /=
                      Libadalang.Common.Ada_Compilation_Unit
         then
            Restrict
              (Unit, Node, Local_Use_Clause,
               "use clause outside the context clause");
         end if;
      elsif Kind = Libadalang.Common.Ada_Param_Spec then
         Guarded (Unit, Node, On (Implicit_In_Mode), Analyze_Parameter_Mode'Access);
      elsif Kind = Libadalang.Common.Ada_Enum_Rep_Clause then
         Restrict
           (Unit, Node, Enumeration_Representation_Clause,
            "enumeration representation clause used");
      elsif Kind = Libadalang.Common.Ada_Object_Decl then
         Guarded (Unit, Node, On (Global_Variable), Analyze_Global_Variable'Access);
      elsif Kind = Libadalang.Common.Ada_Generic_Formal_Obj_Decl then
         declare
            Formal : constant Libadalang.Analysis.Basic_Decl :=
              Node.As_Generic_Formal_Obj_Decl.F_Decl;
         begin
            if Formal.Kind = Libadalang.Common.Ada_Object_Decl
              and then Formal.As_Object_Decl.F_Mode.Kind =
                         Libadalang.Common.Ada_Mode_In_Out
            then
               Restrict
                 (Unit, Node, Generic_In_Out_Object,
                  "generic formal object of mode in out");
            end if;
         end;
      elsif Kind in Libadalang.Common.Ada_Generic_Package_Decl
              | Libadalang.Common.Ada_Generic_Subp_Decl
      then
         Guarded
           (Unit, Node, On (Generic_In_Subprogram),
            Analyze_Generic_Declaration'Access);
      elsif Kind = Libadalang.Common.Ada_Entry_Decl then
         Guarded (Unit, Node, On (Multiple_Protected_Entries), Analyze_Entry'Access);
      elsif Kind = Libadalang.Common.Ada_Renaming_Clause then
         Restrict
           (Unit, Node, Renaming_Declaration, "renaming declaration used");
      elsif Kind = Libadalang.Common.Ada_Subunit then
         Restrict (Unit, Node, Separate_Unit, "separate unit used");
      elsif Kind = Libadalang.Common.Ada_Number_Decl then
         Restrict (Unit, Node, Number_Declaration, "number declaration used");
      end if;

      if Kind = Libadalang.Common.Ada_Package_Decl then
         Guarded (Unit, Node, On (Local_Package), Analyze_Local_Package'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Package_Body
           | Libadalang.Common.Ada_Base_Package_Decl
           | Libadalang.Common.Ada_Task_Body
           | Libadalang.Common.Ada_Protected_Body
           | Libadalang.Common.Ada_Task_Type_Decl
           | Libadalang.Common.Ada_Single_Task_Type_Decl
           | Libadalang.Common.Ada_Protected_Type_Decl
           | Libadalang.Common.Ada_Single_Protected_Decl
      then
         Guarded (Unit, Node, On (No_Closing_Name), Analyze_Closing_Name'Access);
      end if;
   end Analyze_Declaration;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      Analyze_Statement (Unit, Node);
      Analyze_Expression (Unit, Node);
      Analyze_Type_Definition (Unit, Node);
      Analyze_Subprogram_Unit (Unit, Node);
      Analyze_Declaration (Unit, Node);
   end Analyze_Node;

end Adalang_Analyzer.Checks.Coding_Standard;
