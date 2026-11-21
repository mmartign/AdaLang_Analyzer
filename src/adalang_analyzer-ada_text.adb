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

with Ada.Characters.Latin_1;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Libadalang.Common;
with Langkit_Support.Text;

with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Ada_Text is

   Next_Character_Offset       : constant Positive := 1;
   Escaped_Quote_Length        : constant Positive := 2;
   Closing_Apostrophe_Offset   : constant Positive := 2;
   Character_Literal_Length    : constant Positive := 3;
   Apostrophe                  : constant Character := Character'Val (39);

   function Node_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return "";
      else
         return Langkit_Support.Text.To_UTF8
           (Libadalang.Analysis.Text (Node));
      end if;
   end Node_Text;

   function Safe_Filename
     (Unit : Libadalang.Analysis.Analysis_Unit) return String is
   begin
      return Unit.Get_Filename;
   exception
      when others =>
         return "<unknown>";
   end Safe_Filename;

   function Canonical_Text  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Node : Libadalang.Analysis.Ada_Node'Class) return String
   is
      Text      : constant String := Node_Text (Node);
      Result    : Unbounded_String;
      Index     : Natural := Text'First;
      In_String : Boolean := False;
   begin
      while Index <= Text'Last loop
         if Text (Index) = '"' then
            Append (Result, Text (Index));
            if In_String and then Index < Text'Last
              and then Text (Index + Next_Character_Offset) = '"'
            then
               --  Two quotes encode one quote inside an Ada string literal.
               Append (Result, Text (Index + Next_Character_Offset));
               Index := Index + Escaped_Quote_Length;
            else
               In_String := not In_String;
               Index := Index + Next_Character_Offset;
            end if;
         elsif In_String then
            Append (Result, Text (Index));
            Index := Index + Next_Character_Offset;
         elsif Text (Index) = Apostrophe
           and then Index + Closing_Apostrophe_Offset <= Text'Last
           and then Text (Index + Closing_Apostrophe_Offset) = Apostrophe
         then
            --  Preserve the spelling and case of character literals.
            Append
              (Result, Text (Index .. Index + Closing_Apostrophe_Offset));
            Index := Index + Character_Literal_Length;
         elsif Text (Index) not in ' '
           | Ada.Characters.Latin_1.HT
           | Ada.Characters.Latin_1.LF
           | Ada.Characters.Latin_1.CR
         then
            Append (Result, Text_Utils.Lower_Char (Text (Index)));
            Index := Index + Next_Character_Offset;
         else
            Index := Index + Next_Character_Offset;
         end if;
      end loop;

      return To_String (Result);
   end Canonical_Text;

   function Terminates_Statement
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt
            | Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            return True;

         when Libadalang.Common.Ada_Exit_Stmt =>
            return Libadalang.Analysis.Is_Null
              (Node.As_Exit_Stmt.F_Cond_Expr);

         when others =>
            return False;
      end case;
   end Terminates_Statement;

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;

   function Attribute_Name
     (Ref : Libadalang.Analysis.Attribute_Ref) return String is
     (Text_Utils.Normalize_Rule_Name (Node_Text (Ref.F_Attribute)));

   function Is_Attribute_Out_Argument
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Assoc : Libadalang.Analysis.Ada_Node;
      Owner : Libadalang.Analysis.Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;
      Assoc := Node.Parent;
      if Libadalang.Analysis.Is_Null (Assoc)
        or else Assoc.Kind /= Libadalang.Common.Ada_Param_Assoc
        or else Libadalang.Analysis.Ada_Node (Assoc.As_Param_Assoc.F_R_Expr)
          /= Libadalang.Analysis.Ada_Node (Node)
        or else Assoc.Parent.Kind /= Libadalang.Common.Ada_Assoc_List
        or else Assoc.Parent.Children_Count /= 2
        or else Assoc.Parent.Child (2) /= Assoc
      then
         return False;
      end if;
      Owner := Assoc.Parent.Parent;
      if Owner.Kind = Libadalang.Common.Ada_Call_Expr then
         Owner := Libadalang.Analysis.Ada_Node (Owner.As_Call_Expr.F_Name);
      end if;
      return Owner.Kind = Libadalang.Common.Ada_Attribute_Ref
        and then Attribute_Name (Owner.As_Attribute_Ref) in
          "read" | "asm-output";
   exception
      when others =>
         return False;
   end Is_Attribute_Out_Argument;

   function Is_Escaping_Attribute_Prefix
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Parent : Libadalang.Analysis.Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;
      Parent := Node.Parent;
      return not Libadalang.Analysis.Is_Null (Parent)
        and then Parent.Kind = Libadalang.Common.Ada_Attribute_Ref
        and then Libadalang.Analysis.Ada_Node (Parent.As_Attribute_Ref.F_Prefix)
          = Libadalang.Analysis.Ada_Node (Node)
        and then Attribute_Name (Parent.As_Attribute_Ref) in
          "access" | "unchecked-access" | "unrestricted-access" | "address";
   exception
      when others =>
         return False;
   end Is_Escaping_Attribute_Prefix;

   function Is_False_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Is_False_Literal (Node.As_Paren_Expr.F_Expr);
      else
         return Canonical_Text (Node) in "false" | "standard.false";
      end if;
   end Is_False_Literal;

   function Follows_A_Call
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      function Makes_A_Call
        (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean is
      begin
         if Libadalang.Analysis.Is_Null (Item) then
            return False;
         elsif Item.Kind = Libadalang.Common.Ada_Call_Stmt
           or else (Item.Kind = Libadalang.Common.Ada_Call_Expr
                    and then Item.As_Call_Expr.P_Kind =
                      Libadalang.Common.Call)
           or else (Item.Kind = Libadalang.Common.Ada_Identifier
                    and then Item.As_Identifier.P_Is_Call)
         then
            return True;
         end if;
         for Index in 1 .. Item.Children_Count loop
            if Makes_A_Call (Item.Child (Index)) then
               return True;
            end if;
         end loop;
         return False;
      end Makes_A_Call;

      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Node);
      Parent  : Libadalang.Analysis.Ada_Node;
   begin
      loop
         Parent := Current.Parent;
         if Libadalang.Analysis.Is_Null (Parent)
           or else Parent.Kind in Libadalang.Common.Ada_Base_Subp_Body
             | Libadalang.Common.Ada_Task_Body
             | Libadalang.Common.Ada_Entry_Body
             | Libadalang.Common.Ada_Package_Body
             | Libadalang.Common.Ada_Compilation_Unit
         then
            return False;
         elsif Parent.Kind = Libadalang.Common.Ada_Stmt_List then
            for Index in 1 .. Parent.Children_Count loop
               exit when Parent.Child (Index) = Current;
               if Makes_A_Call (Parent.Child (Index)) then
                  return True;
               end if;
            end loop;
         end if;
         Current := Parent;
      end loop;
   exception
      when others =>
         return True;
   end Follows_A_Call;

end Adalang_Analyzer.Ada_Text;
