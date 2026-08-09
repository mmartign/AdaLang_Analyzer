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

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;    use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Domain; use Adalang_Analyzer.Flow_Domain;
with Adalang_Analyzer.Flow_Eval;   use Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.Report;      use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;       use Adalang_Analyzer.Rules;

package body Adalang_Analyzer.Checks.Expressions is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   function Is_Floating_Expression
     (Node : Libadalang.Analysis.Expr'Class) return Boolean
   is
      Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
        Node.P_Expression_Type;
   begin
      return not Libadalang.Analysis.Is_Null (Expr_Type)
        and then Expr_Type.P_Is_Float_Type (Node);
   exception
      when others =>
         --  Name resolution can legitimately fail for incomplete source.
         return False;
   end Is_Floating_Expression;

   --  True when Node's static type is Standard.Boolean, as opposed to a
   --  user-declared type that merely has an enumeration literal spelled
   --  "True" or "False" (a homograph of the predefined literal, not an
   --  instance of it). Used to keep Redundant_Boolean_Comparison from
   --  firing on "X = True" when X is such a type: "X" alone would not be
   --  the equivalent boolean-valued expression the check's advice assumes.
   function Is_Standard_Boolean_Expression
     (Node : Libadalang.Analysis.Expr'Class) return Boolean
   is
      Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
        Node.P_Expression_Type;
   begin
      return not Libadalang.Analysis.Is_Null (Expr_Type)
        and then Langkit_Support.Text.To_UTF8
                   (Expr_Type.P_Canonical_Fully_Qualified_Name) =
                     "standard.boolean";
   exception
      when others =>
         --  Name resolution can legitimately fail for incomplete source.
         return False;
   end Is_Standard_Boolean_Expression;

   --  Strips one layer of enclosing parentheses, if present, so operands
   --  that are otherwise structurally identical still compare equal by
   --  text even when one of them is written with a redundant "(...)".
   function Unwrap_Paren
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if not Libadalang.Analysis.Is_Null (Node)
        and then Node.Kind = Libadalang.Common.Ada_Paren_Expr
      then
         return Libadalang.Analysis.Ada_Node (Node.As_Paren_Expr.F_Expr);
      end if;
      return Libadalang.Analysis.Ada_Node (Node);
   end Unwrap_Paren;

   --  True when Possible_Not is "not X" and Other's canonical text is
   --  exactly X, i.e. the two operands are syntactic negations of each
   --  other. Backs Contradictory_Condition ("X and not X", "X or not X").
   --  A single redundant pair of parentheses around either operand (e.g.
   --  "not (X)") does not defeat the match.
   function Is_Negation_Of
     (Possible_Not : Libadalang.Analysis.Ada_Node'Class;
      Other        : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Possible_Not)
        or else Possible_Not.Kind /= Libadalang.Common.Ada_Un_Op
        or else Possible_Not.As_Un_Op.F_Op /= Libadalang.Common.Ada_Op_Not
      then
         return False;
      end if;

      declare
         Negated_Operand : constant Libadalang.Analysis.Ada_Node :=
           Unwrap_Paren
             (Libadalang.Analysis.Ada_Node (Possible_Not.As_Un_Op.F_Expr));
         Other_Operand   : constant Libadalang.Analysis.Ada_Node :=
           Unwrap_Paren (Other);
      begin
         return Canonical_Text (Negated_Operand) /= ""
           and then Canonical_Text (Negated_Operand) =
             Canonical_Text (Other_Operand);
      end;
   end Is_Negation_Of;

   --  True for operators where "X op X" is suspicious rather than a
   --  routine identity (e.g. "+" and "*" are excluded: "X + X" and
   --  "X * X" are ordinary, intentional expressions).
   function Interesting_Same_Operand_Op
     (Op : Libadalang.Common.Ada_Node_Kind_Type) return Boolean is
   begin
      case Op is
         when Libadalang.Common.Ada_Op_And
            | Libadalang.Common.Ada_Op_And_Then
            | Libadalang.Common.Ada_Op_Or
            | Libadalang.Common.Ada_Op_Or_Else
            | Libadalang.Common.Ada_Op_Xor
            | Libadalang.Common.Ada_Op_Eq
            | Libadalang.Common.Ada_Op_Neq
            | Libadalang.Common.Ada_Op_Lt
            | Libadalang.Common.Ada_Op_Lte
            | Libadalang.Common.Ada_Op_Gt
            | Libadalang.Common.Ada_Op_Gte
            | Libadalang.Common.Ada_Op_Minus
            | Libadalang.Common.Ada_Op_Div
            | Libadalang.Common.Ada_Op_Mod
            | Libadalang.Common.Ada_Op_Rem =>
            return True;
         when others =>
            return False;
      end case;
   end Interesting_Same_Operand_Op;

   procedure Analyze_Binary_Expression  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.Bin_Op)
   is
      Op         : constant Libadalang.Common.Ada_Node_Kind_Type :=
        Expr.F_Op;
      Left_Text  : constant String := Canonical_Text (Expr.F_Left);
      Right_Text : constant String := Canonical_Text (Expr.F_Right);
      Left_Int   : constant Abstract_Int := Integer_Value (Expr.F_Left);
      Right_Int  : constant Abstract_Int := Integer_Value (Expr.F_Right);
   begin
      if Rule_States (Division_By_Zero) = Enabled
        and then Op in Libadalang.Common.Ada_Op_Div
          | Libadalang.Common.Ada_Op_Mod
          | Libadalang.Common.Ada_Op_Rem
      then
         if Is_Static_Zero (Expr.F_Right) then
            Adalang_Analyzer.Proof_Obligations.Register_At
              (Unit             => Unit,
               Node             => Expr.F_Right,
               Kind             =>
                 Adalang_Analyzer.Proof_Obligations.Division_By_Zero_Check,
               Status           =>
                 Adalang_Analyzer.Proof_Obligations.Definite_Error,
               Method           =>
                 Adalang_Analyzer.Proof_Obligations.Static_Evaluation,
               Abstract_State   => "right operand => 0",
               Explanation      => "right operand is statically zero",
               Configuration_Id => Assurance_Profile_Name);
            Report_Rule_Violation
              (Unit, Expr.F_Right, Division_By_Zero,
               "right operand is statically zero",
               Explanation =>
                 "Static evaluation resolved the divisor to zero.",
               Evidence => "right operand => 0");
         else
            Adalang_Analyzer.Proof_Obligations.Register_At
              (Unit               => Unit,
               Node               => Expr.F_Right,
               Kind               =>
                 Adalang_Analyzer.Proof_Obligations.Division_By_Zero_Check,
               Status             =>
                 Adalang_Analyzer.Proof_Obligations.Unproved,
               Method             =>
                 Adalang_Analyzer.Proof_Obligations.Static_Evaluation,
               Explanation        =>
                 "division-by-zero failure is not established, but absence " &
                 "is not proved",
               Imprecision_Source =>
                 "static evaluation does not determine a nonzero operand",
               Configuration_Id   => Assurance_Profile_Name);
         end if;
      end if;

      if Rule_States (Floating_Equality) = Enabled
        and then Op in Libadalang.Common.Ada_Op_Eq
          | Libadalang.Common.Ada_Op_Neq
        and then (Is_Floating_Expression (Expr.F_Left)
                  or else Is_Floating_Expression (Expr.F_Right))
      then
         Report_Rule_Violation
           (Unit, Expr, Floating_Equality,
            "direct equality comparison on floating-point operands");
      end if;

      if Rule_States (Redundant_Boolean_Comparison) = Enabled
        and then Op in Libadalang.Common.Ada_Op_Eq
          | Libadalang.Common.Ada_Op_Neq
        and then (Is_Boolean_Literal (Expr.F_Left)
                    xor Is_Boolean_Literal (Expr.F_Right))
        and then (if Is_Boolean_Literal (Expr.F_Left)
                  then Is_Standard_Boolean_Expression (Expr.F_Right)
                  else Is_Standard_Boolean_Expression (Expr.F_Left))
      then
         Report_Rule_Violation
           (Unit, Expr, Redundant_Boolean_Comparison,
            "comparison with a boolean literal can be simplified");
      end if;

      if Rule_States (Reversed_Range) = Enabled
        and then Op = Libadalang.Common.Ada_Op_Double_Dot
        and then Left_Int.Known
        and then Right_Int.Known
        and then Left_Int.Value > Right_Int.Value

        --  "Low .. Low - 1" (canonically "1 .. 0") is Ada's own idiom for a
        --  statically empty range/array -- "return (1 .. 0 => <>);" for an
        --  empty-array function result, or "Empty : constant T (1 .. 0) :=
        --  (others => <>);" for an empty-array constant -- not a swapped-
        --  bounds mistake. Only a wider gap between the bounds still counts
        --  as reversed, since a real typo (e.g. "10 .. 1" meant to be
        --  "1 .. 10") virtually never happens to land exactly one short of
        --  empty. Found while validating against gnatcoll-core
        --  (AdaCore/gnatcoll-core, see benchmarks/gnatcoll/): all 18
        --  Reversed_Range findings in that corpus were this exact idiom,
        --  every one spelled "1 .. 0" -- a 100% false-positive rate for
        --  the rule as it stood (FP-045).
        and then Left_Int.Value /= Right_Int.Value + 1
      then
         Report_Rule_Violation
           (Unit, Expr, Reversed_Range,
            "range lower bound is greater than upper bound");
      end if;

      if Rule_States (Same_Operand) = Enabled
        and then Interesting_Same_Operand_Op (Op)
        and then Left_Text /= ""
        and then Left_Text = Right_Text
      then
         Report_Rule_Violation
           (Unit, Expr, Same_Operand,
            "same expression appears on both sides of the operator");
      end if;

      if Rule_States (Contradictory_Condition) = Enabled
        and then Op in Libadalang.Common.Ada_Op_And
          | Libadalang.Common.Ada_Op_And_Then
          | Libadalang.Common.Ada_Op_Or
          | Libadalang.Common.Ada_Op_Or_Else
        and then (Is_Negation_Of (Expr.F_Left, Expr.F_Right)
                  or else Is_Negation_Of (Expr.F_Right, Expr.F_Left))
      then
         Report_Rule_Violation
           (Unit, Expr, Contradictory_Condition,
            (if Op in Libadalang.Common.Ada_Op_And
               | Libadalang.Common.Ada_Op_And_Then
             then "condition is always false because it combines X and not X"
             else "condition is always true because it combines X or not X"),
            Explanation =>
              "The two Boolean operands are structural complements, so " &
              (if Op in Libadalang.Common.Ada_Op_And
                 | Libadalang.Common.Ada_Op_And_Then
               then "they cannot both be true."
               else "at least one of them must be true."),
            Evidence =>
              "left operand => " & Left_Text &
              "; right operand => " & Right_Text);
      end if;

      if Rule_States (Duplicate_Boolean_Operand) = Enabled
        and then Op in Libadalang.Common.Ada_Op_And
          | Libadalang.Common.Ada_Op_And_Then
          | Libadalang.Common.Ada_Op_Or
          | Libadalang.Common.Ada_Op_Or_Else
        and then Left_Text /= ""
        and then Left_Text = Right_Text
      then
         Report_Rule_Violation
           (Unit, Expr, Duplicate_Boolean_Operand,
            "boolean expression repeats the same operand");
      end if;

      if Rule_States (Ineffective_Operation) = Enabled then
         if (Op = Libadalang.Common.Ada_Op_Plus
             and then (Is_Static_Zero (Expr.F_Left)
                       or else Is_Static_Zero (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Minus
                    and then Is_Static_Zero (Expr.F_Right))
           or else (Op = Libadalang.Common.Ada_Op_Mult
                    and then (Is_Static_One (Expr.F_Left)
                              or else Is_Static_One (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Div
                    and then Is_Static_One (Expr.F_Right))
           or else (Op = Libadalang.Common.Ada_Op_Pow
                    and then Is_Static_One (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_And
                      | Libadalang.Common.Ada_Op_And_Then
                    and then (Boolean_Value (Expr.F_Left) = Bool_True
                              or else Boolean_Value (Expr.F_Right) = Bool_True))
           or else (Op in Libadalang.Common.Ada_Op_Or
                      | Libadalang.Common.Ada_Op_Or_Else
                    and then (Boolean_Value (Expr.F_Left) = Bool_False
                              or else Boolean_Value (Expr.F_Right) = Bool_False))
         then
            Report_Rule_Violation
              (Unit, Expr, Ineffective_Operation,
               "identity operand has no effect on the expression result");
         end if;
      end if;

      if Rule_States (Constant_Result_Operation) = Enabled then
         if (Op = Libadalang.Common.Ada_Op_Mult
             and then (Is_Static_Zero (Expr.F_Left)
                       or else Is_Static_Zero (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Pow
                    and then Is_Static_Zero (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_Mod
                      | Libadalang.Common.Ada_Op_Rem
                    and then Is_Static_One (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_And
                      | Libadalang.Common.Ada_Op_And_Then
                    and then (Boolean_Value (Expr.F_Left) = Bool_False
                              or else Boolean_Value (Expr.F_Right) = Bool_False))
           or else (Op in Libadalang.Common.Ada_Op_Or
                      | Libadalang.Common.Ada_Op_Or_Else
                    and then (Boolean_Value (Expr.F_Left) = Bool_True
                              or else Boolean_Value (Expr.F_Right) = Bool_True))
         then
            Report_Rule_Violation
              (Unit, Expr, Constant_Result_Operation,
               "an absorbing operand forces this expression to a constant");
         end if;
      end if;
   end Analyze_Binary_Expression;

   procedure Analyze_Unary_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.Un_Op)
   is
      Inner : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Expr.F_Expr);
   begin
      if Inner.Kind = Libadalang.Common.Ada_Paren_Expr then
         Inner := Libadalang.Analysis.Ada_Node
           (Inner.As_Paren_Expr.F_Expr);
      end if;

      if Rule_States (Duplicate_Boolean_Operand) = Enabled
        and then Expr.F_Op = Libadalang.Common.Ada_Op_Not
        and then Inner.Kind = Libadalang.Common.Ada_Un_Op
        and then Inner.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Not
      then
         Report_Rule_Violation
           (Unit, Expr, Duplicate_Boolean_Operand,
            "double negation can be simplified");
      end if;
   end Analyze_Unary_Expression;

end Adalang_Analyzer.Checks.Expressions;
