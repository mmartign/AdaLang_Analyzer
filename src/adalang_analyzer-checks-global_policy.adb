--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Hashed_Sets;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Strings.Hash;

with GNATCOLL.GMP.Integers;

with Langkit_Support.Slocs;
with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Config;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks.Global_Policy is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Defining_Name;
   use type GNATCOLL.GMP.Integers.Big_Integer;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;

   subtype Node is Libadalang.Analysis.Ada_Node;

   function Is_Null (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
     renames Libadalang.Analysis.Is_Null;

   package Node_Sets is new Ada.Containers.Hashed_Sets
     (Element_Type        => Node,
      Hash                => Libadalang.Analysis.Hash,
      Equivalent_Elements => Libadalang.Analysis."=",
      "="                 => Libadalang.Analysis."=");

   package String_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   package Node_Vectors is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => Node,
      "="          => Libadalang.Analysis."=");

   ------------------
   --  Use_Clause  --
   ------------------

   --  The visible declarations of the package Name denotes, or a null
   --  node when Name denotes something else.
   function Visible_Declarations (Name : Node) return Node is
      Decl : constant Node := Referenced (Name);
      Pkg  : Libadalang.Analysis.Base_Package_Decl;
   begin
      if Is_Null (Decl) then
         return Libadalang.Analysis.No_Ada_Node;
      elsif Decl.Kind in Libadalang.Common.Ada_Base_Package_Decl then
         Pkg := Decl.As_Base_Package_Decl;
      elsif Decl.Kind = Libadalang.Common.Ada_Package_Renaming_Decl then
         Pkg := Decl.As_Package_Renaming_Decl.P_Final_Renamed_Package
                  .As_Base_Package_Decl;
      elsif Decl.Kind = Libadalang.Common.Ada_Generic_Package_Instantiation
      then
         Pkg := Decl.As_Generic_Package_Instantiation
                  .P_Designated_Generic_Decl.As_Generic_Package_Decl
                  .F_Package_Decl.As_Base_Package_Decl;
      else
         return Libadalang.Analysis.No_Ada_Node;
      end if;
      return Pkg.F_Public_Part.F_Decls.As_Ada_Node;
   end Visible_Declarations;

   function Is_Operator (Decl : Node) return Boolean
   is (Decl.Kind in Libadalang.Common.Ada_Basic_Subp_Decl
                  | Libadalang.Common.Ada_Base_Subp_Body
       and then Decl.As_Basic_Decl.P_Defining_Name.P_Is_Operator_Name);

   --  True unless the package Name denotes declares operators and nothing
   --  else in its visible part.
   function Declares_More_Than_Operators (Name : Node) return Boolean is
      Decls : constant Node := Visible_Declarations (Name);
   begin
      if Is_Null (Decls) or else Decls.Children_Count = 0 then
         return True;
      end if;
      for I in 1 .. Decls.Children_Count loop
         if not Is_Null (Decls.Child (I))
           and then not Is_Operator (Decls.Child (I))
         then
            return True;
         end if;
      end loop;
      return False;
   end Declares_More_Than_Operators;

   function Qualified_Name (Decl : Node) return String is
   begin
      if Is_Null (Decl) or else Decl.Kind not in Libadalang.Common.Ada_Basic_Decl
      then
         return "";
      end if;
      return Langkit_Support.Text.To_UTF8
        (Decl.As_Basic_Decl.P_Canonical_Fully_Qualified_Name);
   exception
      when others =>
         return "";
   end Qualified_Name;

   procedure Analyze_Use_Clause
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Allowed : constant String := Text_Parameter (Use_Clause, "allowed");
      Exempt  : constant Boolean :=
        Is_Set (Use_Clause, "exempt_operator_packages");
      Names   : constant Libadalang.Analysis.Name_List :=
        Item.As_Use_Package_Clause.F_Packages;
   begin
      for I in 1 .. Names.Children_Count loop
         declare
            Name : constant Node := Names.Child (I);
         begin
            if not Is_Null (Name)
              and then
                (Allowed = ""
                 or else not Is_Listed
                               (Qualified_Name (Referenced (Name)), Allowed))
              and then (not Exempt
                        or else Declares_More_Than_Operators (Name))
            then
               Report_Finding (Unit, Name, Use_Clause, "use clause");
            end if;
         end;
      end loop;
   end Analyze_Use_Clause;

   -----------------------------
   --  Unavailable_Body_Call  --
   -----------------------------

   procedure Analyze_Unavailable_Body
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Name : constant Libadalang.Analysis.Name := Item.As_Name;
   begin
      if Is_Set (Unavailable_Body_Call, "indirect_calls")
        and then Name.P_Is_Access_Call
      then
         Report_Finding
           (Unit, Item, Unavailable_Body_Call, "call to unavailable body");
         return;
      end if;

      if Item.Kind not in Libadalang.Common.Ada_Base_Id
        or else not Name.P_Is_Static_Call
      then
         return;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
      begin
         if not Is_Null (Decl)
           and then Decl.Kind = Libadalang.Common.Ada_Subp_Decl
           and then Is_Null (Decl.As_Subp_Decl.P_Body_Part)
         then
            Report_Finding
              (Unit, Item, Unavailable_Body_Call, "call to unavailable body");
         end if;
      end;
   end Analyze_Unavailable_Body;

   ------------------------------
   --  Deeply_Nested_Inlining  --
   ------------------------------

   function Body_Of (Decl : Libadalang.Analysis.Basic_Decl'Class) return Node
   is
   begin
      if Decl.Kind in Libadalang.Common.Ada_Classic_Subp_Decl then
         return Decl.As_Classic_Subp_Decl.P_Body_Part.As_Ada_Node;
      elsif Decl.Kind = Libadalang.Common.Ada_Generic_Subp_Decl then
         return Decl.As_Generic_Subp_Decl.P_Body_Part.As_Ada_Node;
      else
         return Libadalang.Analysis.No_Ada_Node;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Body_Of;

   --  The body of the subprogram Name denotes when Inline applies to it,
   --  a null node otherwise.
   function Inlined_Body (Name : Libadalang.Analysis.Name) return Node is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Name.P_Referenced_Decl;
   begin
      if Is_Null (Decl) then
         return Libadalang.Analysis.No_Ada_Node;
      elsif Decl.Kind in Libadalang.Common.Ada_Base_Subp_Body then
         return (if Has_Aspect (Decl, "Inline") then Decl.As_Ada_Node
                 else Libadalang.Analysis.No_Ada_Node);
      elsif Decl.Kind = Libadalang.Common.Ada_Enum_Literal_Decl then
         return Libadalang.Analysis.No_Ada_Node;
      elsif Decl.Kind = Libadalang.Common.Ada_Generic_Subp_Instantiation then
         declare
            Generic_Decl : constant Node :=
              Referenced
                (Decl.As_Generic_Subp_Instantiation.F_Generic_Subp_Name);
         begin
            if not Is_Null (Generic_Decl)
              and then Generic_Decl.Kind =
                         Libadalang.Common.Ada_Generic_Subp_Decl
              and then (Has_Aspect (Generic_Decl.As_Basic_Decl, "Inline")
                        or else Has_Aspect (Decl, "Inline"))
            then
               return Body_Of (Generic_Decl.As_Basic_Decl);
            end if;
         end;
      end if;

      if Decl.P_Is_Subprogram and then Has_Aspect (Decl, "Inline") then
         return Body_Of (Decl);
      end if;
      return Libadalang.Analysis.No_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Inlined_Body;

   --  True when a chain of Depth calls to inlined subprograms starts in
   --  Subp_Body, nested bodies left out.
   function Inlines_To_Depth (Subp_Body : Node; Depth : Natural) return Boolean
   is
      Found : Boolean := False;

      procedure Visit (Item : Node) is
      begin
         if not Found
           and then Item.Kind in Libadalang.Common.Ada_Name
           and then Item.As_Name.P_Is_Call
           and then Inlines_To_Depth
                      (Inlined_Body (Item.As_Name), Depth - 1)
         then
            Found := True;
         end if;
      exception
         when Exc : others =>
            --  An unresolved name is not a known inlined call.
            Note_Skipped_Check (Item, Exc);
      end Visit;
   begin
      if Depth = 0 then
         return not Is_Null (Subp_Body);
      elsif Is_Null (Subp_Body) then
         return False;
      end if;
      For_Each_Below (Subp_Body, Visit'Access, Skip_Nested_Bodies => True);
      return Found;
   end Inlines_To_Depth;

   procedure Analyze_Nested_Inlining
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Depth : constant Natural :=
        Config.Rule_Parameter (Deeply_Nested_Inlining, "n", 3) + 1;
      Kind  : constant Node_Kind := Item.Kind;
      Start : Node := Libadalang.Analysis.No_Ada_Node;
   begin
      if Kind in Libadalang.Common.Ada_Classic_Subp_Decl
           | Libadalang.Common.Ada_Generic_Subp_Decl
      then
         if Has_Aspect (Item.As_Basic_Decl, "Inline") then
            Start := Body_Of (Item.As_Basic_Decl);
         end if;
      elsif Kind in Libadalang.Common.Ada_Base_Subp_Body then
         if Is_Null (Item.As_Base_Subp_Body.P_Previous_Part)
           and then Has_Aspect (Item.As_Basic_Decl, "Inline")
         then
            Start := Item.As_Ada_Node;
         end if;
      elsif Kind = Libadalang.Common.Ada_Generic_Subp_Instantiation then
         declare
            Generic_Decl : constant Node :=
              Referenced
                (Item.As_Generic_Subp_Instantiation.F_Generic_Subp_Name);
         begin
            if not Is_Null (Generic_Decl)
              and then Generic_Decl.Kind =
                         Libadalang.Common.Ada_Generic_Subp_Decl
              and then Has_Aspect (Generic_Decl.As_Basic_Decl, "Inline")
            then
               Start := Body_Of (Generic_Decl.As_Basic_Decl);
            end if;
         end;
      end if;

      if Inlines_To_Depth (Start, Depth) then
         Report_Finding
           (Unit, Item, Deeply_Nested_Inlining, "deeply nested inlining");
      end if;
   end Analyze_Nested_Inlining;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      if Kind = Libadalang.Common.Ada_Use_Package_Clause then
         Guarded (Unit, Node, On (Use_Clause), Analyze_Use_Clause'Access);
      elsif Kind in Libadalang.Common.Ada_Classic_Subp_Decl
              | Libadalang.Common.Ada_Generic_Subp_Decl
              | Libadalang.Common.Ada_Base_Subp_Body
              | Libadalang.Common.Ada_Generic_Subp_Instantiation
      then
         Guarded
           (Unit, Node, On (Deeply_Nested_Inlining),
            Analyze_Nested_Inlining'Access);
      elsif Kind in Libadalang.Common.Ada_Name then
         Guarded
           (Unit, Node, On (Unavailable_Body_Call),
            Analyze_Unavailable_Body'Access);
      end if;
   end Analyze_Node;

   -----------------------------------
   --  Integer_Type_As_Enumeration  --
   -----------------------------------

   function Is_Arithmetic (Op : Node_Kind) return Boolean
   is (Op in Libadalang.Common.Ada_Op_Div | Libadalang.Common.Ada_Op_Minus
           | Libadalang.Common.Ada_Op_Mod | Libadalang.Common.Ada_Op_Mult
           | Libadalang.Common.Ada_Op_Plus | Libadalang.Common.Ada_Op_Pow
           | Libadalang.Common.Ada_Op_Rem | Libadalang.Common.Ada_Op_Xor
           | Libadalang.Common.Ada_Op_And | Libadalang.Common.Ada_Op_Or
           | Libadalang.Common.Ada_Op_Abs | Libadalang.Common.Ada_Op_Not);

   --  The types that keep an integer type from being an enumeration
   --  candidate: those of arithmetic and bitwise operations, those named in
   --  an instantiation, conversion operands and targets, and the parents
   --  of subtypes and derived types.
   Numeric_Uses : Node_Sets.Set;

   --  Every package instantiation of the analyzed sources.
   Instantiations : Node_Vectors.Vector;

   procedure Note_Use (Item : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if not Is_Null (Item) then
         Numeric_Uses.Include (Item.As_Ada_Node);
      end if;
   end Note_Use;

   procedure Collect (Item : Node) is
      Kind : constant Node_Kind := Item.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Bin_Op
               | Libadalang.Common.Ada_Relation_Op
      then
         if Is_Arithmetic (Item.As_Bin_Op.F_Op.Kind) then
            Note_Use (Item.As_Expr.P_Expression_Type);
         end if;
      elsif Kind = Libadalang.Common.Ada_Un_Op then
         if Is_Arithmetic (Item.As_Un_Op.F_Op.Kind) then
            Note_Use (Item.As_Expr.P_Expression_Type);
         end if;
      elsif Kind = Libadalang.Common.Ada_Call_Expr then
         if Item.As_Call_Expr.P_Kind = Libadalang.Common.Type_Conversion then
            Note_Use (Referenced (Item));
            declare
               Suffix : constant Node := Item.As_Call_Expr.F_Suffix.As_Ada_Node;
            begin
               if Suffix.Kind = Libadalang.Common.Ada_Assoc_List
                 and then Suffix.Children_Count >= 1
                 and then Suffix.Child (1).Kind =
                            Libadalang.Common.Ada_Param_Assoc
               then
                  Note_Use
                    (Suffix.Child (1).As_Param_Assoc.F_R_Expr
                       .P_Expression_Type);
               end if;
            end;
         end if;
      elsif Kind = Libadalang.Common.Ada_Subtype_Decl then
         Note_Use (Referenced (Item.As_Subtype_Decl.F_Subtype.F_Name));
      elsif Kind in Libadalang.Common.Ada_Type_Decl then
         declare
            Def : constant Libadalang.Analysis.Type_Def :=
              Item.As_Type_Decl.F_Type_Def;
         begin
            if not Is_Null (Def)
              and then Def.Kind = Libadalang.Common.Ada_Derived_Type_Def
            then
               Note_Use
                 (Referenced
                    (Def.As_Derived_Type_Def.F_Subtype_Indication.F_Name));
            end if;
         end;
      end if;

      if Kind = Libadalang.Common.Ada_Generic_Package_Instantiation then
         Instantiations.Append (Item);
      end if;
   exception
      when Exc : others =>
         Note_Skipped_Check (Item, Exc);
   end Collect;

   --  Records what the names under an instantiation denote.
   procedure Collect_Instantiation_Names (Item : Node) is
      procedure Visit (Below : Node) is
      begin
         if Below.Kind = Libadalang.Common.Ada_Identifier then
            Note_Use (Referenced (Below));
         end if;
      end Visit;
   begin
      if Item.Kind in Libadalang.Common.Ada_Generic_Instantiation then
         For_Each_Below (Item, Visit'Access);
      end if;
   end Collect_Instantiation_Names;

   procedure Report_Integer_Types
     (Unit : Libadalang.Analysis.Analysis_Unit)
   is
      procedure Visit (Item : Node) is
      begin
         if Item.Kind = Libadalang.Common.Ada_Concrete_Type_Decl
           and then Item.As_Base_Type_Decl.P_Is_Int_Type
           and then not Numeric_Uses.Contains (Item)
         then
            Report_Finding
              (Unit, Item, Integer_Type_As_Enumeration,
               "integer type may be replaced by an enumeration");
         end if;
      exception
         when Exc : others =>
            Note_Skipped_Check (Item, Exc);
      end Visit;
   begin
      For_Each_Below (Unit.Root, Visit'Access);
   end Report_Integer_Types;

   --------------------------
   --  Same_Instantiation  --
   --------------------------

   function Same_Actual (Left, Right : Libadalang.Analysis.Expr) return Boolean
   is
      Kind : constant Node_Kind := Left.Kind;
   begin
      if Kind = Libadalang.Common.Ada_Int_Literal then
         return Right.Kind = Kind
           and then Left.As_Int_Literal.P_Denoted_Value =
                      Right.As_Int_Literal.P_Denoted_Value;
      elsif Kind = Libadalang.Common.Ada_String_Literal then
         return Right.Kind = Kind
           and then Left.As_String_Literal.P_Denoted_Value =
                      Right.As_String_Literal.P_Denoted_Value;
      elsif Kind = Libadalang.Common.Ada_Char_Literal then
         return Right.Kind = Kind
           and then Left.As_Char_Literal.P_Denoted_Value =
                      Right.As_Char_Literal.P_Denoted_Value;
      elsif Kind in Libadalang.Common.Ada_Name then
         if Right.Kind not in Libadalang.Common.Ada_Name then
            return False;
         end if;
         declare
            Definition : constant Libadalang.Analysis.Defining_Name :=
              Left.As_Name.P_Referenced_Defining_Name;
         begin
            return not Is_Null (Definition)
              and then Definition = Right.As_Name.P_Referenced_Defining_Name
              and then not Left.As_Name.P_Is_Call;
         end;
      else
         return False;
      end if;
   end Same_Actual;

   function Same_Parameters
     (Left, Right : Libadalang.Analysis.Generic_Package_Instantiation)
      return Boolean
   is
      Left_Params  : constant Libadalang.Analysis.Param_Actual_Array :=
        Left.P_Inst_Params;
      Right_Params : constant Libadalang.Analysis.Param_Actual_Array :=
        Right.P_Inst_Params;
   begin
      if Left_Params'Length = 0
        or else Left_Params'Length /= Right_Params'Length
      then
         return False;
      end if;
      for I in Left_Params'Range loop
         declare
            Left_Actual  : constant Libadalang.Analysis.Expr :=
              Libadalang.Analysis.Actual (Left_Params (I)).As_Expr;
            Right_Actual : constant Libadalang.Analysis.Expr :=
              Libadalang.Analysis.Actual
                (Right_Params (I - Left_Params'First + Right_Params'First))
                .As_Expr;
         begin
            if Is_Null (Left_Actual) or else Is_Null (Right_Actual)
              or else not Same_Actual (Left_Actual, Right_Actual)
            then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Same_Parameters;

   function Location (Item : Node) return String is
      Start : constant Langkit_Support.Slocs.Source_Location :=
        Langkit_Support.Slocs.Start_Sloc (Item.Sloc_Range);
   begin
      return Ada.Directories.Simple_Name (Item.Unit.Get_Filename) & ":"
        & To_Decimal (Natural (Start.Line)) & ":"
        & To_Decimal (Natural (Start.Column));
   end Location;

   --  The file names of the analyzed units: findings are reported there
   --  only.
   Analyzed_Units : String_Sets.Set;

   procedure Report_Same_Instantiations is
      Library_Only : constant Boolean :=
        Is_Set (Same_Instantiation, "library_level_only");

      function Considered (Item : Node) return Boolean
      is (not Library_Only or else not Has_Local_Scope (Item));
   begin
      for Candidate of Instantiations loop
         if Considered (Candidate)
           and then Analyzed_Units.Contains (Candidate.Unit.Get_Filename)
         then
            begin
               declare
                  Generic_Decl : constant Node :=
                    Referenced
                      (Candidate.As_Generic_Package_Instantiation
                         .F_Generic_Pkg_Name);
               begin
                  for Other of Instantiations loop
                     if Other /= Candidate
                       and then Considered (Other)
                       and then not Is_Null (Generic_Decl)
                       and then Referenced
                                  (Other.As_Generic_Package_Instantiation
                                     .F_Generic_Pkg_Name) = Generic_Decl
                       and then Same_Parameters
                                  (Candidate.As_Generic_Package_Instantiation,
                                   Other.As_Generic_Package_Instantiation)
                     then
                        Report_Finding
                          (Candidate.Unit, Candidate, Same_Instantiation,
                           "same instantiation found at " & Location (Other));
                        exit;
                     end if;
                  end loop;
               end;
            exception
               when Exc : others =>
                  Note_Skipped_Check (Candidate, Exc);
            end;
         end if;
      end loop;
   end Report_Same_Instantiations;

   procedure Analyze_Sources
     (Ctx     : Libadalang.Analysis.Analysis_Context;
      Sources : Source_Lists)
   is
      Integer_Types : constant Boolean := On (Integer_Type_As_Enumeration);
      Instances     : constant Boolean := On (Same_Instantiation);

      procedure Visit (Item : Node) is
      begin
         Collect (Item);
         if Integer_Types then
            Collect_Instantiation_Names (Item);
         end if;
      end Visit;
   begin
      if not Integer_Types and then not Instances then
         return;
      end if;

      Numeric_Uses.Clear;
      Instantiations.Clear;
      Analyzed_Units.Clear;
      for File of Sources.Analyzed loop
         Analyzed_Units.Include (Ctx.Get_From_File (File).Get_Filename);
      end loop;

      for File of Sources.Known loop
         declare
            Unit : constant Libadalang.Analysis.Analysis_Unit :=
              Ctx.Get_From_File (File);
         begin
            if not Unit.Has_Diagnostics then
               For_Each_Below (Unit.Root, Visit'Access);
            end if;
         end;
      end loop;

      if Integer_Types then
         for File of Sources.Analyzed loop
            declare
               Unit : constant Libadalang.Analysis.Analysis_Unit :=
                 Ctx.Get_From_File (File);
            begin
               if not Unit.Has_Diagnostics then
                  Report_Integer_Types (Unit);
               end if;
            end;
         end loop;
      end if;

      if Instances then
         Report_Same_Instantiations;
      end if;
   end Analyze_Sources;

end Adalang_Analyzer.Checks.Global_Policy;
