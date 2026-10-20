--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Vectors;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;   use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;     use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Contracts;
with Adalang_Analyzer.Report;     use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.SPARK_Dependency_Analysis is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   subtype Key_Type is Libadalang.Analysis.Ada_Node;
   No_Key : Key_Type renames Libadalang.Analysis.No_Ada_Node;

   package Key_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Key_Type);

   type Dependency_Association is record
      Output      : Key_Type := No_Key;
      Output_Name : Unbounded_String;
      Inputs      : Key_Vectors.Vector;
      Site        : Libadalang.Analysis.Ada_Node := No_Key;
   end record;

   package Association_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Dependency_Association);

   function Contract_Expression
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Libadalang.Analysis.Expr
   is
      Result : Libadalang.Analysis.Expr;
   begin
      Result := Decl.P_Get_Aspect_Spec_Expr
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Name)));
      if Libadalang.Analysis.Is_Null (Result)
        and then Decl.Kind = Libadalang.Common.Ada_Subp_Body
      then
         declare
            Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
              Decl.As_Subp_Body.P_Decl_Part
                (Imprecise_Fallback => True);
         begin
            if not Libadalang.Analysis.Is_Null (Decl_Part) then
               Result := Decl_Part.P_Get_Aspect_Spec_Expr
                 (Langkit_Support.Text.To_Unbounded_Text
                    (Langkit_Support.Text.To_Text (Name)));
            end if;
         end;
      end if;
      return Result;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Contract_Expression;

   type SPARK_Mode_State is record
      Has_Mode : Boolean := False;
      Is_Off   : Boolean := False;
   end record;

   function Own_SPARK_Mode
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return SPARK_Mode_State
   is
   begin
      declare
         Aspect : constant Libadalang.Analysis.Aspect :=
           Decl.P_Get_Aspect
             (Langkit_Support.Text.To_Unbounded_Text
                (Langkit_Support.Text.To_Text ("SPARK_Mode")));
      begin
         if not Libadalang.Analysis.Exists (Aspect) then
            return (Has_Mode => False, Is_Off => False);
         end if;
         return
           (Has_Mode => True,
            Is_Off   =>
              not Libadalang.Analysis.Is_Null
                (Libadalang.Analysis.Value (Aspect))
              and then Normalize_Rule_Name
                (Node_Text (Libadalang.Analysis.Value (Aspect))) = "off");
      end;
   exception
      when others =>
         return (Has_Mode => False, Is_Off => False);
   end Own_SPARK_Mode;

   function Effective_SPARK_Enabled
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Mode     : SPARK_Mode_State;
      Ancestor : Libadalang.Analysis.Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return True;
      end if;

      Mode := Own_SPARK_Mode (Decl);
      if Mode.Has_Mode then
         return not Mode.Is_Off;
      end if;

      --  SPARK_Mode was not set directly on Decl: per the SPARK RM it is
      --  inherited from the nearest enclosing package/subprogram/task/
      --  protected body or spec. Libadalang's own aspect lookup only
      --  follows type derivation for inheritance, not lexical scoping,
      --  so the enclosing bodies/specs are walked by hand here.
      Ancestor := Libadalang.Analysis.Ada_Node (Decl).Parent;
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         case Ancestor.Kind is
            when Libadalang.Common.Ada_Package_Body
               | Libadalang.Common.Ada_Package_Decl
               | Libadalang.Common.Ada_Generic_Package_Decl
               | Libadalang.Common.Ada_Subp_Body
               | Libadalang.Common.Ada_Task_Body
               | Libadalang.Common.Ada_Protected_Body
            =>
               Mode := Own_SPARK_Mode (Ancestor.As_Basic_Decl);
               if Mode.Has_Mode then
                  return not Mode.Is_Off;
               end if;
            when others =>
               null;
         end case;
         Ancestor := Ancestor.Parent;
      end loop;

      return True;
   exception
      when others =>
         return True;
   end Effective_SPARK_Enabled;

   --  The object or state abstraction Node names, by a simple or an
   --  expanded name.
   function Referenced_Key
     (Node : Libadalang.Analysis.Ada_Node'Class) return Key_Type
   is
      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind not in Libadalang.Common.Ada_Identifier
          | Libadalang.Common.Ada_Dotted_Name
      then
         return No_Key;
      end if;
      Decl := Node.As_Name.P_Referenced_Decl (Imprecise_Fallback => True);
      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind not in Libadalang.Common.Ada_Object_Decl
          | Libadalang.Common.Ada_Param_Spec
          | Libadalang.Common.Ada_Abstract_State_Decl
      then
         return No_Key;
      end if;
      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return No_Key;
   end Referenced_Key;

   function Key_Name (Key : Key_Type) return String is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return "null";
      else
         return Node_Text (Key);
      end if;
   end Key_Name;

   function Is_Parameter_Key (Key : Key_Type) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node := Key;
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return True;
         elsif Current.Kind = Libadalang.Common.Ada_Object_Decl then
            return False;
         end if;
         Current := Current.Parent;
      end loop;
      return False;
   end Is_Parameter_Key;

   function Equivalent_Keys (Left, Right : Key_Type) return Boolean is
     (Left = Right
      or else
        (Is_Parameter_Key (Left)
         and then Is_Parameter_Key (Right)
         and then Normalize_Rule_Name (Key_Name (Left)) =
           Normalize_Rule_Name (Key_Name (Right))));

   function Contains
     (Keys : Key_Vectors.Vector; Key : Key_Type) return Boolean
   is
   begin
      for Item of Keys loop
         if Equivalent_Keys (Item, Key) then
            return True;
         end if;
      end loop;
      return False;
   end Contains;

   procedure Include (Keys : in out Key_Vectors.Vector; Key : Key_Type) is
   begin
      if not Libadalang.Analysis.Is_Null (Key)
        and then not Contains (Keys, Key)
      then
         Keys.Append (Key);
      end if;
   end Include;

   procedure Add_Key_References
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Keys : in out Key_Vectors.Vector)
   is
      Key : Key_Type;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      elsif Node.Kind in Libadalang.Common.Ada_Identifier
                | Libadalang.Common.Ada_Dotted_Name
      then
         Key := Referenced_Key (Node);
         if not Libadalang.Analysis.Is_Null (Key)
           or else Node.Kind = Libadalang.Common.Ada_Identifier
         then
            Include (Keys, Key);
            return;
         end if;
      end if;
      for I in 1 .. Node.Children_Count loop
         Add_Key_References (Node.Child (I), Keys);
      end loop;
   end Add_Key_References;

   procedure Parse_Global
     (Expr     : Libadalang.Analysis.Expr;
      Inputs   : in out Key_Vectors.Vector;
      Outputs  : in out Key_Vectors.Vector;
      Proof_In : in out Key_Vectors.Vector)
   is
      procedure Add_Association
        (Node : Libadalang.Analysis.Ada_Node'Class;
         Readable, Writable, Is_Proof : Boolean)
      is
         Keys : Key_Vectors.Vector;
      begin
         Add_Key_References (Node, Keys);
         for Key of Keys loop
            if Readable then
               Include (Inputs, Key);
            end if;
            if Writable then
               Include (Outputs, Key);
            end if;
            if Is_Proof then
               Include (Proof_In, Key);
            end if;
         end loop;
      end Add_Association;
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind = Libadalang.Common.Ada_Null_Literal
      then
         return;
      elsif Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate then
         Add_Association (Expr, True, False, False);
         return;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            declare
               Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                 Item.As_Aggregate_Assoc;
               Mode : constant String :=
                 (if Assoc.F_Designators.Children_Count = 0 then "input"
                  else Normalize_Rule_Name
                    (Node_Text (Assoc.F_Designators.Child (1))));
            begin
               Add_Association
                 (Assoc.F_R_Expr,
                  Readable => Mode = "input" or else Mode = "in-out"
                    or else Mode = "proof-in",
                  Writable => Mode = "output" or else Mode = "in-out",
                  Is_Proof => Mode = "proof-in");
            end;
         end if;
      end loop;
   end Parse_Global;

   procedure Parse_Depends
     (Expr         : Libadalang.Analysis.Expr;
      Associations : in out Association_Vectors.Vector)
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr)
        or else Expr.Kind = Libadalang.Common.Ada_Null_Literal
        or else Expr.Kind not in Libadalang.Common.Ada_Base_Aggregate
      then
         return;
      end if;

      for Item of Expr.As_Base_Aggregate.F_Assocs loop
         if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
            declare
               Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                 Item.As_Aggregate_Assoc;
               Inputs : Key_Vectors.Vector;
               Has_Plus : constant Boolean :=
                 Ada.Strings.Fixed.Index (Node_Text (Assoc), "=>+") /= 0
                 or else Ada.Strings.Fixed.Index
                   (Node_Text (Assoc), "=> +") /= 0;
            begin
               Add_Key_References (Assoc.F_R_Expr, Inputs);

               --  A combined-output designator such as "(A, B) => C" is not
               --  a discrete choice list in Ada's own aggregate grammar
               --  (that would need "|", not ","), so Libadalang parses the
               --  parenthesized "A, B" as a nested positional aggregate:
               --  one designator of kind Ada_Aggregate wrapping two
               --  Aggregate_Assoc children "A" and "B", rather than as two
               --  separate designators. Left as-is, Referenced_Key sees
               --  that single Ada_Aggregate node, is not an identifier, and
               --  resolves to no key -- silently dropping every output in
               --  a combined list and misreporting the shared input as an
               --  unused "null => Input" association instead. Expand that
               --  nested aggregate's own associations here so each of its
               --  identifiers is treated as its own output designator.
               declare
                  procedure Append_Association
                    (Name_Node : Libadalang.Analysis.Ada_Node'Class;
                     Site_Node : Libadalang.Analysis.Ada_Node'Class)
                  is
                     Output : constant Key_Type :=
                       Referenced_Key (Name_Node);
                     Actual_Inputs : Key_Vectors.Vector := Inputs;
                  begin
                     if Has_Plus then
                        Include (Actual_Inputs, Output);
                     end if;
                     Associations.Append
                       ((Output      => Output,
                         Output_Name => To_Unbounded_String
                           (if Libadalang.Analysis.Is_Null (Output) then
                               "null"
                            else Node_Text (Name_Node)),
                         Inputs      => Actual_Inputs,
                         Site        =>
                           Libadalang.Analysis.Ada_Node (Site_Node)));
                  end Append_Association;
               begin
                  for Designator of Assoc.F_Designators loop
                     if Designator.Kind = Libadalang.Common.Ada_Aggregate then
                        for Nested of Designator.As_Base_Aggregate.F_Assocs
                        loop
                           if Nested.Kind =
                             Libadalang.Common.Ada_Aggregate_Assoc
                           then
                              Append_Association
                                (Nested.As_Aggregate_Assoc.F_R_Expr, Nested);
                           end if;
                        end loop;
                     else
                        Append_Association (Designator, Designator);
                     end if;
                  end loop;
               end;
            end;
         end if;
      end loop;
   end Parse_Depends;

   --  Where the association of the output named Name is written; the
   --  aspect when none is found.
   function Association_Site
     (Associations : Association_Vectors.Vector;
      Name         : String;
      Depends      : Libadalang.Analysis.Expr)
      return Libadalang.Analysis.Ada_Node is
   begin
      for Assoc of Associations loop
         if not Libadalang.Analysis.Is_Null (Assoc.Output)
           and then Normalize_Rule_Name (Key_Name (Assoc.Output)) =
             Normalize_Rule_Name (Name)
         then
            return Assoc.Site;
         end if;
      end loop;
      return Libadalang.Analysis.Ada_Node (Depends);
   end Association_Site;

   function Mentioned_Input
     (Associations : Association_Vectors.Vector;
      Input        : Key_Type) return Boolean
   is
   begin
      for Assoc of Associations loop
         if Contains (Assoc.Inputs, Input) then
            return True;
         end if;
      end loop;
      return False;
   end Mentioned_Input;

   --  How far an out parameter is an input: an array whose bounds the
   --  actual gives is one, by its bounds; an object of another indefinite
   --  type may be, by its discriminants, when the actual is constrained,
   --  and the contract may list it or not; any other is none.
   type Out_Input is (No_Input, May_Be_Input, Bounds_Input);

   function Out_Parameter_Input
     (Param : Libadalang.Analysis.Param_Spec) return Out_Input is
   begin
      if Param.F_Type_Expr.P_Is_Definite_Subtype then
         return No_Input;
      elsif Param.F_Type_Expr.P_Designated_Type_Decl.P_Is_Array_Type then
         return Bounds_Input;
      end if;
      return May_Be_Input;
   exception
      when others =>
         return May_Be_Input;
   end Out_Parameter_Input;

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Depends : constant Libadalang.Analysis.Expr :=
        Contract_Expression (Subprogram, "Depends");
      Global : constant Libadalang.Analysis.Expr :=
        Contract_Expression (Subprogram, "Global");
      Inputs, Outputs, Proof_In : Key_Vectors.Vector;
      --  Inputs the contract may list or leave out.
      Optional : Key_Vectors.Vector;
      Associations : Association_Vectors.Vector;

      --  What the body does that the aspect does not say, as worked out by
      --  the flow-dependencies analysis; nothing when it is not worked out.
      procedure Report_Flow
        (Kind : Flow_Contracts.Mismatch_Kind;
         Output, Input : String) is  --  adalang-analyzer: ignore Swappable_Parameters
      begin
         case Kind is
            when Flow_Contracts.Missing_Flow =>
               Report_Rule_Violation
                 (Unit, Association_Site (Associations, Output, Depends),
                  Depends_Contract_Mismatch,
                  "output '" & Output & "' may depend on input '" & Input &
                    "', which is missing from Depends");
            when Flow_Contracts.Extra_Flow =>
               Report_Rule_Violation
                 (Unit, Association_Site (Associations, Output, Depends),
                  Depends_Contract_Mismatch,
                  "input '" & Input & "' is declared for output '" &
                    Output & "' but no such flow is inferred");
            when Flow_Contracts.Proof_Flow =>
               Report_Rule_Violation
                 (Unit, Association_Site (Associations, Output, Depends),
                  Depends_Contract_Mismatch,
                  "output '" & Output & "' depends on Proof_In global '" &
                    Input & "'");
            when Flow_Contracts.Not_Analyzed  --  adalang-analyzer: ignore Null_Case_Alternative
               | Flow_Contracts.Unlisted_Output =>
               --  Not worked out, or the business of the Global aspect.
               null;
         end case;
      end Report_Flow;
   begin
      if Rule_States (Depends_Contract_Mismatch) /= Enabled
        or else Libadalang.Analysis.Is_Null (Depends)
        or else not Effective_SPARK_Enabled (Subprogram)
      then
         return;
      end if;

      for Param of Subprogram.F_Subp_Spec.P_Params loop
         for Id of Param.F_Ids loop
            declare
               Key : constant Key_Type := Libadalang.Analysis.Ada_Node (Id);
            begin
               if Param.F_Mode.Kind not in Libadalang.Common.Ada_Mode_Out
               then
                  Include (Inputs, Key);
               else
                  if Out_Parameter_Input (Param) = Bounds_Input then
                     Include (Inputs, Key);
                  elsif Out_Parameter_Input (Param) = May_Be_Input then
                     Include (Optional, Key);
                  end if;
               end if;
               if Param.F_Mode.Kind in Libadalang.Common.Ada_Mode_Out
                 | Libadalang.Common.Ada_Mode_In_Out
               then
                  Include (Outputs, Key);
               end if;
            end;
         end loop;
      end loop;

      Parse_Global (Global, Inputs, Outputs, Proof_In);
      Parse_Depends (Depends, Associations);

      Flow_Contracts.Check_Depends (Subprogram, Depends, Report_Flow'Access);

      --  Depends is complete over inputs as well as outputs. An unused input
      --  is represented by a null => Input association.
      for Input of Inputs loop
         if not Mentioned_Input (Associations, Input) then
            Report_Rule_Violation
              (Unit, Subprogram.F_Subp_Spec.P_Name,
               Depends_Contract_Mismatch,
               "input '" & Key_Name (Input) &
                 "' is missing from the Depends relation");
         end if;
      end loop;

      for Assoc of Associations loop
         for Input of Assoc.Inputs loop
            if not Contains (Inputs, Input)
              and then not Contains (Optional, Input)
            then
               Report_Rule_Violation
                 (Unit, Assoc.Site, Depends_Contract_Mismatch,
                  "'" & Key_Name (Input) &
                    "' is declared as a dependency but is not an input");
            end if;
         end loop;
      end loop;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping dependency analysis for subprogram: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Analyze_Subprogram;

end Adalang_Analyzer.SPARK_Dependency_Analysis;
