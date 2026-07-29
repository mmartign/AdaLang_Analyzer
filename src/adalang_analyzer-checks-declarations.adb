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

with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Exceptions;
with Ada.Strings.Hash;
with Ada.Unchecked_Deallocation;

with Langkit_Support.Errors;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;      use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Data_Flow;
with Adalang_Analyzer.Config;        use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Interp;
with Adalang_Analyzer.Report;        use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;         use Adalang_Analyzer.Rules;
with Adalang_Analyzer.SPARK_Dependency_Analysis;
with Adalang_Analyzer.SPARK_Readiness;
with Adalang_Analyzer.Text_Utils;    use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks.Declarations is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Adalang_Analyzer.Checks.Data_Flow.Access_Kind;

   package Identifier_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   type Scope_Record;
   type Scope_Access is access Scope_Record;
   type Scope_Record is record
      Names : Identifier_Sets.Set;
      Outer : Scope_Access;
   end record;

   Current_Scope : Scope_Access;

   procedure Free is new Ada.Unchecked_Deallocation
     (Object => Scope_Record, Name => Scope_Access);

   function Opens_Shadowing_Scope
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
     (Node.Kind in Libadalang.Common.Ada_Subp_Body
        | Libadalang.Common.Ada_Decl_Block
        | Libadalang.Common.Ada_Package_Body);

   procedure Begin_Traversal is
      Old_Scope : Scope_Access;
   begin
      while Current_Scope /= null loop
         Old_Scope := Current_Scope;
         Current_Scope := Current_Scope.Outer;
         Free (Old_Scope);
      end loop;
   end Begin_Traversal;

   procedure Enter_Node (Node : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Opens_Shadowing_Scope (Node) then
         Current_Scope := new Scope_Record'
           (Names => Identifier_Sets.Empty_Set, Outer => Current_Scope);
      end if;
   end Enter_Node;

   procedure Leave_Node (Node : Libadalang.Analysis.Ada_Node'Class) is
      Old_Scope : Scope_Access;
   begin
      if Opens_Shadowing_Scope (Node) and then Current_Scope /= null then
         Old_Scope := Current_Scope;
         Current_Scope := Current_Scope.Outer;
         Free (Old_Scope);
      end if;
   end Leave_Node;

   procedure Register_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Current_Scope = null then
         return;
      elsif Node.Kind = Libadalang.Common.Ada_Object_Decl then
         for Id of Node.As_Object_Decl.F_Ids loop
            Current_Scope.Names.Include (Canonical_Text (Id));
         end loop;
      elsif Node.Kind = Libadalang.Common.Ada_Param_Spec then
         for Id of Node.As_Param_Spec.F_Ids loop
            Current_Scope.Names.Include (Canonical_Text (Id));
         end loop;
      end if;
   end Register_Declaration;

   --  True when some identifier under Node both spells Identifier and
   --  resolves to Decl. The text comparison is checked first (cheap) so
   --  that the semantic resolution call only runs on plausible matches.
   --  Shared by Unused_Parameter (Decl is the parameter's Param_Spec) and
   --  Unused_Variable (Decl is the local object's Object_Decl); matching by
   --  spelling first lets it correctly tell apart names declared together
   --  in one multi-name declaration, which all share the same Basic_Decl.
   function References_Named_Declaration
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Decl       : Libadalang.Analysis.Basic_Decl;
      Identifier : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Identifier
        and then Canonical_Text (Node) = Identifier
      then
         declare
            Referenced : constant Libadalang.Analysis.Basic_Decl :=
              Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
         begin
            --  Use the declaration named directly in the source, rather than
            --  the canonical storage object used by the data-flow checks. A
            --  write through an object rename is a use of the rename itself.
            --  When Libadalang cannot resolve a name in an otherwise valid
            --  unit, conservatively treat the matching spelling as a use.
            return Libadalang.Analysis.Is_Null (Referenced)
              or else Referenced = Decl;
         end;
      end if;

      for I in 1 .. Node.Children_Count loop
         if References_Named_Declaration (Node.Child (I), Decl, Identifier) then
            return True;
         end if;
      end loop;

      return False;
   exception
      when others =>
         --  Mirrors the conservative fallback above: an identifier whose
         --  resolution outright raises, rather than returning null, is
         --  still treated as a use rather than silently propagating and
         --  discarding every other check for the enclosing subprogram.
         return True;
   end References_Named_Declaration;

   --  The current scope is deliberately skipped: this rule only diagnoses
   --  hiding across a lexical-scope boundary. Each lookup visits the usually
   --  tiny scope stack and performs an O(1) hashed-set query at every level.
   function Shadows_Enclosing_Declaration (Name : String) return Boolean is
      Scope : Scope_Access :=
        (if Current_Scope = null then null else Current_Scope.Outer);
   begin
      while Scope /= null loop
         if Scope.Names.Contains (Name) then
            return True;
         end if;
         Scope := Scope.Outer;
      end loop;
      return False;
   end Shadows_Enclosing_Declaration;

   --  Sums the decision points in Node's subtree (if/elsif, loops,
   --  exception handlers each add 1, an N-way case adds N-1, and each
   --  short-circuit "and then"/"or else" adds 1), the standard count of
   --  independent paths added to a base complexity of 1 per subprogram.
   --  A nested subprogram body stops the walk and contributes 0, since it
   --  is scored separately when Analyze_Subprogram visits it in turn.
   function Cyclomatic_Value
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Result : Natural := 0;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return 0;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_If_Stmt
            | Libadalang.Common.Ada_Elsif_Stmt_Part
            | Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_Exception_Handler =>
            Result := 1;

         when Libadalang.Common.Ada_Case_Stmt =>
            declare
               Count : constant Natural :=
                 Node.As_Case_Stmt.F_Alternatives.Children_Count;
            begin
               if Count > 0 then
                  Result := Count - 1;
               end if;
            end;

         when Libadalang.Common.Ada_Bin_Op =>
            if Node.As_Bin_Op.F_Op in
              Libadalang.Common.Ada_Op_And_Then
                | Libadalang.Common.Ada_Op_Or_Else
            then
               Result := 1;
            end if;

         when Libadalang.Common.Ada_Subp_Body =>
            --  A nested subprogram has its own independent complexity score.
            return 0;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         Result := Result + Cyclomatic_Value (Node.Child (I));
      end loop;

      return Result;
   end Cyclomatic_Value;

   --  Deepest control-flow nesting level reached under Node, starting from
   --  Depth. If, case, loop, extended-return, and declare-block statements
   --  each add one level; elsif/else parts share their enclosing if
   --  statement's level rather than adding their own. A nested subprogram
   --  body stops the walk (it is scored separately in its own
   --  Analyze_Subprogram call), matching Cyclomatic_Value's scoping.
   function Max_Nesting_Depth
     (Node : Libadalang.Analysis.Ada_Node'Class; Depth : Natural) return Natural
   is
      Result      : Natural := Depth;
      Child_Depth : Natural := Depth;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Depth;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Subp_Body then
         return Depth;
      end if;

      if Node.Kind in Libadalang.Common.Ada_If_Stmt
           | Libadalang.Common.Ada_Case_Stmt
           | Libadalang.Common.Ada_For_Loop_Stmt
           | Libadalang.Common.Ada_While_Loop_Stmt
           | Libadalang.Common.Ada_Loop_Stmt
           | Libadalang.Common.Ada_Extended_Return_Stmt
           | Libadalang.Common.Ada_Decl_Block
      then
         Child_Depth := Depth + 1;
      end if;

      for I in 1 .. Node.Children_Count loop
         declare
            Sub_Depth : constant Natural :=
              Max_Nesting_Depth (Node.Child (I), Child_Depth);
         begin
            if Sub_Depth > Result then
               Result := Sub_Depth;
            end if;
         end;
      end loop;

      return Result;
   end Max_Nesting_Depth;

   --  Number of return statements under Node, not descending into a nested
   --  subprogram body (its own returns belong to that subprogram, not the
   --  one being counted here). Backs No_Multiple_Return.
   function Count_Return_Statements
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Result : Natural := 0;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return 0;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt =>
            Result := 1;

         when Libadalang.Common.Ada_Subp_Body =>
            return 0;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         Result := Result + Count_Return_Statements (Node.Child (I));
      end loop;

      return Result;
   end Count_Return_Statements;

   function Parameter_Name_Matches
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Param : Libadalang.Analysis.Param_Spec;
      Name  : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
        or else Canonical_Text (Node) /= Name
      then
         return False;
      end if;

      declare
         Referenced : constant Libadalang.Analysis.Basic_Decl :=
           Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      begin
         return Libadalang.Analysis.Is_Null (Referenced)
           or else Referenced = Libadalang.Analysis.Basic_Decl (Param)
           or else Referenced.P_Canonical_Part
             (Imprecise_Fallback => True) =
               Libadalang.Analysis.Basic_Decl (Param).P_Canonical_Part
                 (Imprecise_Fallback => True)
           or else Referenced.Kind in Libadalang.Common.Ada_Param_Spec_Range;
      end;
   exception
      when others =>
         return True;
   end Parameter_Name_Matches;

   function Contains_Parameter_Reference
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Param : Libadalang.Analysis.Param_Spec;
      Name  : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Parameter_Name_Matches (Node, Param, Name) then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if Contains_Parameter_Reference (Node.Child (I), Param, Name) then
            return True;
         end if;
      end loop;
      return False;
   end Contains_Parameter_Reference;

   function Association_Uses_Parameter_Mode
     (Assoc    : Libadalang.Analysis.Param_Assoc;
      Param    : Libadalang.Analysis.Param_Spec;
      Name     : String;
      For_Read : Boolean) return Boolean
   is
      Found_Formal : Boolean := False;
   begin
      if not Contains_Parameter_Reference
        (Assoc.F_R_Expr, Param, Name)
      then
         return False;
      end if;

      for Formal_Name of
        Assoc.P_Get_Params (Imprecise_Fallback => True)
      loop
         declare
            Ancestor : Libadalang.Analysis.Ada_Node := Formal_Name.Parent;
         begin
            while not Libadalang.Analysis.Is_Null (Ancestor)
              and then Ancestor.Kind not in
                Libadalang.Common.Ada_Param_Spec_Range
            loop
               Ancestor := Ancestor.Parent;
            end loop;

            if not Libadalang.Analysis.Is_Null (Ancestor) then
               Found_Formal := True;
               if For_Read
                 and then Ancestor.As_Param_Spec.F_Mode.Kind not in
                   Libadalang.Common.Ada_Mode_Out_Range
               then
                  return True;
               elsif not For_Read
                 and then Ancestor.As_Param_Spec.F_Mode.Kind in
                   Libadalang.Common.Ada_Mode_Out_Range
                     | Libadalang.Common.Ada_Mode_In_Out_Range
               then
                  return True;
               end if;
            end if;
         end;
      end loop;

      --  An unresolved profile is not enough evidence to recommend a mode
      --  change. Conservatively classify the actual as both read and written.
      return not Found_Formal;
   exception
      when others =>
         return True;
   end Association_Uses_Parameter_Mode;

   function Call_Uses_Parameter_Mode
     (Node     : Libadalang.Analysis.Ada_Node'Class;
      Param    : Libadalang.Analysis.Param_Spec;
      Name     : String;
      For_Read : Boolean) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Param_Assoc then
         return Association_Uses_Parameter_Mode
           (Node.As_Param_Assoc, Param, Name, For_Read);
      end if;

      for I in 1 .. Node.Children_Count loop
         if Call_Uses_Parameter_Mode
           (Node.Child (I), Param, Name, For_Read)
         then
            return True;
         end if;
      end loop;
      return False;
   end Call_Uses_Parameter_Mode;

   function Parameter_Is_Read
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Param : Libadalang.Analysis.Param_Spec;
      Name  : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         declare
            Stmt : constant Libadalang.Analysis.Assign_Stmt :=
              Node.As_Assign_Stmt;
         begin
            if Parameter_Is_Read (Stmt.F_Expr, Param, Name) then
               return True;
            elsif Stmt.F_Dest.Kind = Libadalang.Common.Ada_Call_Expr then
               return Parameter_Is_Read
                 (Stmt.F_Dest.As_Call_Expr.F_Suffix, Param, Name);
            elsif Stmt.F_Dest.Kind /= Libadalang.Common.Ada_Identifier then
               return Parameter_Is_Read (Stmt.F_Dest, Param, Name);
            end if;
            return False;
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
         return Call_Uses_Parameter_Mode
             (Node.As_Call_Expr.F_Suffix, Param, Name, For_Read => True)
           or else
             (Node.Parent.Kind = Libadalang.Common.Ada_Call_Stmt
              and then Contains_Parameter_Reference
                (Node.As_Call_Expr.F_Name, Param, Name));
      elsif Parameter_Name_Matches (Node, Param, Name) then
         return True;
      end if;

      for I in 1 .. Node.Children_Count loop
         if Parameter_Is_Read (Node.Child (I), Param, Name) then
            return True;
         end if;
      end loop;
      return False;
   end Parameter_Is_Read;

   --  Whether Param is the object an assignment destination ultimately
   --  writes: only the base object a selector/index/dereference chain
   --  reaches is written, not any index, slice bound, or selector suffix
   --  used along the way to reach it (those are reads, and the read-side
   --  walker separately accounts for them). Writing State.Field or
   --  State (Index) writes State even though the destination as a whole is
   --  not the parameter identifier; conversely, writing Arr (Idx) does not
   --  write Idx, even though Idx's own text appears inside Dest. A
   --  destination shape this doesn't specifically recognize (e.g. a slice)
   --  falls back to the older, broader "appears anywhere in Dest" test.
   function Write_Target_Contains_Parameter
     (Dest  : Libadalang.Analysis.Ada_Node'Class;
      Param : Libadalang.Analysis.Param_Spec;
      Name  : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Dest) then
         return False;
      end if;

      case Dest.Kind is
         when Libadalang.Common.Ada_Identifier =>
            return Parameter_Name_Matches (Dest, Param, Name);

         when Libadalang.Common.Ada_Dotted_Name =>
            return Write_Target_Contains_Parameter
              (Dest.As_Dotted_Name.F_Prefix, Param, Name);

         when Libadalang.Common.Ada_Call_Expr =>
            --  Array indexing or slicing: only the prefix identifies the
            --  object being written. The suffix holds index or slice-bound
            --  expressions, which merely read whatever they reference.
            return Write_Target_Contains_Parameter
              (Dest.As_Call_Expr.F_Name, Param, Name);

         when Libadalang.Common.Ada_Explicit_Deref =>
            return Write_Target_Contains_Parameter
              (Dest.As_Explicit_Deref.F_Prefix, Param, Name);

         when others =>
            return Contains_Parameter_Reference (Dest, Param, Name);
      end case;
   end Write_Target_Contains_Parameter;

   function Parameter_Is_Written
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Param : Libadalang.Analysis.Param_Spec;
      Name  : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
         declare
            Dest : constant Libadalang.Analysis.Name :=
              Node.As_Assign_Stmt.F_Dest;
         begin
            return Write_Target_Contains_Parameter (Dest, Param, Name);
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
         return Call_Uses_Parameter_Mode
             (Node.As_Call_Expr.F_Suffix, Param, Name, For_Read => False)
           or else
             (Node.Parent.Kind = Libadalang.Common.Ada_Call_Stmt
              and then Contains_Parameter_Reference
                (Node.As_Call_Expr.F_Name, Param, Name));
      elsif Node.Kind = Libadalang.Common.Ada_Call_Stmt
        and then Node.As_Call_Stmt.F_Call.Kind =
          Libadalang.Common.Ada_Dotted_Name
      then
         --  A parameterless prefixed procedure call has no Call_Expr node:
         --  Libadalang represents "Object.Clear;" as a bare dotted name.
         --  Treat the prefix like the controlling actual, consistently with
         --  the Call_Expr case above.
         return Contains_Parameter_Reference
           (Node.As_Call_Stmt.F_Call.As_Dotted_Name.F_Prefix, Param, Name);
      end if;

      for I in 1 .. Node.Children_Count loop
         if Parameter_Is_Written (Node.Child (I), Param, Name) then
            return True;
         end if;
      end loop;
      return False;
   end Parameter_Is_Written;

   --  Reports Unused_Variable for every local object declared directly in
   --  Decls that is referenced nowhere among its sibling declarations or
   --  within Stmts, then recurses into every nested declare block
   --  reachable through Stmts so a local declared inside one is checked
   --  too, not just a subprogram's own top-level declarations. Does not
   --  descend into a nested subprogram body: its own locals are checked
   --  independently when Analyze_Subprogram runs for it.
   procedure Check_Unused_Variables_In_Scope
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Decls : Libadalang.Analysis.Ada_Node'Class;
      Stmts : Libadalang.Analysis.Ada_Node'Class)
   is
      procedure Find_Nested_Decl_Blocks
        (Node : Libadalang.Analysis.Ada_Node'Class)
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Decl_Block then
            declare
               Block : constant Libadalang.Analysis.Decl_Block :=
                 Node.As_Decl_Block;
            begin
               Check_Unused_Variables_In_Scope
                 (Unit, Block.F_Decls.F_Decls, Block.F_Stmts);
            end;
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Subp_Body then
            return;
         end if;

         for I in 1 .. Node.Children_Count loop
            Find_Nested_Decl_Blocks (Node.Child (I));
         end loop;
      end Find_Nested_Decl_Blocks;
   begin
      for I in 1 .. Decls.Children_Count loop
         declare
            Item : constant Libadalang.Analysis.Ada_Node := Decls.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Item)
              and then Item.Kind = Libadalang.Common.Ada_Object_Decl
            then
               declare
                  Decl : constant Libadalang.Analysis.Object_Decl :=
                    Item.As_Object_Decl;
               begin
                  for Id of Decl.F_Ids loop
                     declare
                        Name : constant String := Canonical_Text (Id);
                        Basic : constant Libadalang.Analysis.Basic_Decl :=
                          Libadalang.Analysis.Basic_Decl (Decl);
                        Used_Elsewhere : Boolean := False;
                     begin
                        --  Scan sibling declarations only, skipping this
                        --  declaration's own node: it always contains Id's
                        --  defining occurrence, which would otherwise be
                        --  misread as a use of itself.
                        for J in 1 .. Decls.Children_Count loop
                           if J /= I
                             and then References_Named_Declaration
                               (Decls.Child (J), Basic, Name)
                           then
                              Used_Elsewhere := True;
                              exit;  --  adalang-analyzer: ignore No_Exit
                           end if;
                        end loop;

                        if not Used_Elsewhere
                          and then not References_Named_Declaration
                            (Stmts, Basic, Name)
                        then
                           Report_Rule_Violation
                             (Unit, Id, Unused_Variable,
                              "variable '" & Node_Text (Id) &
                                "' is never referenced");
                        end if;
                     end;
                  end loop;
               end;
            end if;
         end;
      end loop;

      Find_Nested_Decl_Blocks (Stmts);
   end Check_Unused_Variables_In_Scope;

   --  Reports Missing_Overriding_Indicator when Node genuinely overrides an
   --  inherited primitive (Overriding_Field_Value is anything other than
   --  the 'overriding' keyword itself). Resolving whether Node overrides
   --  anything requires semantic analysis that can fail on unresolved or
   --  non-primitive code, so any failure is treated the same as "does not
   --  override" rather than risking a false positive.
   procedure Check_Overriding_Indicator
     (Unit                    : Libadalang.Analysis.Analysis_Unit;
      Node                    : Libadalang.Analysis.Basic_Decl'Class;
      Spec                    : Libadalang.Analysis.Base_Subp_Spec'Class;
      Overriding_Field_Value  : Libadalang.Analysis.Overriding_Node)
   is
   begin
      if Overriding_Field_Value.Kind =
        Libadalang.Common.Ada_Overriding_Overriding
      then
         return;
      end if;

      --  Only primitives of tagged types can override another operation.
      --  Besides avoiding needless semantic work for ordinary helpers, this
      --  guards P_Base_Subp_Declarations from known Libadalang failures on
      --  profiles whose formal types are access-type aliases.
      if Libadalang.Analysis.Is_Null
        (Spec.P_Primitive_Subp_Tagged_Type (Imprecise_Fallback => True))
      then
         return;
      end if;

      declare
         Base : constant Libadalang.Analysis.Basic_Decl_Array :=
           Node.P_Base_Subp_Declarations (Imprecise_Fallback => True);
      begin
         if Base'Length > 1 then
            Report_Rule_Violation
              (Unit, Node, Missing_Overriding_Indicator,
               "subprogram overrides an inherited operation without the " &
               "'overriding' keyword");
         end if;
      end;
   exception
      when E : Langkit_Support.Errors.Property_Error =>
         --  Some otherwise valid profiles cannot be classified as tagged
         --  primitives by Libadalang (notably access-type aliases). An
         --  unresolved profile is not evidence of a missing indicator.
         Log_Verbose_Once
           ("Missing_Overriding_Indicator skipped unresolved profile at "
            & Safe_Filename (Unit) & ":"
            & To_Decimal (Natural (Node.Sloc_Range.Start_Line)) & ": "
            & Ada.Exceptions.Exception_Message (E));
      when E : others =>
         Report_Recoverable_Failure_Once
           (Rule       => "Missing_Overriding_Indicator",
            Operation  => "resolve overridden base declarations",
            Source     =>
              Safe_Filename (Unit) & ":"
              & To_Decimal (Natural (Node.Sloc_Range.Start_Line)),
            Occurrence => E);
   end Check_Overriding_Indicator;

   procedure Analyze_Subprogram  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Param_Count : Natural := 0;
   begin
      if Rule_States (Missing_Overriding_Indicator) = Enabled then
         Check_Overriding_Indicator
           (Unit, Subprogram, Subprogram.F_Subp_Spec,
            Subprogram.F_Overriding);
      end if;

      if Rule_States (Unused_Parameter) = Enabled
        or else Rule_States (Wrong_Parameter_Mode) = Enabled
        or else Rule_States (Too_Many_Parameters) = Enabled
      then
         for Param of Subprogram.F_Subp_Spec.P_Params loop
            for Id of Param.F_Ids loop
               Param_Count := Param_Count + 1;

               if Rule_States (Unused_Parameter) = Enabled then
                  declare
                     Name : constant String := Canonical_Text (Id);
                  begin
                     if not References_Named_Declaration
                       (Subprogram.F_Decls,
                        Libadalang.Analysis.Basic_Decl (Param), Name)
                       and then not References_Named_Declaration
                         (Subprogram.F_Stmts,
                          Libadalang.Analysis.Basic_Decl (Param), Name)
                     then
                        Report_Rule_Violation
                          (Unit, Id, Unused_Parameter,
                           "parameter '" & Node_Text (Id) &
                             "' is never referenced");
                     end if;
                  end;
               end if;

               if Rule_States (Wrong_Parameter_Mode) = Enabled
                 and then Param.F_Mode.Kind in
                   Libadalang.Common.Ada_Mode_In_Out_Range
               then
                  declare
                     Name : constant String := Canonical_Text (Id);
                     Is_Read : constant Boolean :=
                       Parameter_Is_Read (Subprogram.F_Decls, Param, Name)
                       or else Parameter_Is_Read
                         (Subprogram.F_Stmts, Param, Name);
                     Is_Written : constant Boolean :=
                       Parameter_Is_Written (Subprogram.F_Decls, Param, Name)
                       or else Parameter_Is_Written
                         (Subprogram.F_Stmts, Param, Name);
                  begin
                     if Is_Read and then not Is_Written then
                        Report_Rule_Violation
                          (Unit, Id, Wrong_Parameter_Mode,
                           "parameter '" & Node_Text (Id) &
                             "' is only read; use mode in");
                     elsif Is_Written and then not Is_Read then
                        Report_Rule_Violation
                          (Unit, Id, Wrong_Parameter_Mode,
                           "parameter '" & Node_Text (Id) &
                             "' is only written; use mode out");
                     end if;
                  end;
               end if;
            end loop;
         end loop;
      end if;

      if Rule_States (Too_Many_Parameters) = Enabled
        and then Param_Count > Parameter_Threshold
      then
         Report_Rule_Violation
           (Unit, Subprogram.F_Subp_Spec.P_Name, Too_Many_Parameters,
            "parameter count " & To_Decimal (Param_Count) &
              " exceeds threshold " & To_Decimal (Parameter_Threshold));
      end if;

      if Rule_States (Unused_Variable) = Enabled then
         Check_Unused_Variables_In_Scope
           (Unit, Subprogram.F_Decls.F_Decls, Subprogram.F_Stmts);
      end if;

      if Rule_States (Cyclomatic_Complexity) = Enabled then
         declare
            Complexity : constant Natural :=
              1 + Cyclomatic_Value (Subprogram.F_Stmts);
         begin
            if Complexity > Complexity_Threshold then
               Report_Rule_Violation
                 (Unit, Subprogram.F_Subp_Spec.P_Name,
                  Cyclomatic_Complexity,
                  "cyclomatic complexity " & To_Decimal (Complexity)
                  & " exceeds threshold " &
                    To_Decimal (Complexity_Threshold));
            end if;
         end;
      end if;

      if Rule_States (Deep_Nesting) = Enabled then
         declare
            Depth : constant Natural :=
              Max_Nesting_Depth (Subprogram.F_Stmts, 0);
         begin
            if Depth > Nesting_Threshold then
               Report_Rule_Violation
                 (Unit, Subprogram.F_Subp_Spec.P_Name, Deep_Nesting,
                  "nesting depth " & To_Decimal (Depth) &
                    " exceeds threshold " & To_Decimal (Nesting_Threshold));
            end if;
         end;
      end if;

      if Rule_States (No_Multiple_Return) = Enabled then
         declare
            Count : constant Natural :=
              Count_Return_Statements (Subprogram.F_Stmts);
         begin
            if Count > 1 then
               Report_Rule_Violation
                 (Unit, Subprogram.F_Subp_Spec.P_Name, No_Multiple_Return,
                  "subprogram has " & To_Decimal (Count) &
                    " return statements");
            end if;
         end;
      end if;

      --  Interpret_Subprogram_Flow itself no-ops unless a flow-sensitive or
      --  contract-aware rule is enabled, so the guard lives there.
      SPARK_Readiness.Analyze_Subprogram (Unit, Subprogram);
      SPARK_Dependency_Analysis.Analyze_Subprogram (Unit, Subprogram);
      Flow_Interp.Interpret_Subprogram_Flow (Unit, Subprogram);
   end Analyze_Subprogram;

   --  Whether Decl's type is scalar (an integer, floating-point,
   --  fixed-point, or enumeration type). Only scalar types have no defined
   --  default value in Ada -- a just-declared access value is null, and a
   --  composite/private/tagged type such as a container is default
   --  initialized to its own well-defined initial state -- so reading any
   --  of those before an explicit assignment is not a bug the way reading
   --  an uninitialized scalar is. Resolution failure is treated as "not
   --  scalar" rather than risking a false positive.
   function Is_Scalar_Declaration
     (Decl : Libadalang.Analysis.Object_Decl) return Boolean
   is
      Type_Expr : constant Libadalang.Analysis.Type_Expr := Decl.F_Type_Expr;
   begin
      if Libadalang.Analysis.Is_Null (Type_Expr) then
         return False;
      end if;

      declare
         Base : constant Libadalang.Analysis.Base_Type_Decl :=
           Type_Expr.P_Designated_Type_Decl;
      begin
         return not Libadalang.Analysis.Is_Null (Base)
           and then Base.P_Is_Scalar_Type;
      end;
   exception
      when others =>
         return False;
   end Is_Scalar_Declaration;

   procedure Analyze_Object_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Decl : Libadalang.Analysis.Object_Decl) is
   begin
      if Rule_States (Shadowed_Declaration) = Enabled then
         for Id of Decl.F_Ids loop
            if Shadows_Enclosing_Declaration (Canonical_Text (Id))
            then
               Report_Rule_Violation
                 (Unit, Id, Shadowed_Declaration,
                  "declaration shadows an object in an enclosing subprogram");
            end if;
         end loop;
      end if;

      if Rule_States (Uninitialized_Read) = Enabled
        and then Libadalang.Analysis.Is_Null (Decl.F_Default_Expr)
        and then Libadalang.Analysis.Is_Null (Decl.F_Renaming_Clause)
        and then Is_Scalar_Declaration (Decl)
      then
         declare
            Subprogram : constant Libadalang.Analysis.Subp_Body :=
              Data_Flow.Enclosing_Subprogram (Decl);
         begin
            if not Libadalang.Analysis.Is_Null (Subprogram) then
               declare
                  Result : constant Data_Flow.Access_Result :=
                    Data_Flow.First_Access
                      (Subprogram.As_Ada_Node, Decl.As_Basic_Decl, Decl);
               begin
                  if Result.Kind = Data_Flow.Read_Access then
                     Report_Rule_Violation
                       (Unit, Result.Node, Uninitialized_Read,
                        "variable is read before it is ever assigned a " &
                        "value");
                  end if;
               end;
            end if;
         end;
      end if;
   end Analyze_Object_Declaration;

   procedure Analyze_Subprogram_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Decl : Libadalang.Analysis.Classic_Subp_Decl'Class) is
   begin
      if Rule_States (Missing_Overriding_Indicator) = Enabled then
         Check_Overriding_Indicator
           (Unit, Decl, Decl.F_Subp_Spec, Decl.F_Overriding);
      end if;
   end Analyze_Subprogram_Declaration;

end Adalang_Analyzer.Checks.Declarations;
