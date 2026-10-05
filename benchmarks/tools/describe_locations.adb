--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with Langkit_Support.Slocs;
with Langkit_Support.Text;
with Libadalang.Analysis;
with Libadalang.Common;

--  Reads "file<TAB>line<TAB>column" lines on standard input and prints each
--  one followed by a tab and the construct the location is in, from the
--  inside out: "slice < actual-parameter < call-statement", say. Used by the
--  benchmark ledgers to group the places where the two tools differ. Only
--  the syntax is looked at; no project is needed.
procedure Describe_Locations is

   package LAL renames Libadalang.Analysis;
   package LALCO renames Libadalang.Common;

   use type LAL.Ada_Node;
   use type LALCO.Ada_Node_Kind_Type;

   Context : constant LAL.Analysis_Context := LAL.Create_Context;

   function Lower (Text : String) return String
     renames Ada.Characters.Handling.To_Lower;

   function Text_Of (Node : LAL.Ada_Node'Class) return String
   is (Lower (Langkit_Support.Text.To_UTF8 (Node.Text)));

   --  What Node is, seen from its child Child, or "" when it adds nothing
   --  to the description.
   function Label (Node, Child : LAL.Ada_Node) return String is
      Kind : constant LALCO.Ada_Node_Kind_Type := Node.Kind;
   begin
      if Kind = LALCO.Ada_Aspect_Assoc then
         return "aspect:" & Text_Of (Node.As_Aspect_Assoc.F_Id);
      elsif Kind = LALCO.Ada_Pragma_Node then
         return "pragma:" & Text_Of (Node.As_Pragma_Node.F_Id);
      elsif Kind = LALCO.Ada_Expr_Function then
         return "expression-function";
      elsif Kind = LALCO.Ada_Call_Expr then
         declare
            Suffix : constant LAL.Ada_Node :=
              Node.As_Call_Expr.F_Suffix.As_Ada_Node;
         begin
            if Suffix.Kind /= LALCO.Ada_Assoc_List then
               return "slice";
            elsif Child = Suffix then
               return "argument";
            end if;
            return "";
         end;
      elsif Kind = LALCO.Ada_For_Loop_Spec then
         return "loop-range";
      elsif Kind in LALCO.Ada_Subtype_Indication_Range then
         return "subtype-indication";
      elsif Kind = LALCO.Ada_Subtype_Decl then
         return "subtype-declaration";
      elsif Kind in LALCO.Ada_Base_Aggregate then
         return "aggregate";
      elsif Kind = LALCO.Ada_Object_Decl then
         return "object-declaration";
      elsif Kind = LALCO.Ada_Component_Decl then
         return "component-declaration";
      elsif Kind = LALCO.Ada_Param_Spec then
         return "parameter-declaration";
      elsif Kind = LALCO.Ada_Assign_Stmt then
         return (if Child = Node.As_Assign_Stmt.F_Dest.As_Ada_Node
                 then "assignment-target" else "assignment-value");
      elsif Kind in LALCO.Ada_Return_Stmt | LALCO.Ada_Extended_Return_Stmt then
         return "return";
      elsif Kind = LALCO.Ada_Call_Stmt then
         return "call-statement";
      elsif Kind in LALCO.Ada_If_Stmt | LALCO.Ada_Elsif_Stmt_Part
                  | LALCO.Ada_While_Loop_Spec | LALCO.Ada_Exit_Stmt
      then
         return "condition";
      elsif Kind = LALCO.Ada_Case_Stmt then
         return "case";
      elsif Kind in LALCO.Ada_Cond_Expr then
         return "conditional-expression";
      elsif Kind = LALCO.Ada_Quantified_Expr then
         return "quantified-expression";
      elsif Kind = LALCO.Ada_Attribute_Ref then
         return "attribute:" & Text_Of (Node.As_Attribute_Ref.F_Attribute);
      elsif Kind = LALCO.Ada_Qual_Expr then
         return "qualified-expression";
      elsif Kind in LALCO.Ada_Type_Decl then
         return "type-declaration";
      elsif Kind in LALCO.Ada_Generic_Instantiation then
         return "instantiation";
      elsif Kind in LALCO.Ada_Classic_Subp_Decl then
         return "subprogram-declaration";
      elsif Kind in LALCO.Ada_Base_Subp_Body then
         return "subprogram-body";
      elsif Kind in LALCO.Ada_Base_Package_Decl then
         return "package-specification";
      elsif Kind = LALCO.Ada_Package_Body then
         return "package-body";
      end if;
      return "";
   end Label;

   function Describe (Filename : String; Line, Column : Positive) return String
   is
      Unit   : constant LAL.Analysis_Unit := Context.Get_From_File (Filename);
      Result : Unbounded_String;
      Node, Child : LAL.Ada_Node;
      Last   : Unbounded_String;
   begin
      if Unit.Root.Is_Null then
         return "unparsed";
      end if;
      Node := Unit.Root.Lookup
        ((Langkit_Support.Slocs.Line_Number (Line),
          Langkit_Support.Slocs.Column_Number (Column)));
      if Node.Is_Null then
         return "outside";
      end if;

      Result := To_Unbounded_String ("node:" & Lower (Node.Kind_Name));
      Child := Node;
      Node := Node.Parent;
      while not Node.Is_Null loop
         declare
            Name : constant String := Label (Node, Child);
         begin
            if Name /= "" and then Name /= To_String (Last) then
               Append (Result, " < " & Name);
               Last := To_Unbounded_String (Name);
            end if;
            --  The unit a location is in says nothing more once reached.
            exit when Name = "subprogram-body"
              or else Name = "subprogram-declaration"
              or else Name = "expression-function"
              or else Name = "package-specification"
              or else Name = "package-body";
         end;
         Child := Node;
         Node := Node.Parent;
      end loop;
      return To_String (Result);
   end Describe;

begin
   while not Ada.Text_IO.End_Of_File loop
      declare
         Text   : constant String := Ada.Text_IO.Get_Line;
         First  : constant Natural :=
           Ada.Strings.Fixed.Index (Text, "" & ASCII.HT);
         Second : constant Natural :=
           (if First = 0 then 0
            else Ada.Strings.Fixed.Index (Text, "" & ASCII.HT, First + 1));
      begin
         if Second /= 0 then
            Ada.Text_IO.Put_Line
              (Text & ASCII.HT
               & Describe
                   (Text (Text'First .. First - 1),
                    Positive'Value (Text (First + 1 .. Second - 1)),
                    Positive'Value (Text (Second + 1 .. Text'Last))));
         end if;
      exception
         when others =>
            Ada.Text_IO.Put_Line (Text & ASCII.HT & "error");
      end;
   end loop;
end Describe_Locations;
