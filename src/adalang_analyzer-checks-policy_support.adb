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

package body Adalang_Analyzer.Checks.Policy_Support is

   use type Adalang_Analyzer.Config.Rule_State;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   function On (Rule : Rules.Rule_Kind) return Boolean
   is (Config.Rule_States (Rule) = Config.Enabled);

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

   function Has_Local_Scope
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is ((not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind =
                   Libadalang.Common.Ada_Generic_Formal_Obj_Decl)
       or else Has_Semantic_Ancestor (Node, Is_Local_Scope'Access));

   function Lower (Text : String) return String
     renames Ada.Characters.Handling.To_Lower;

   function Is_Listed (Item : String; List : String) return Boolean is
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
