--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Strings.Fixed;

with Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;

package body Adalang_Analyzer.Checks.Policy_Support is

   use type Adalang_Analyzer.Config.Rule_State;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Ref_Result_Kind;

   function On (Rule : Rules.Rule_Kind) return Boolean
   is (Config.Rule_States (Rule) = Config.Enabled);

   procedure Report_Finding
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Rule    : Rules.Rule_Kind;
      Message : String)
   is
      Target : Libadalang.Analysis.Ada_Node := Node.As_Ada_Node;
   begin
      if Node.Kind in Libadalang.Common.Ada_Basic_Decl then
         begin
            declare
               Name : constant Libadalang.Analysis.Defining_Name :=
                 Node.As_Basic_Decl.P_Defining_Name;
            begin
               if not Libadalang.Analysis.Is_Null (Name) then
                  Target := Name.As_Ada_Node;
               end if;
            end;
         exception
            when Exc : others =>
               --  An unnamed or unresolvable declaration is reported at
               --  its own position.
               Note_Skipped_Check (Node, Exc);
         end;
      end if;

      Report.Report_Rule_Violation (Unit, Target, Rule, Message);
   end Report_Finding;

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

   function Has_Ancestor
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Boolean
   is (Count_Ancestors (Node, Match) > 0);

   function Has_Semantic_Ancestor
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Match : not null access function (Kind : Node_Kind) return Boolean)
      return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Node.P_Semantic_Parent;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Match (Current.Kind) then
            return True;
         end if;
         Current := Current.P_Semantic_Parent;
      end loop;
      return False;
   end Has_Semantic_Ancestor;

   function Is_Local_Scope (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Basic_Subp_Decl
         | Libadalang.Common.Ada_Subp_Body
         | Libadalang.Common.Ada_Task_Body
         | Libadalang.Common.Ada_Expr_Function
         | Libadalang.Common.Ada_Block_Stmt
         | Libadalang.Common.Ada_Entry_Body
         | Libadalang.Common.Ada_Protected_Body);

   --  The enclosing constructs are looked at first: they need no name
   --  resolution, so a declaration written inside a subprogram is local
   --  even when its unit cannot be resolved.
   function Has_Local_Scope
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is ((not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind =
                   Libadalang.Common.Ada_Generic_Formal_Obj_Decl)
       or else Has_Ancestor (Node, Is_Local_Scope'Access)
       or else Has_Semantic_Ancestor (Node, Is_Local_Scope'Access));

   function In_Generic_Template
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Node.As_Ada_Node;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind in Libadalang.Common.Ada_Generic_Decl then
            return True;
         elsif Current.Kind in Libadalang.Common.Ada_Package_Body
                 | Libadalang.Common.Ada_Subp_Body
         then
            declare
               Spec : constant Libadalang.Analysis.Ada_Node :=
                 Current.As_Body_Node.P_Decl_Part.As_Ada_Node;
            begin
               if not Libadalang.Analysis.Is_Null (Spec)
                 and then Spec.Kind in Libadalang.Common.Ada_Generic_Decl
                            | Libadalang.Common.Ada_Generic_Package_Internal
                            | Libadalang.Common.Ada_Generic_Subp_Internal
               then
                  return True;
               end if;
            end;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end In_Generic_Template;

   function Referenced
     (Name : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Name)
        or else Name.Kind not in Libadalang.Common.Ada_Name
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;
      --  The failsafe query reports a resolution failure as a result
      --  instead of raising: unwinding an exception for every unresolved
      --  name dominates the run when a unit's dependencies are missing.
      declare
         Result : constant Libadalang.Analysis.Refd_Decl :=
           Name.As_Name.P_Failsafe_Referenced_Decl;
      begin
         if Libadalang.Analysis.Kind (Result) =
              Libadalang.Common.Precise
         then
            return Libadalang.Analysis.Decl (Result).As_Ada_Node;
         end if;
         return Libadalang.Analysis.No_Ada_Node;
      end;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Referenced;

   function Canonical_Exception
     (Name : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
      Decl : Libadalang.Analysis.Ada_Node := Referenced (Name);
   begin
      --  The bound only guards against a malformed renaming cycle.
      for Step in 1 .. 16 loop
         exit when Libadalang.Analysis.Is_Null (Decl)
           or else Decl.Kind /= Libadalang.Common.Ada_Exception_Decl
           or else Libadalang.Analysis.Is_Null
                     (Decl.As_Exception_Decl.F_Renames);
         Decl := Referenced
           (Decl.As_Exception_Decl.F_Renames.F_Renamed_Object);
      end loop;
      return Decl;
   end Canonical_Exception;

   procedure For_Each_Below
     (Root               : Libadalang.Analysis.Ada_Node'Class;
      Visit              : not null access procedure
        (Item : Libadalang.Analysis.Ada_Node);
      Skip_Nested_Bodies : Boolean := False)
   is
   begin
      if Libadalang.Analysis.Is_Null (Root) then
         return;
      end if;

      for I in 1 .. Root.Children_Count loop
         declare
            Child : constant Libadalang.Analysis.Ada_Node := Root.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Child)
              and then not (Skip_Nested_Bodies
                            and then Child.Kind in
                                       Libadalang.Common.Ada_Body_Node)
            then
               Visit (Child);
               For_Each_Below (Child, Visit, Skip_Nested_Bodies);
            end if;
         end;
      end loop;
   end For_Each_Below;

   function Lower (Text : String) return String
     renames Ada.Characters.Handling.To_Lower;

   function Is_Listed
     (Item : String;
      List : String)  --  adalang-analyzer: ignore Swappable_Parameters
      return Boolean
   is
      Wanted : constant String := Lower (Item);
      Start  : Positive := List'First;
   begin
      for I in List'First .. List'Last + 1 loop
         if I > List'Last or else List (I) = ',' then
            if Lower
                 (Ada.Strings.Fixed.Trim
                    (List (Start .. I - 1), Ada.Strings.Both)) = Wanted
            then
               return True;
            end if;
            Start := I + 1;
         end if;
      end loop;
      return False;
   end Is_Listed;

   function Text_Parameter
     (Rule : Rules.Rule_Kind; Name : String) return String
   is (Config.Rule_Parameter (Rule, Name, ""));

   function Is_Set (Rule : Rules.Rule_Kind; Name : String) return Boolean
   is (Lower (Text_Parameter (Rule, Name)) = "true");

   function Aspect_Name
     (Name : String) return Langkit_Support.Text.Unbounded_Text_Type
   is (Langkit_Support.Text.To_Unbounded_Text
         (Langkit_Support.Text.To_Text (Name)));

   function Has_Aspect
     (Decl : Libadalang.Analysis.Basic_Decl'Class; Name : String)
      return Boolean
   is (Decl.P_Has_Aspect (Aspect_Name (Name)));

end Adalang_Analyzer.Checks.Policy_Support;
