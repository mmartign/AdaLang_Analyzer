--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;      use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Data_Flow;
with Adalang_Analyzer.Config;        use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Interp;
with Adalang_Analyzer.Report;        use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;         use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils;    use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks.Declarations is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;

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
              Data_Flow.Referenced_Declaration (Node);
         begin
            --  Prefer semantic identity.  When Libadalang cannot resolve a
            --  name in an otherwise valid unit, conservatively treat the
            --  matching spelling as a use instead of emitting a false
            --  "unused" diagnostic.
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
   end References_Named_Declaration;

   --  True when Node is an object or parameter declaration that introduces
   --  Name (compared via its canonical, case-folded spelling).
   function Declares_Name
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Name : String) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind = Libadalang.Common.Ada_Object_Decl then
         for Id of Node.As_Object_Decl.F_Ids loop
            if Canonical_Text (Id) = Name then
               return True;
            end if;
         end loop;
      elsif Node.Kind = Libadalang.Common.Ada_Param_Spec then
         for Id of Node.As_Param_Spec.F_Ids loop
            if Canonical_Text (Id) = Name then
               return True;
            end if;
         end loop;
      end if;

      return False;
   end Declares_Name;

   --  True when Decl's Name is already declared by an object or parameter
   --  in some scope that textually encloses Decl's own scope, i.e. Decl
   --  hides an outer declaration of the same name. The search walks the
   --  whole compilation unit from its root because Libadalang doesn't
   --  expose an "enclosing scopes" iterator directly usable here; the
   --  Is_Ancestor_Of check filters candidates down to genuine ancestors.
   function Shadows_Enclosing_Declaration
     (Decl : Libadalang.Analysis.Object_Decl; Name : String) return Boolean
   is
      --  The nearest subprogram body, declare block, or package body
      --  enclosing Node, i.e. its lexical scope for shadowing purposes.
      function Scope_Of
        (Node : Libadalang.Analysis.Ada_Node'Class)
         return Libadalang.Analysis.Ada_Node
      is
         Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
      begin
         while not Libadalang.Analysis.Is_Null (Ancestor) loop
            if Ancestor.Kind in Libadalang.Common.Ada_Subp_Body
              | Libadalang.Common.Ada_Decl_Block
              | Libadalang.Common.Ada_Package_Body
            then
               return Ancestor;
            end if;
            Ancestor := Ancestor.Parent;
         end loop;
         return Libadalang.Analysis.No_Ada_Node;
      end Scope_Of;

      --  True when Possible_Ancestor is a syntactic ancestor of Node.
      function Is_Ancestor_Of
        (Possible_Ancestor : Libadalang.Analysis.Ada_Node;
         Node              : Libadalang.Analysis.Ada_Node'Class)
         return Boolean
      is
         Ancestor : Libadalang.Analysis.Ada_Node := Node.Parent;
      begin
         while not Libadalang.Analysis.Is_Null (Ancestor) loop
            if Ancestor = Possible_Ancestor then
               return True;
            end if;
            Ancestor := Ancestor.Parent;
         end loop;
         return False;
      end Is_Ancestor_Of;

      Current_Node  : constant Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Decl);
      Current_Scope : constant Libadalang.Analysis.Ada_Node := Scope_Of (Decl);
      Root          : Libadalang.Analysis.Ada_Node := Current_Node;

      --  Searches the subtree rooted at Node for a declaration of Name
      --  whose scope both differs from Decl's own scope and encloses it.
      function Has_Outer_Declaration
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
         Candidate_Scope : Libadalang.Analysis.Ada_Node;
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         end if;

         if Libadalang.Analysis.Ada_Node (Node) /= Current_Node
           and then Node.Kind in Libadalang.Common.Ada_Object_Decl
             | Libadalang.Common.Ada_Param_Spec
           and then Declares_Name (Node, Name)
         then
            Candidate_Scope := Scope_Of (Node);
            if not Libadalang.Analysis.Is_Null (Candidate_Scope)
              and then Candidate_Scope /= Current_Scope
              and then Is_Ancestor_Of (Candidate_Scope, Decl)
            then
               return True;
            end if;
         end if;

         for I in 1 .. Node.Children_Count loop
            if Has_Outer_Declaration (Node.Child (I)) then
               return True;
            end if;
         end loop;
         return False;
      end Has_Outer_Declaration;
   begin
      while not Libadalang.Analysis.Is_Null (Root.Parent) loop
         Root := Root.Parent;
      end loop;
      return Has_Outer_Declaration (Root);
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

   procedure Analyze_Subprogram  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Param_Count : Natural := 0;
   begin
      if Rule_States (Unused_Parameter) = Enabled
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
         for I in 1 .. Subprogram.F_Decls.F_Decls.Children_Count loop
            declare
               Item : constant Libadalang.Analysis.Ada_Node :=
                 Subprogram.F_Decls.F_Decls.Child (I);
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
                           --  declaration's own node: it always contains
                           --  Id's defining occurrence, which would
                           --  otherwise be misread as a use of itself.
                           for J in 1 .. Subprogram.F_Decls.F_Decls.Children_Count loop
                              if J /= I
                                and then References_Named_Declaration
                                  (Subprogram.F_Decls.F_Decls.Child (J),
                                   Basic, Name)
                              then
                                 Used_Elsewhere := True;
                                 exit;  --  adalang-analyzer: ignore No_Exit
                              end if;
                           end loop;

                           if not Used_Elsewhere
                             and then not References_Named_Declaration
                               (Subprogram.F_Stmts, Basic, Name)
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

      --  Interpret_Subprogram_Flow itself no-ops unless Division_By_Zero or
      --  Constant_Condition is enabled, so the guard lives there.
      Flow_Interp.Interpret_Subprogram_Flow (Unit, Subprogram);
   end Analyze_Subprogram;

   procedure Analyze_Object_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Decl : Libadalang.Analysis.Object_Decl) is
   begin
      if Rule_States (Shadowed_Declaration) = Enabled then
         for Id of Decl.F_Ids loop
            if Shadows_Enclosing_Declaration
              (Decl, Canonical_Text (Id))
            then
               Report_Rule_Violation
                 (Unit, Id, Shadowed_Declaration,
                  "declaration shadows an object in an enclosing subprogram");
            end if;
         end loop;
      end if;
   end Analyze_Object_Declaration;

end Adalang_Analyzer.Checks.Declarations;
