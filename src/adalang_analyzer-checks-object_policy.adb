--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;   use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;     use Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;     use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks.Object_Policy is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Base_Type_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   subtype Node_Kind is Libadalang.Common.Ada_Node_Kind_Type;

   function Aspect_Name
     (Name : String) return Langkit_Support.Text.Unbounded_Text_Type
   is (Langkit_Support.Text.To_Unbounded_Text
         (Langkit_Support.Text.To_Text (Name)));

   function Is_Scope (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Base_Package_Decl
         | Libadalang.Common.Ada_Package_Body
         | Libadalang.Common.Ada_Basic_Subp_Decl
         | Libadalang.Common.Ada_Base_Subp_Body
         | Libadalang.Common.Ada_Task_Type_Decl_Range
         | Libadalang.Common.Ada_Single_Task_Decl
         | Libadalang.Common.Ada_Task_Body
         | Libadalang.Common.Ada_Protected_Type_Decl
         | Libadalang.Common.Ada_Single_Protected_Decl
         | Libadalang.Common.Ada_Protected_Body
         | Libadalang.Common.Ada_Entry_Body
         | Libadalang.Common.Ada_Block_Stmt);

   function Is_Local_Scope (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Basic_Subp_Decl
         | Libadalang.Common.Ada_Subp_Body
         | Libadalang.Common.Ada_Task_Body
         | Libadalang.Common.Ada_Expr_Function
         | Libadalang.Common.Ada_Block_Stmt
         | Libadalang.Common.Ada_Entry_Body
         | Libadalang.Common.Ada_Protected_Body);

   --  The number of ancestors of Node whose kind satisfies Match.
   function Count_Ancestors
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Natural
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
      Total   : Natural := 0;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Match (Current.Kind) then
            Total := Total + 1;
         end if;
         Current := Current.Parent;
      end loop;
      return Total;
   end Count_Ancestors;

   function Is_Generic_Unit (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Generic_Decl);

   function Is_Protected_Definition (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Protected_Def);

   function Has_Local_Scope
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node;
   begin
      if not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind =
                   Libadalang.Common.Ada_Generic_Formal_Obj_Decl
      then
         return True;
      end if;

      Current := Node.P_Semantic_Parent;
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Is_Local_Scope (Current.Kind) then
            return True;
         end if;
         Current := Current.P_Semantic_Parent;
      end loop;
      return False;
   end Has_Local_Scope;

   --  The nearest package specification or body around Node.
   function Enclosing_Package
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Base_Package_Decl
              | Libadalang.Common.Ada_Package_Body
         then
            return Current;
         end if;
         Current := Current.Parent;
      end loop;
      return Libadalang.Analysis.No_Ada_Node;
   end Enclosing_Package;

   function Is_Classwide
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is (Type_Decl.Kind = Libadalang.Common.Ada_Classwide_Type_Decl
       or else (Type_Decl.Kind in Libadalang.Common.Ada_Base_Subtype_Decl
                and then Type_Decl.P_Base_Subtype.Kind =
                           Libadalang.Common.Ada_Classwide_Type_Decl));

   --  True when Type_Ref denotes a specific tagged type, or an anonymous
   --  access to one, written in the same package as Spec: the shape of a
   --  controlling parameter or result.
   function Is_Controlling
     (Type_Ref : Libadalang.Analysis.Type_Expr;
      Spec     : Libadalang.Analysis.Base_Subp_Spec) return Boolean
   is
      Designated : Libadalang.Analysis.Base_Type_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Type_Ref) then
         return False;
      end if;

      Designated := Type_Ref.P_Designated_Type_Decl;
      if Libadalang.Analysis.Is_Null (Designated) then
         return False;
      end if;

      if not ((Designated.P_Is_Tagged_Type
               and then not Is_Classwide (Designated))
              or else (Designated.Kind =
                         Libadalang.Common.Ada_Anonymous_Type_Decl
                       and then not Libadalang.Analysis.Is_Null
                                      (Designated.P_Accessed_Type)
                       and then Designated.P_Accessed_Type.P_Is_Tagged_Type
                       and then not Is_Classwide
                                      (Designated.P_Accessed_Type)))
      then
         return False;
      end if;

      return Enclosing_Package (Type_Ref) = Enclosing_Package (Spec);
   end Is_Controlling;

   --  The specification of a subprogram declaration, or of a body or stub
   --  that has no separate declaration, when it is a primitive operation
   --  of a tagged type; a null node otherwise.
   function Primitive_Spec
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Base_Subp_Spec
   is
      Kind : constant Node_Kind := Node.Kind;
      Spec : Libadalang.Analysis.Base_Subp_Spec;
   begin
      if Kind in Libadalang.Common.Ada_Base_Subp_Body
           | Libadalang.Common.Ada_Subp_Body_Stub
        and then not Libadalang.Analysis.Is_Null
                       (Node.As_Body_Node.P_Previous_Part)
      then
         return Libadalang.Analysis.No_Base_Subp_Spec;
      end if;

      Spec := Node.As_Basic_Decl.P_Subp_Spec_Or_Null;
      if Libadalang.Analysis.Is_Null (Spec)
        or else Libadalang.Analysis.Is_Null
                  (Spec.P_Primitive_Subp_Tagged_Type)
      then
         return Libadalang.Analysis.No_Base_Subp_Spec;
      end if;
      return Spec;
   end Primitive_Spec;

   --  Constructor, Misnamed_Controlling_Parameter and Specific_Pre_Post.
   procedure Analyze_Primitive
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Spec : constant Libadalang.Analysis.Base_Subp_Spec :=
        Primitive_Spec (Node);
   begin
      if Libadalang.Analysis.Is_Null (Spec) then
         return;
      end if;

      if Rule_States (Specific_Pre_Post) = Enabled
        and then (Node.As_Basic_Decl.P_Has_Aspect
                    (Aspect_Name ("Pre"), Previous_Parts_Only => True)
                  or else Node.As_Basic_Decl.P_Has_Aspect
                            (Aspect_Name ("Post"),
                             Previous_Parts_Only => True))
      then
         Report_Rule_Violation
           (Unit, Node, Specific_Pre_Post,
            "primitive operation has a Pre or Post aspect that is not "
            & "class-wide");
      end if;

      if Rule_States (Constructor) /= Enabled
        and then Rule_States (Misnamed_Controlling_Parameter) /= Enabled
      then
         return;
      end if;

      declare
         Params     : constant Libadalang.Analysis.Param_Spec_Array :=
           Spec.P_Params;
         Returns_It : constant Boolean :=
           Is_Controlling (Spec.P_Returns, Spec);
         Controlling_Params : Natural := 0;
      begin
         for P of Params loop
            if Is_Controlling (P.F_Type_Expr, Spec) then
               Controlling_Params := Controlling_Params + 1;
            end if;
         end loop;

         if Rule_States (Constructor) = Enabled
           and then Returns_It
           and then Controlling_Params = 0
         then
            Report_Rule_Violation
              (Unit, Node, Constructor, "constructor function declared");
         end if;

         if Rule_States (Misnamed_Controlling_Parameter) = Enabled
           and then Params'Length > 0
           and then not (Canonical_Text
                           (Params (Params'First).F_Ids.Child (1)
                              .As_Defining_Name.F_Name) = "this"
                         and then Is_Controlling
                                    (Params (Params'First).F_Type_Expr, Spec))
           and then (not Returns_It or else Controlling_Params > 0)
         then
            Report_Rule_Violation
              (Unit, Node, Misnamed_Controlling_Parameter,
               "first parameter is not a controlling parameter named This");
         end if;
      end;
   end Analyze_Primitive;

   --  True when a chain of Depth derivation steps starts at Type_Decl.
   function Has_Derivation_Depth
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl; Depth : Natural)
      return Boolean
   is
   begin
      if Depth = 0 then
         return True;
      end if;

      for Parent of Type_Decl.P_Base_Types loop
         if Has_Derivation_Depth (Parent, Depth - 1) then
            return True;
         end if;
      end loop;
      return False;
   end Has_Derivation_Depth;

   --  The distinct types Type_Decl derives from, directly or not.
   function Parent_Count
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl) return Natural
   is
      Seen  : array (1 .. 256) of Libadalang.Analysis.Base_Type_Decl;
      Total : Natural := 0;

      procedure Visit (Item : Libadalang.Analysis.Base_Type_Decl) is
      begin
         for Parent of Item.P_Base_Types loop
            if not (for some I in 1 .. Total => Seen (I) = Parent)
              and then Total < Seen'Last
            then
               Total := Total + 1;
               Seen (Total) := Parent;
            end if;
            Visit (Parent);
         end loop;
      end Visit;
   begin
      Visit (Type_Decl);
      return Total;
   end Parent_Count;

   --  Deep_Inheritance_Hierarchy, Too_Many_Parents and Too_Many_Primitives
   --  on a type declaration.
   procedure Analyze_Tagged_Type
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl : constant Libadalang.Analysis.Base_Type_Decl :=
        Node.As_Base_Type_Decl;
      Kind : constant Node_Kind := Node.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Type_Decl
        and then not Decl.P_Is_Tagged_Type
      then
         return;
      end if;

      if Rule_States (Too_Many_Parents) = Enabled then
         declare
            Limit : constant Natural :=
              Rule_Parameter (Too_Many_Parents, "n", 5);
            Total : constant Natural := Parent_Count (Decl);
         begin
            if Total > Limit then
               Report_Rule_Violation
                 (Unit, Node, Too_Many_Parents,
                  "type has " & To_Decimal (Total) & " parents, more than "
                  & To_Decimal (Limit));
            end if;
         end;
      end if;

      if Kind not in Libadalang.Common.Ada_Type_Decl then
         return;
      end if;

      if Rule_States (Too_Many_Primitives) = Enabled
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then not Libadalang.Analysis.Is_Null (Node.Parent.Parent)
        and then Node.Parent.Parent.Kind = Libadalang.Common.Ada_Public_Part
      then
         declare
            Limit : constant Natural :=
              Rule_Parameter (Too_Many_Primitives, "n", 5);
            Total : constant Natural := Decl.P_Get_Primitives'Length;
         begin
            if Total > Limit then
               Report_Rule_Violation
                 (Unit, Decl.P_Defining_Name, Too_Many_Primitives,
                  "tagged type has " & To_Decimal (Total)
                  & " primitives, more than " & To_Decimal (Limit));
            end if;
         end;
      end if;

      if Rule_States (Deep_Inheritance_Hierarchy) = Enabled
        and then Node.Parent.Kind /=
                   Libadalang.Common.Ada_Generic_Formal_Type_Decl
        and then not (Node.As_Type_Decl.F_Type_Def.Kind =
                        Libadalang.Common.Ada_Derived_Type_Def
                      and then Node.As_Type_Decl.F_Type_Def
                                 .As_Derived_Type_Def.F_Has_With_Private
                                 .P_As_Bool)
        and then Libadalang.Analysis.Is_Null (Decl.P_Next_Part_For_Decl)
        and then Has_Derivation_Depth
                   (Decl,
                    Rule_Parameter (Deep_Inheritance_Hierarchy, "n", 2) + 1)
      then
         Report_Rule_Violation
           (Unit, Node, Deep_Inheritance_Hierarchy,
            "derivation tree is too deep");
      end if;
   end Analyze_Tagged_Type;

   procedure Analyze_Global_Initialization
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl : constant Libadalang.Analysis.Object_Decl := Node.As_Object_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Decl.F_Default_Expr)
        and then not Decl.F_Has_Constant.P_As_Bool
        and then not Has_Local_Scope (Node)
      then
         Report_Rule_Violation
           (Unit, Node, Uninitialized_Global_Variable,
            "global variable declared without an initial value");
      end if;
   end Analyze_Global_Initialization;

   procedure Analyze_Volatile_Object
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Decl     : constant Libadalang.Analysis.Object_Decl :=
        Node.As_Object_Decl;
      Volatile : Boolean := Decl.P_Has_Aspect (Aspect_Name ("Volatile"));
   begin
      if not Volatile
        and then not Libadalang.Analysis.Is_Null (Decl.F_Type_Expr)
      then
         declare
            Object_Type : constant Libadalang.Analysis.Base_Type_Decl :=
              Decl.F_Type_Expr.P_Designated_Type_Decl;
         begin
            Volatile := not Libadalang.Analysis.Is_Null (Object_Type)
              and then Object_Type.P_Has_Aspect (Aspect_Name ("Volatile"));
         end;
      end if;

      if Volatile
        and then not Decl.P_Has_Aspect (Aspect_Name ("Address"))
      then
         Report_Rule_Violation
           (Unit, Node, Volatile_Object_Without_Address,
            "volatile object has no address specification");
      end if;
   end Analyze_Volatile_Object;

   procedure Analyze_Type_Invariant
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      if Canonical_Text (Node.As_Aspect_Assoc.F_Id) /= "type_invariant" then
         return;
      end if;

      for Level in 1 .. 3 loop
         exit when Libadalang.Analysis.Is_Null (Current);
         if Current.Kind in Libadalang.Common.Ada_Base_Type_Decl
           and then Current.As_Base_Type_Decl.P_Is_Tagged_Type
         then
            Report_Rule_Violation
              (Unit, Node, Specific_Type_Invariant,
               "Type_Invariant aspect of a tagged type is not class-wide");
            return;
         end if;
         Current := Current.Parent;
      end loop;
   end Analyze_Type_Invariant;

   --  True when the barrier identifier Id denotes something other than a
   --  component of the protected object that Owner is the body of.
   function Is_Foreign_To_Barrier
     (Id    : Libadalang.Analysis.Ada_Node;
      Owner : Libadalang.Analysis.Protected_Body) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Id.As_Identifier.P_Referenced_Decl;
      Current : Libadalang.Analysis.Ada_Node;
      Spec    : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return False;
      elsif Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
              | Libadalang.Common.Ada_Param_Spec
      then
         return True;
      elsif Decl.Kind /= Libadalang.Common.Ada_Component_Decl then
         return False;
      end if;

      --  A component is the protected object's own when it is declared in
      --  the private part of that protected unit.
      Spec := Owner.P_Decl_Part;
      Current := Decl.Parent;
      while not Libadalang.Analysis.Is_Null (Current) loop
         if not Libadalang.Analysis.Is_Null (Spec)
           and then Current = Spec.As_Ada_Node
         then
            return False;
         end if;
         Current := Current.Parent;
      end loop;

      --  Otherwise it may be reached through a prefix that is one.
      if not Libadalang.Analysis.Is_Null (Id.Parent)
        and then Id.Parent.Kind = Libadalang.Common.Ada_Dotted_Name
        and then Id.Parent.As_Dotted_Name.F_Prefix.Kind =
                   Libadalang.Common.Ada_Identifier
      then
         return Is_Foreign_To_Barrier
           (Id.Parent.As_Dotted_Name.F_Prefix.As_Ada_Node, Owner)
           and then Id.Parent.As_Dotted_Name.F_Prefix.As_Ada_Node /= Id;
      end if;
      return True;
   end Is_Foreign_To_Barrier;

   function Barrier_Has_Foreign_Name
     (Item  : Libadalang.Analysis.Ada_Node'Class;
      Owner : Libadalang.Analysis.Protected_Body) return Boolean
   is
   begin
      if Item.Kind = Libadalang.Common.Ada_Identifier
        and then Is_Foreign_To_Barrier (Item.As_Ada_Node, Owner)
      then
         return True;
      end if;

      for I in 1 .. Item.Children_Count loop
         if not Libadalang.Analysis.Is_Null (Item.Child (I))
           and then Barrier_Has_Foreign_Name (Item.Child (I), Owner)
         then
            return True;
         end if;
      end loop;
      return False;
   end Barrier_Has_Foreign_Name;

   procedure Analyze_Barrier
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Current : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current)
        and then Current.Kind /= Libadalang.Common.Ada_Protected_Body
      loop
         Current := Current.Parent;
      end loop;

      if not Libadalang.Analysis.Is_Null (Current)
        and then Barrier_Has_Foreign_Name
                   (Node.As_Entry_Body.F_Barrier, Current.As_Protected_Body)
      then
         Report_Rule_Violation
           (Unit, Node.As_Entry_Body.F_Barrier, Non_Component_In_Barrier,
            "barrier refers to something other than a component of the "
            & "protected object");
      end if;
   end Analyze_Barrier;

   --  Runs one check procedure with its own exception boundary.
   procedure Guarded
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Enabled : Boolean;
      Check   : not null access procedure
        (Unit : Libadalang.Analysis.Analysis_Unit;
         Node : Libadalang.Analysis.Ada_Node'Class))
   is
   begin
      if Enabled then
         Check (Unit, Node);
      end if;
   exception
      when Exc : others =>
         Note_Skipped_Check (Node, Exc);
   end Guarded;

   function On (Rule : Rule_Kind) return Boolean
   is (Rule_States (Rule) = Enabled);

   --  The nesting and hierarchy depth checks.
   procedure Analyze_Depth
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      if On (Overly_Nested_Scope)
        and then Is_Scope (Kind)
        and then Count_Ancestors (Node, Is_Scope'Access) >
                   Rule_Parameter (Overly_Nested_Scope, "n", 10)
      then
         Report_Rule_Violation
           (Unit, Node, Overly_Nested_Scope,
            "nesting level of scopes is too deep");
      end if;

      if On (Deeply_Nested_Generic)
        and then Kind in Libadalang.Common.Ada_Generic_Decl
      then
         declare
            Limit : constant Natural :=
              Rule_Parameter (Deeply_Nested_Generic, "n", 5);
            Depth : constant Natural :=
              Count_Ancestors (Node, Is_Generic_Unit'Access);
         begin
            if Depth > Limit then
               Report_Rule_Violation
                 (Unit, Node.As_Basic_Decl.P_Defining_Name,
                  Deeply_Nested_Generic,
                  "generic unit is nested in " & To_Decimal (Depth)
                  & " generic units, more than " & To_Decimal (Limit));
            end if;
         end;
      end if;

      if On (Deep_Library_Hierarchy)
        and then Kind in Libadalang.Common.Ada_Base_Package_Decl
                   | Libadalang.Common.Ada_Generic_Package_Instantiation
      then
         declare
            Name : constant String :=
              Node_Text
                (if Kind = Libadalang.Common.Ada_Generic_Package_Instantiation
                 then Node.As_Generic_Package_Instantiation.F_Name
                 else Node.As_Base_Package_Decl.F_Package_Name);
            Dots : Natural := 0;
         begin
            for C of Name loop
               if C = '.' then
                  Dots := Dots + 1;
               end if;
            end loop;

            if Dots > Rule_Parameter (Deep_Library_Hierarchy, "n", 3) then
               Report_Rule_Violation
                 (Unit, Node, Deep_Library_Hierarchy,
                  "unit has " & To_Decimal (Dots) & " ancestor units");
            end if;
         end;
      end if;
   end Analyze_Depth;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      begin
         Analyze_Depth (Unit, Node);
      exception
         when Exc : others =>
            Note_Skipped_Check (Node, Exc);
      end;

      if Kind in Libadalang.Common.Ada_Basic_Subp_Decl
           | Libadalang.Common.Ada_Base_Subp_Body
           | Libadalang.Common.Ada_Subp_Body_Stub
      then
         Guarded
           (Unit, Node,
            On (Constructor) or else On (Misnamed_Controlling_Parameter)
            or else On (Specific_Pre_Post),
            Analyze_Primitive'Access);
      elsif Kind in Libadalang.Common.Ada_Type_Decl
              | Libadalang.Common.Ada_Task_Type_Decl_Range
              | Libadalang.Common.Ada_Protected_Type_Decl
      then
         Guarded
           (Unit, Node,
            On (Too_Many_Parents) or else On (Too_Many_Primitives)
            or else On (Deep_Inheritance_Hierarchy),
            Analyze_Tagged_Type'Access);
      elsif Kind in Libadalang.Common.Ada_Object_Decl_Range then
         Guarded
           (Unit, Node, On (Uninitialized_Global_Variable),
            Analyze_Global_Initialization'Access);
         Guarded
           (Unit, Node, On (Volatile_Object_Without_Address),
            Analyze_Volatile_Object'Access);
      elsif Kind = Libadalang.Common.Ada_Component_Decl then
         if On (Default_Value_For_Record_Component)
           and then not Libadalang.Analysis.Is_Null
                          (Node.As_Component_Decl.F_Default_Expr)
           and then Count_Ancestors (Node, Is_Protected_Definition'Access) = 0
         then
            Report_Rule_Violation
              (Unit, Node, Default_Value_For_Record_Component,
               "record component has a default value");
         end if;
      elsif Kind = Libadalang.Common.Ada_Aspect_Assoc then
         Guarded
           (Unit, Node, On (Specific_Type_Invariant),
            Analyze_Type_Invariant'Access);
      elsif Kind = Libadalang.Common.Ada_Entry_Body then
         Guarded
           (Unit, Node, On (Non_Component_In_Barrier), Analyze_Barrier'Access);
      end if;
   end Analyze_Node;

end Adalang_Analyzer.Checks.Object_Policy;
