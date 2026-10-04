--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Fixed;

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;   use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;     use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks.Flow_Policy is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   subtype Node is Libadalang.Analysis.Ada_Node;

   function Is_Null (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
     renames Libadalang.Analysis.Is_Null;

   function Referenced
     (Name : Libadalang.Analysis.Ada_Node'Class) return Node
   is
   begin
      if Is_Null (Name) or else Name.Kind not in Libadalang.Common.Ada_Name
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;
      return Name.As_Name.P_Referenced_Decl.As_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Referenced;

   --  The fully qualified name, in lower case, of what Name denotes, or "".
   function Denoted_Name
     (Name : Libadalang.Analysis.Ada_Node'Class) return String
   is
      Definition : Libadalang.Analysis.Defining_Name;
   begin
      if Is_Null (Name) or else Name.Kind not in Libadalang.Common.Ada_Name
      then
         return "";
      end if;

      Definition := Name.As_Name.P_Referenced_Defining_Name;
      return (if Is_Null (Definition) then ""
              else Lower
                     (Langkit_Support.Text.To_UTF8
                        (Definition.P_Canonical_Fully_Qualified_Name)));
   exception
      when others =>
         return "";
   end Denoted_Name;

   --  The exception declaration Name denotes, looking through renamings.
   function Canonical_Exception
     (Name : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Decl : Node := Referenced (Name);
   begin
      for Step in 1 .. 16 loop
         exit when Is_Null (Decl)
           or else Decl.Kind /= Libadalang.Common.Ada_Exception_Decl
           or else Is_Null (Decl.As_Exception_Decl.F_Renames);
         Decl := Referenced
           (Decl.As_Exception_Decl.F_Renames.F_Renamed_Object);
      end loop;
      return Decl;
   end Canonical_Exception;

   function Enclosing_Body
     (Item : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Current : Node := Item.Parent;
   begin
      while not Is_Null (Current)
        and then Current.Kind not in Libadalang.Common.Ada_Body_Node
      loop
         Current := Current.Parent;
      end loop;
      return Current;
   end Enclosing_Body;

   --  Calls Visit on every node below Root, without entering the bodies
   --  nested in it when Skip_Nested_Bodies is set.
   procedure For_Each_Below
     (Root               : Libadalang.Analysis.Ada_Node'Class;
      Visit              : not null access procedure (Item : Node);
      Skip_Nested_Bodies : Boolean := False)
   is
   begin
      for I in 1 .. Root.Children_Count loop
         declare
            Child : constant Node := Root.Child (I);
         begin
            if not Is_Null (Child) then
               Visit (Child);
               if not (Skip_Nested_Bodies
                       and then Child.Kind in Libadalang.Common.Ada_Body_Node)
               then
                  For_Each_Below (Child, Visit, Skip_Nested_Bodies);
               end if;
            end if;
         end;
      end loop;
   end For_Each_Below;

   -------------------
   --  Complexity   --
   -------------------

   function Is_Jump (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Return_Stmt
         | Libadalang.Common.Ada_Raise_Stmt
         | Libadalang.Common.Ada_Terminate_Alternative
         | Libadalang.Common.Ada_Goto_Stmt
         | Libadalang.Common.Ada_Exit_Stmt);

   function Is_Loop (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Base_Loop_Stmt);

   function Is_Branch (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Case_Stmt
         | Libadalang.Common.Ada_If_Stmt
         | Libadalang.Common.Ada_Select_Stmt);

   --  Essential complexity: one, plus the number of compound statements
   --  that a jump (return, raise, goto, exit, terminate) leaves early. An
   --  exit counts the constructs up to and including its loop.
   function Essential_Complexity
     (Subprogram : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Counted : array (1 .. 512) of Node;
      Total   : Natural := 0;

      procedure Add (Item : Node) is
      begin
         if not (for some I in 1 .. Total => Counted (I) = Item)
           and then Total < Counted'Last
         then
            Total := Total + 1;
            Counted (Total) := Item;
         end if;
      end Add;

      procedure Visit (Item : Node) is
         Current : Node := Item;
         Is_Exit : constant Boolean :=
           Item.Kind = Libadalang.Common.Ada_Exit_Stmt;
      begin
         if not Is_Jump (Item.Kind) then
            return;
         end if;

         loop
            exit when Is_Null (Current.Parent);
            if Is_Loop (Current.Parent.Kind) then
               Add (Current.Parent);
               exit when Is_Exit;
               Current := Current.Parent;
            elsif Is_Branch (Current.Parent.Kind) then
               Add (Current.Parent);
               Current := Current.Parent;
            elsif Current.Kind in Libadalang.Common.Ada_Basic_Decl then
               exit;
            else
               Current := Current.Parent;
            end if;
         end loop;
      end Visit;
   begin
      For_Each_Below (Subprogram, Visit'Access, Skip_Nested_Bodies => True);
      return Total + 1;
   end Essential_Complexity;

   function Counts_As_Subexpression (Kind : Node_Kind) return Boolean
   is ((Kind in Libadalang.Common.Ada_Single_Tok_Node
        and then Kind not in Libadalang.Common.Ada_Op)
       or else Kind in Libadalang.Common.Ada_Cond_Expr
                 | Libadalang.Common.Ada_Quantified_Expr
                 | Libadalang.Common.Ada_Base_Aggregate
                 | Libadalang.Common.Ada_Target_Name);

   procedure Analyze_Expression_Size
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Total : Natural := (if Counts_As_Subexpression (Item.Kind) then 1 else 0);

      procedure Visit (Candidate : Node) is
      begin
         if Counts_As_Subexpression (Candidate.Kind) then
            Total := Total + 1;
         end if;
      end Visit;

      Limit : constant Natural :=
        Config.Rule_Parameter (Maximum_Expression_Complexity, "n", 10);
   begin
      For_Each_Below (Item, Visit'Access);
      if Total > Limit then
         Report_Rule_Violation
           (Unit, Item, Maximum_Expression_Complexity,
            "expression has " & To_Decimal (Total)
            & " sub-expressions, more than " & To_Decimal (Limit));
      end if;
   end Analyze_Expression_Size;

   ------------------------
   --  Nested paths      --
   ------------------------

   --  The statement that unconditionally leaves Stmts as its last
   --  statement, looking into a final block without handlers.
   function Last_Breaking_Statement
     (Stmts : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Last : Node;
   begin
      if Is_Null (Stmts) or else Stmts.Children_Count = 0 then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      Last := Stmts.Child (Stmts.Children_Count);
      if Last.Kind in Libadalang.Common.Ada_Raise_Stmt
           | Libadalang.Common.Ada_Return_Stmt
             | Libadalang.Common.Ada_Goto_Stmt
        or else (Last.Kind = Libadalang.Common.Ada_Exit_Stmt
                 and then Is_Null (Last.As_Exit_Stmt.F_Cond_Expr))
      then
         return Last;
      elsif Last.Kind in Libadalang.Common.Ada_Block_Stmt then
         declare
            Handled : constant Libadalang.Analysis.Handled_Stmts :=
              (if Last.Kind = Libadalang.Common.Ada_Decl_Block
               then Last.As_Decl_Block.F_Stmts
               else Last.As_Begin_Block.F_Stmts);
         begin
            if Handled.F_Exceptions.Children_Count = 0 then
               return Last_Breaking_Statement (Handled.F_Stmts);
            end if;
         end;
      end if;
      return Libadalang.Analysis.No_Ada_Node;
   end Last_Breaking_Statement;

   procedure Analyze_Path
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Owner   : Node := Item.Parent;
      Stmt    : Libadalang.Analysis.If_Stmt;
      Mine    : Node;
      Theirs  : Node;
      Is_Else : Boolean := False;
   begin
      if Is_Null (Owner) then
         return;
      elsif Owner.Kind = Libadalang.Common.Ada_Else_Part then
         Owner := Owner.Parent;
         Is_Else := True;
      end if;

      if Is_Null (Owner)
        or else Owner.Kind /= Libadalang.Common.Ada_If_Stmt
      then
         return;
      end if;

      Stmt := Owner.As_If_Stmt;
      if Stmt.F_Alternatives.Children_Count > 0
        or else Is_Null (Stmt.F_Else_Part)
        or else (not Is_Else
                 and then Stmt.F_Then_Stmts.As_Ada_Node /= Item.As_Ada_Node)
      then
         return;
      end if;

      Mine := Last_Breaking_Statement (Item);
      Theirs := Last_Breaking_Statement
        (if Is_Else then Stmt.F_Then_Stmts.As_Ada_Node
         else Stmt.F_Else_Part.F_Stmts.As_Ada_Node);

      --  This path stays in the if statement while the other one leaves
      --  it, or both leave it in different ways (reported on the else).
      if (Is_Null (Mine) and then not Is_Null (Theirs))
        or else (not Is_Null (Mine) and then not Is_Null (Theirs)
                 and then Is_Else
                 and then Mine.Kind /= Theirs.Kind)
      then
         Report_Rule_Violation
           (Unit, Item, Nested_Path,
            "statements can be moved out of the if statement, whose other "
            & "path always leaves it");
      end if;
   end Analyze_Path;

   ------------------------------
   --  Exceptions and calls    --
   ------------------------------

   procedure Analyze_Local_Raise
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Name    : constant Libadalang.Analysis.Name :=
        Item.As_Raise_Stmt.F_Exception_Name;
      Owner   : constant Node := Enclosing_Body (Item);
      Raised  : Node;
      Handled : Boolean := False;

      function Is_Under
        (Candidate : Node; Limit : Node) return Boolean
      is
         Current : Node := Candidate;
      begin
         while not Is_Null (Current) and then not Is_Null (Current.Parent)
         loop
            if Current.Parent = Limit then
               return True;
            end if;
            Current := Current.Parent;
         end loop;
         return False;
      end Is_Under;

      procedure Visit (Candidate : Node) is
         Choices : Libadalang.Analysis.Alternatives_List;
         Handlers : Node;
         Matches  : Boolean := False;
      begin
         if Handled
           or else Candidate.Kind /= Libadalang.Common.Ada_Exception_Handler
         then
            return;
         end if;

         Choices := Candidate.As_Exception_Handler.F_Handled_Exceptions;
         for I in 1 .. Choices.Children_Count loop
            if Choices.Child (I).Kind =
                 Libadalang.Common.Ada_Others_Designator
              or else (Choices.Child (I).Kind =
                         Libadalang.Common.Ada_Identifier
                       and then Canonical_Exception (Choices.Child (I)) =
                                  Raised)
            then
               Matches := True;
            end if;
         end loop;

         --  The raise must be in the statements that the handler guards,
         --  not in one of the handlers of the same block.
         Handlers := Candidate.Parent;
         if Matches
           and then not Is_Null (Handlers)
           and then not Is_Null (Handlers.Parent)
           and then Is_Under (Item.As_Ada_Node, Handlers.Parent)
           and then not Is_Under (Item.As_Ada_Node, Handlers)
         then
            Handled := True;
         end if;
      end Visit;
   begin
      if Is_Null (Name)
        or else Is_Null (Owner)
        or else Owner.Kind not in Libadalang.Common.Ada_Base_Subp_Body
      then
         return;
      end if;

      Raised := Canonical_Exception (Name);
      For_Each_Below (Owner, Visit'Access);
      if Handled then
         Report_Rule_Violation
           (Unit, Item, Exception_As_Control_Flow,
            "raised exception is handled in the same subprogram body");
      end if;
   end Analyze_Local_Raise;

   procedure Analyze_Handler_Calls
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Forbidden : constant String :=
        Text_Parameter (Call_In_Exception_Handler, "subprograms");
      Found     : Boolean := False;

      procedure Visit (Candidate : Node) is
      begin
         if not Found
           and then Candidate.Kind in Libadalang.Common.Ada_Base_Id
           and then Candidate.As_Name.P_Is_Call
           and then Is_Listed (Denoted_Name (Candidate), Forbidden)
         then
            Found := True;
         end if;
      exception
         when others =>
            null;
      end Visit;
   begin
      if Forbidden = "" then
         return;
      end if;

      For_Each_Below (Item.As_Exception_Handler.F_Stmts, Visit'Access);
      if Found then
         Report_Rule_Violation
           (Unit, Item, Call_In_Exception_Handler,
            "exception handler calls a forbidden subprogram");
      end if;
   end Analyze_Handler_Calls;

   ------------------------------
   --  Subprogram shape        --
   ------------------------------

   function Is_Limited_Type
     (Type_Decl : Libadalang.Analysis.Base_Type_Decl) return Boolean
   is
      Def : Libadalang.Analysis.Type_Def;
   begin
      if Is_Null (Type_Decl)
        or else Type_Decl.Kind not in Libadalang.Common.Ada_Type_Decl
      then
         return False;
      end if;

      Def := Type_Decl.As_Type_Decl.F_Type_Def;
      if Is_Null (Def) then
         return False;
      end if;

      case Def.Kind is
         when Libadalang.Common.Ada_Derived_Type_Def =>
            return Def.As_Derived_Type_Def.F_Has_Limited.P_As_Bool;
         when Libadalang.Common.Ada_Private_Type_Def =>
            return Def.As_Private_Type_Def.F_Has_Limited.P_As_Bool;
         when Libadalang.Common.Ada_Record_Type_Def =>
            return Def.As_Record_Type_Def.F_Has_Limited.P_As_Bool;
         when Libadalang.Common.Ada_Interface_Type_Def =>
            return not Is_Null (Def.As_Interface_Type_Def.F_Interface_Kind)
              and then Def.As_Interface_Type_Def.F_Interface_Kind.Kind =
                         Libadalang.Common.Ada_Interface_Kind_Limited;
         when others =>
            return False;
      end case;
   end Is_Limited_Type;

   procedure Analyze_Procedure_Profile
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind   : constant Node_Kind := Item.Kind;
      Spec   : Libadalang.Analysis.Subp_Spec;
      Output : Libadalang.Analysis.Param_Spec :=
        Libadalang.Analysis.No_Param_Spec;
      Outputs : Natural := 0;
   begin
      if Kind = Libadalang.Common.Ada_Subp_Body then
         Spec := Item.As_Subp_Body.F_Subp_Spec;
      elsif Kind = Libadalang.Common.Ada_Subp_Body_Stub then
         Spec := Item.As_Subp_Body_Stub.F_Subp_Spec;
      elsif Kind = Libadalang.Common.Ada_Generic_Subp_Internal then
         Spec := Item.As_Generic_Subp_Internal.F_Subp_Spec;
      else
         Spec := Item.As_Classic_Subp_Decl.F_Subp_Spec;
      end if;

      if Spec.F_Subp_Kind.Kind /= Libadalang.Common.Ada_Subp_Kind_Procedure
        or else Is_Null (Spec.F_Subp_Params)
      then
         return;
      end if;

      for I in 1 .. Spec.F_Subp_Params.F_Params.Children_Count loop
         declare
            Param : constant Libadalang.Analysis.Param_Spec :=
              Spec.F_Subp_Params.F_Params.Child (I).As_Param_Spec;
         begin
            if Param.F_Mode.Kind = Libadalang.Common.Ada_Mode_In_Out then
               return;
            elsif Param.F_Mode.Kind = Libadalang.Common.Ada_Mode_Out then
               Outputs := Outputs + 1;
               Output := Param;
            end if;
         end;
      end loop;

      if Outputs /= 1 or else Output.F_Ids.Children_Count /= 1 then
         return;
      end if;

      if Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Subp_Body_Stub
        and then not Is_Null (Item.As_Body_Node.P_Previous_Part)
      then
         return;
      end if;

      declare
         Global : constant Libadalang.Analysis.Expr :=
           Item.As_Basic_Decl.P_Get_Aspect_Spec_Expr (Aspect_Name ("Global"));
      begin
         if (Is_Null (Global)
             or else Global.Kind = Libadalang.Common.Ada_Null_Literal)
           and then not Is_Limited_Type
                          (Output.F_Type_Expr.P_Designated_Type_Decl)
         then
            Report_Rule_Violation
              (Unit, Item, Function_Style_Procedure,
               "procedure with a single out parameter can be a function");
         end if;
      end;
   end Analyze_Procedure_Profile;

   --  The body that implements the inlined entity Item, when it is a
   --  subprogram body.
   function Implementing_Body
     (Item : Libadalang.Analysis.Ada_Node'Class) return Node
   is
      Result : Node;
   begin
      if Item.Kind = Libadalang.Common.Ada_Subp_Body then
         return Item.As_Ada_Node;
      elsif Item.Kind = Libadalang.Common.Ada_Subp_Renaming_Decl then
         Result := Referenced
           (Item.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object);
         if Is_Null (Result) then
            return Result;
         elsif Result.Kind in Libadalang.Common.Ada_Base_Subp_Body then
            return Result;
         end if;
         return Result.As_Basic_Decl.P_Body_Part_For_Decl.As_Ada_Node;
      else
         return Item.As_Generic_Subp_Instantiation.P_Designated_Generic_Decl
           .As_Basic_Decl.P_Body_Part_For_Decl.As_Ada_Node;
      end if;
   end Implementing_Body;

   procedure Analyze_Inlined_Subprogram
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Limit   : constant Natural :=
        Config.Rule_Parameter (Complex_Inlined_Subprogram, "n", 5);
      Target  : Node;
      Complex : Boolean := False;
      Reason  : Natural := 0;

      procedure Visit_Declaration (Candidate : Node) is
      begin
         if Candidate.Kind in Libadalang.Common.Ada_Subp_Body
              | Libadalang.Common.Ada_Package_Decl
              | Libadalang.Common.Ada_Task_Body
              | Libadalang.Common.Ada_Protected_Body
              | Libadalang.Common.Ada_Generic_Package_Instantiation
              | Libadalang.Common.Ada_Generic_Subp_Instantiation
         then
            Complex := True;
            Reason := 1;
         end if;
      end Visit_Declaration;

      procedure Visit_Statement (Candidate : Node) is
      begin
         if Candidate.Kind in Libadalang.Common.Ada_Base_Loop_Stmt
              | Libadalang.Common.Ada_Case_Stmt
              | Libadalang.Common.Ada_If_Stmt
         then
            Complex := True;
            Reason := 2;
         end if;
      end Visit_Statement;
   begin
      if not Has_Aspect (Item.As_Basic_Decl, "Inline") then
         return;
      end if;

      Target := Implementing_Body (Item);
      if Is_Null (Target)
        or else Target.Kind /= Libadalang.Common.Ada_Subp_Body
      then
         return;
      end if;

      For_Each_Below (Target.As_Subp_Body.F_Decls, Visit_Declaration'Access);
      if not Complex then
         For_Each_Below (Target.As_Subp_Body.F_Stmts, Visit_Statement'Access);
      end if;

      if not Complex then
         declare
            Stmts : constant Libadalang.Analysis.Stmt_List :=
              Target.As_Subp_Body.F_Stmts.F_Stmts;
            Total : Natural := 0;
         begin
            for I in 1 .. Stmts.Children_Count loop
               if Stmts.Child (I).Kind in Libadalang.Common.Ada_Stmt then
                  Total := Total + 1;
               end if;
            end loop;
            Complex := Total > Limit;
         end;
      end if;

      if Complex then
         Report_Rule_Violation
           (Unit,
            (if Item.Kind = Libadalang.Common.Ada_Subp_Renaming_Decl
             then Target else Item.As_Ada_Node),
            Complex_Inlined_Subprogram,
            (case Reason is
                when 1      => "inlined subprogram has a complex declaration",
                when 2      => "inlined subprogram has branching or a loop",
                when others => "inlined subprogram has too many statements"));
      end if;
   end Analyze_Inlined_Subprogram;

   function Is_Subprogram_Body (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Base_Subp_Body);

   procedure Analyze_Instantiation_Place
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Root : constant Node := Unit.Root;
      Body_Node : Node;
   begin
      if Is_Null (Root)
        or else Root.Kind /= Libadalang.Common.Ada_Compilation_Unit
      then
         return;
      end if;

      Body_Node := Root.As_Compilation_Unit.F_Body;
      if (Body_Node.Kind = Libadalang.Common.Ada_Library_Item
          and then Body_Node.As_Library_Item.F_Item.Kind in
                     Libadalang.Common.Ada_Generic_Package_Decl
                     | Libadalang.Common.Ada_Base_Package_Decl)
        or else Has_Ancestor (Item, Is_Subprogram_Body'Access)
      then
         Report_Rule_Violation
           (Unit, Item.As_Basic_Decl.P_Defining_Name,
            Improperly_Located_Instantiation,
            (if Has_Ancestor (Item, Is_Subprogram_Body'Access)
             then "instantiation in a subprogram body"
             else "instantiation in a library package specification"));
      end if;
   end Analyze_Instantiation_Place;

   --------------------------
   --  Language subsets    --
   --------------------------

   function Is_SPARK_Attribute (Name : String) return Boolean is
      Allowed : constant String :=
        " adjacent aft base ceiling component_size compose copy_sign delta"
        & " denorm digits exponent first floor fore fraction last"
        & " leading_part length machine machine_emax machine_emin"
        & " machine_mantissa machine_overflows machine_radix machine_rounds"
        & " max min model model_emin model_epsilon model_mantissa"
        & " model_small modulus pos pred range remainder rounding safe_first"
        & " safe_last scaling signed_zeros size small succ truncation"
        & " unbiased_rounding val valid ";
   begin
      return Ada.Strings.Fixed.Index (Allowed, " " & Name & " ") > 0;
   end Is_SPARK_Attribute;

   function Is_Protected_Body (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Protected_Body);

   function Is_Parameter (Kind : Node_Kind) return Boolean
   is (Kind = Libadalang.Common.Ada_Param_Spec);

   function Is_Formal_Subprogram (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Formal_Subp_Decl);

   function Is_Generic_Unit (Kind : Node_Kind) return Boolean
   is (Kind in Libadalang.Common.Ada_Generic_Decl);

   function Is_Ada_2022_Construct
     (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Kind : constant Node_Kind := Item.Kind;

      function Is_Iterated (Candidate : Node) return Boolean
      is (Candidate.Kind = Libadalang.Common.Ada_Iterated_Assoc);

      Found : Boolean := False;

      procedure Visit (Candidate : Node) is
      begin
         if Is_Iterated (Candidate) then
            Found := True;
         end if;
      end Visit;
   begin
      if Kind in Libadalang.Common.Ada_Reduce_Attribute_Ref
           | Libadalang.Common.Ada_Decl_Expr
           | Libadalang.Common.Ada_Target_Name
           | Libadalang.Common.Ada_Delta_Aggregate
      then
         return True;
      elsif Kind = Libadalang.Common.Ada_Attribute_Ref then
         if Canonical_Text (Item.As_Attribute_Ref.F_Attribute) /= "image" then
            return False;
         end if;

         declare
            Prefix_Type : constant Libadalang.Analysis.Base_Type_Decl :=
              Item.As_Attribute_Ref.F_Prefix.P_Expression_Type;
         begin
            return not Is_Null (Prefix_Type)
              and then not Prefix_Type.P_Is_Scalar_Type;
         end;
      elsif Kind in Libadalang.Common.Ada_Aggregate
              | Libadalang.Common.Ada_Bracket_Aggregate
      then
         For_Each_Below (Item, Visit'Access);
         return Found;
      elsif Kind in Libadalang.Common.Ada_Expr_Function
              | Libadalang.Common.Ada_Null_Subp_Decl
      then
         return Has_Ancestor (Item, Is_Protected_Body'Access);
      elsif Kind = Libadalang.Common.Ada_Aspect_Spec then
         return Has_Ancestor (Item, Is_Parameter'Access);
      elsif Kind = Libadalang.Common.Ada_Aspect_Assoc then
         declare
            Name : constant String :=
              Canonical_Text (Item.As_Aspect_Assoc.F_Id);
         begin
            return Name = "string_literal" or else Name = "integer_literal"
              or else Name = "real_literal"
              or else ((Name = "pre" or else Name = "post")
                       and then Has_Ancestor
                                  (Item, Is_Formal_Subprogram'Access));
         end;
      end if;
      return False;
   end Is_Ada_2022_Construct;

   function Is_In_Ghost_Code
     (Item : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Node := Item.Parent;
   begin
      while not Is_Null (Current) loop
         begin
            if (Current.Kind in Libadalang.Common.Ada_Basic_Decl
                and then Current.As_Basic_Decl.P_Is_Ghost_Code)
              or else (Current.Kind = Libadalang.Common.Ada_Pragma_Node
                       and then Current.As_Pragma_Node.P_Is_Ghost_Code)
              or else (Current.Kind = Libadalang.Common.Ada_Aspect_Assoc
                       and then Current.As_Aspect_Assoc.P_Is_Ghost_Code)
            then
               return True;
            end if;
         exception
            when others =>
               null;
         end;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_In_Ghost_Code;

   procedure Analyze_Ada_2022
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      if Is_Ada_2022_Construct (Item)
        and then not Has_Ancestor (Item, Is_Generic_Unit'Access)
        and then not Is_In_Ghost_Code (Item)
      then
         Report_Rule_Violation
           (Unit, Item, Ada_2022_In_Ghost_Code,
            "Ada 2022 construct used outside ghost code");
      end if;
   end Analyze_Ada_2022;

   --  Actual_Parameter: the forbidden parameter lists triples
   --  "subprogram:formal:object", each by fully qualified name; an object
   --  that starts with "|" matches any object whose name contains the
   --  rest.
   procedure Analyze_Actuals
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Item : Libadalang.Analysis.Ada_Node'Class)
   is
      Forbidden : constant String :=
        Text_Parameter (Actual_Parameter, "forbidden");
      Call      : Libadalang.Analysis.Call_Expr;
      Start     : Positive := Forbidden'First;

      function Strip (Actual : Node) return Node is
      begin
         if Actual.Kind = Libadalang.Common.Ada_Paren_Expr then
            return Strip (Actual.As_Paren_Expr.F_Expr.As_Ada_Node);
         elsif Actual.Kind = Libadalang.Common.Ada_Qual_Expr then
            return Strip (Actual.As_Qual_Expr.F_Suffix.As_Ada_Node);
         elsif Actual.Kind = Libadalang.Common.Ada_Call_Expr
           and then not Is_Null (Referenced (Actual.As_Call_Expr.F_Name))
           and then Referenced (Actual.As_Call_Expr.F_Name).Kind in
                      Libadalang.Common.Ada_Base_Type_Decl
           and then Actual.As_Call_Expr.F_Suffix.Children_Count > 0
         then
            return Strip
              (Actual.As_Call_Expr.F_Suffix.Child (1).As_Param_Assoc.F_R_Expr
                 .As_Ada_Node);
         end if;
         return Actual;
      end Strip;

      function Matches (Triple : String) return Boolean is
         First  : constant Natural := Ada.Strings.Fixed.Index (Triple, ":");
         Second : Natural;
      begin
         if First = 0 then
            return False;
         end if;
         Second := Ada.Strings.Fixed.Index
           (Triple (First + 1 .. Triple'Last), ":");
         if Second = 0
           or else Lower (Triple (Triple'First .. First - 1)) /=
                     Denoted_Name (Call.F_Name)
         then
            return False;
         end if;

         declare
            Formal : constant String := Lower (Triple (First + 1 .. Second - 1));
            Wanted : constant String := Lower (Triple (Second + 1 .. Triple'Last));
         begin
            for Pair of Call.P_Call_Params loop
               if Lower (Node_Text (Libadalang.Analysis.Param (Pair))) = Formal
               then
                  declare
                     Actual : constant Node :=
                       Strip (Libadalang.Analysis.Actual (Pair).As_Ada_Node);
                     Decl   : constant Node := Referenced (Actual);
                     Name   : constant String := Denoted_Name (Actual);
                  begin
                     if not Is_Null (Decl)
                       and then Decl.Kind in
                                  Libadalang.Common.Ada_Object_Decl_Range
                                  | Libadalang.Common.Ada_Number_Decl
                                  | Libadalang.Common.Ada_Param_Spec
                                  | Libadalang.Common.Ada_Generic_Formal_Obj_Decl
                                  | Libadalang.Common.Ada_Base_Subp_Body
                                  | Libadalang.Common.Ada_Basic_Subp_Decl
                       and then Name /= ""
                       and then (if Wanted'Length > 1
                                   and then Wanted (Wanted'First) = '|'
                                 then Ada.Strings.Fixed.Index
                                        (Name,
                                         Wanted (Wanted'First + 1 ..
                                                 Wanted'Last)) > 0
                                 else Name = Wanted)
                     then
                        return True;
                     end if;
                  end;
               end if;
            end loop;
         end;
         return False;
      end Matches;
   begin
      if Forbidden = ""
        or else Is_Null (Item.Parent)
        or else Item.Parent.Kind /= Libadalang.Common.Ada_Call_Expr
        or else not Item.Parent.As_Call_Expr.P_Is_Call
      then
         return;
      end if;
      Call := Item.Parent.As_Call_Expr;

      for I in Forbidden'First .. Forbidden'Last + 1 loop
         if I > Forbidden'Last or else Forbidden (I) = ',' then
            if Matches
                 (Ada.Strings.Fixed.Trim
                    (Forbidden (Start .. I - 1), Ada.Strings.Both))
            then
               Report_Rule_Violation
                 (Unit, Item, Actual_Parameter,
                  "forbidden object passed as actual parameter");
               return;
            end if;
            Start := I + 1;
         end if;
      end loop;
   end Analyze_Actuals;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Node_Kind := Node.Kind;
   begin
      Guarded (Unit, Node, On (Ada_2022_In_Ghost_Code), Analyze_Ada_2022'Access);

      if Kind in Libadalang.Common.Ada_Expr
        and then On (Maximum_Expression_Complexity)
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind not in Libadalang.Common.Ada_Expr
        and then Kind not in Libadalang.Common.Ada_Identifier
                   | Libadalang.Common.Ada_Defining_Name
                   | Libadalang.Common.Ada_End_Name
      then
         Guarded (Unit, Node, True, Analyze_Expression_Size'Access);
      end if;

      if Kind = Libadalang.Common.Ada_Attribute_Ref then
         if On (Non_SPARK_Attribute)
           and then not Is_SPARK_Attribute
                          (Canonical_Text (Node.As_Attribute_Ref.F_Attribute))
         then
            Report_Rule_Violation
              (Unit, Node, Non_SPARK_Attribute,
               "attribute "
               & Node_Text (Node.As_Attribute_Ref.F_Attribute)
               & " is not in the SPARK 2005 subset");
         end if;
      elsif Kind = Libadalang.Common.Ada_Stmt_List then
         Guarded (Unit, Node, On (Nested_Path), Analyze_Path'Access);
      elsif Kind = Libadalang.Common.Ada_Raise_Stmt then
         Guarded
           (Unit, Node, On (Exception_As_Control_Flow),
            Analyze_Local_Raise'Access);
      elsif Kind = Libadalang.Common.Ada_Exception_Handler then
         Guarded
           (Unit, Node, On (Call_In_Exception_Handler),
            Analyze_Handler_Calls'Access);
      elsif Kind = Libadalang.Common.Ada_Assoc_List then
         Guarded (Unit, Node, On (Actual_Parameter), Analyze_Actuals'Access);
      elsif Kind in Libadalang.Common.Ada_Generic_Instantiation then
         Guarded
           (Unit, Node, On (Improperly_Located_Instantiation),
            Analyze_Instantiation_Place'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Subp_Body_Stub
           | Libadalang.Common.Ada_Classic_Subp_Decl
           | Libadalang.Common.Ada_Generic_Subp_Internal
      then
         Guarded
           (Unit, Node, On (Function_Style_Procedure),
            Analyze_Procedure_Profile'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Generic_Subp_Instantiation
           | Libadalang.Common.Ada_Subp_Renaming_Decl
      then
         Guarded
           (Unit, Node, On (Complex_Inlined_Subprogram),
            Analyze_Inlined_Subprogram'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Base_Subp_Body
        and then On (Essential_Complexity)
      then
         begin
            declare
               Limit : constant Natural :=
                 Config.Rule_Parameter (Essential_Complexity, "n", 3);
               Value : constant Natural := Essential_Complexity (Node);
            begin
               if Value > Limit then
                  Report_Rule_Violation
                    (Unit, Node, Essential_Complexity,
                     "essential complexity " & To_Decimal (Value)
                     & " exceeds " & To_Decimal (Limit));
               end if;
            end;
         exception
            when Exc : others =>
               Note_Skipped_Check (Node, Exc);
         end;
      end if;
   end Analyze_Node;

end Adalang_Analyzer.Checks.Flow_Policy;
