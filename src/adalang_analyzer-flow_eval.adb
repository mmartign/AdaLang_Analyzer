--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Langkit_Support.Text;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Numeric_Literals;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Flow_Eval is

   use type Libadalang.Common.Ada_Node_Kind_Type;

   function Safe_Add
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left + Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Add;

   function Safe_Sub
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left - Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Sub;

   function Safe_Mul
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left * Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Mul;

   function Safe_Pow
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
      Result : Long_Long_Integer := 1;
   begin
      --  A 64-bit magnitude can't hold 2**64 or higher, and Ada's "**"
      --  disallows a negative exponent for an integer base.
      if Right < 0
        or else Right >
          Long_Long_Integer (Numeric_Literals.Maximum_Integer_Exponent)
      then
         return Unknown_Int;
      end if;

      for Count in 1 .. Right loop
         Result := Result * Left;
      end loop;

      return Known_Int (Result);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Pow;

   function Integer_Value  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State := Empty_Flow_State) return Abstract_Int
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Unknown_Int;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Int_Literal =>
            declare
               Parsed : Long_Long_Integer;
            begin
               if Numeric_Literals.Parse_Integer_Text
                    (Ada_Text.Node_Text (Node), Parsed)
               then
                  return Known_Int (Parsed);
               else
                  return Unknown_Int;
               end if;
            end;

         when Libadalang.Common.Ada_Identifier =>
            return Flow_Lookup
              (State,
               Libadalang.Analysis.Ada_Node
                 (Node.As_Name.P_Referenced_Defining_Name));

         when Libadalang.Common.Ada_Paren_Expr =>
            return Integer_Value (Node.As_Paren_Expr.F_Expr, State);

         when Libadalang.Common.Ada_Qual_Expr =>
            return Integer_Value (Node.As_Qual_Expr.F_Suffix, State);

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Expr  : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
               Value : constant Abstract_Int :=
                 Integer_Value (Expr.F_Expr, State);
            begin
               if not Value.Known then
                  return Unknown_Int;
               end if;

               case Expr.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Value;
                  when Libadalang.Common.Ada_Op_Minus =>
                     if Value.Value = Long_Long_Integer'First then
                        return Unknown_Int;
                     else
                        return Known_Int (-Value.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Abs =>
                     if Value.Value = Long_Long_Integer'First then
                        return Unknown_Int;
                     elsif Value.Value < 0 then
                        return Known_Int (-Value.Value);
                     else
                        return Value;
                     end if;
                  when others =>
                     return Unknown_Int;
               end case;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               Left  : constant Abstract_Int :=
                 Integer_Value (Expr.F_Left, State);
               Right : constant Abstract_Int :=
                 Integer_Value (Expr.F_Right, State);
            begin
               if not Left.Known or else not Right.Known then
                  return Unknown_Int;
               end if;

               case Expr.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Safe_Add (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Minus =>
                     return Safe_Sub (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Mult =>
                     return Safe_Mul (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Div =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value / Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Mod =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value mod Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Rem =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value rem Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Pow =>
                     return Safe_Pow (Left.Value, Right.Value);
                  when others =>
                     return Unknown_Int;
               end case;
            end;

         when Libadalang.Common.Ada_If_Expr =>
            declare
               If_Node : constant Libadalang.Analysis.If_Expr :=
                 Node.As_If_Expr;

               --  Evaluates the elsif/else chain starting at Index, mirroring
               --  Interpret_Else_Chain's statement-level logic for the
               --  expression form of if/elsif/else.
               function Elsif_Value (Index : Positive) return Abstract_Int is
               begin
                  if Index > If_Node.F_Alternatives.Children_Count then
                     return Integer_Value (If_Node.F_Else_Expr, State);
                  end if;

                  declare
                     Alt  : constant Libadalang.Analysis.Elsif_Expr_Part :=
                       If_Node.F_Alternatives.Child (Index)
                         .As_Elsif_Expr_Part;
                     Cond : constant Abstract_Bool :=
                       Boolean_Value (Alt.F_Cond_Expr, State);
                  begin
                     if Cond = Bool_True then
                        return Integer_Value (Alt.F_Then_Expr, State);
                     elsif Cond = Bool_False then
                        return Elsif_Value (Index + 1);
                     else
                        return Unknown_Int;
                     end if;
                  end;
               end Elsif_Value;

               Cond : constant Abstract_Bool :=
                 Boolean_Value (If_Node.F_Cond_Expr, State);
            begin
               if Cond = Bool_True then
                  return Integer_Value (If_Node.F_Then_Expr, State);
               elsif Cond = Bool_False then
                  return Elsif_Value (1);
               else
                  return Unknown_Int;
               end if;
            end;

         when others =>
            return Unknown_Int;
      end case;
   exception
      when others =>
         return Unknown_Int;
   end Integer_Value;

   function Is_Static_Zero
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Int_Value : constant Abstract_Int := Integer_Value (Node);
   begin
      if Int_Value.Known then
         return Int_Value.Value = 0;
      end if;

      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Real_Literal =>
            declare
               Value : constant Long_Long_Float :=
                 Long_Long_Float'Value
                   (Numeric_Literals.Strip_Underscores
                      (Ada_Text.Node_Text (Node)));
            begin
               return abs Value <= Floating_Zero_Tolerance;
            exception
               when others =>
                  return False;
            end;

         when Libadalang.Common.Ada_Paren_Expr =>
            return Is_Static_Zero (Node.As_Paren_Expr.F_Expr);

         when Libadalang.Common.Ada_Qual_Expr =>
            return Is_Static_Zero (Node.As_Qual_Expr.F_Suffix);

         when Libadalang.Common.Ada_Un_Op =>
            return Is_Static_Zero (Node.As_Un_Op.F_Expr);

         when others =>
            return False;
      end case;
   end Is_Static_Zero;

   function Is_Static_One
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Value : constant Abstract_Int := Integer_Value (Node);
   begin
      if Value.Known then
         return Value.Value = 1;
      end if;

      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Real_Literal
      then
         return False;
      end if;

      return Long_Long_Float'Value
        (Numeric_Literals.Strip_Underscores (Ada_Text.Node_Text (Node))) =
        1.0;
   exception
      when others =>
         return False;
   end Is_Static_One;

   function Is_Null_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Null_Literal =>
            return True;
         when Libadalang.Common.Ada_Paren_Expr =>
            return Is_Null_Literal (Node.As_Paren_Expr.F_Expr);
         when Libadalang.Common.Ada_Qual_Expr =>
            return Is_Null_Literal (Node.As_Qual_Expr.F_Suffix);
         when others =>
            return False;
      end case;
   end Is_Null_Literal;

   function Is_Boolean_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return False;
      end if;

      declare
         Text : constant String :=
           Text_Utils.Normalize_Rule_Name (Ada_Text.Node_Text (Node));
      begin
         return Text = "true" or else Text = "false";
      end;
   end Is_Boolean_Literal;

   function Compare_Integers
     (Op   : Libadalang.Common.Ada_Node_Kind_Type;
      Left : Abstract_Int; Right : Abstract_Int) return Abstract_Bool
   is
   begin
      if not Left.Known or else not Right.Known then
         return Bool_Unknown;
      end if;

      case Op is
         when Libadalang.Common.Ada_Op_Eq =>
            return Bool_From (Left.Value = Right.Value);
         when Libadalang.Common.Ada_Op_Neq =>
            return Bool_From (Left.Value /= Right.Value);
         when Libadalang.Common.Ada_Op_Lt =>
            return Bool_From (Left.Value < Right.Value);
         when Libadalang.Common.Ada_Op_Lte =>
            return Bool_From (Left.Value <= Right.Value);
         when Libadalang.Common.Ada_Op_Gt =>
            return Bool_From (Left.Value > Right.Value);
         when Libadalang.Common.Ada_Op_Gte =>
            return Bool_From (Left.Value >= Right.Value);
         when others =>
            return Bool_Unknown;
      end case;
   end Compare_Integers;

   function Range_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Abstract_Range
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Unknown_Range;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier then
         return Flow_Range_Lookup
           (State,
            Libadalang.Analysis.Ada_Node
              (Node.As_Name.P_Referenced_Defining_Name));
      elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Range_Value (Node.As_Paren_Expr.F_Expr, State);
      else
         return Range_From_Int (Integer_Value (Node, State));
      end if;
   end Range_Value;

   function Compare_Range
     (Op   : Libadalang.Common.Ada_Node_Kind_Type;
      Left : Abstract_Range; Right : Abstract_Range) return Abstract_Bool
   is
   begin
      case Op is
         when Libadalang.Common.Ada_Op_Gt =>
            if Left.Has_Low and then Right.Has_High
              and then Left.Low > Right.High
            then
               return Bool_True;
            elsif Left.Has_High and then Right.Has_Low
              and then Left.High <= Right.Low
            then
               return Bool_False;
            else
               return Bool_Unknown;
            end if;

         when Libadalang.Common.Ada_Op_Gte =>
            if Left.Has_Low and then Right.Has_High
              and then Left.Low >= Right.High
            then
               return Bool_True;
            elsif Left.Has_High and then Right.Has_Low
              and then Left.High < Right.Low
            then
               return Bool_False;
            else
               return Bool_Unknown;
            end if;

         when Libadalang.Common.Ada_Op_Lt =>
            return Compare_Range (Libadalang.Common.Ada_Op_Gt, Right, Left);

         when Libadalang.Common.Ada_Op_Lte =>
            return Compare_Range (Libadalang.Common.Ada_Op_Gte, Right, Left);

         when Libadalang.Common.Ada_Op_Eq =>
            if (Left.Has_High and then Right.Has_Low
                and then Left.High < Right.Low)
              or else (Right.Has_High and then Left.Has_Low
                       and then Right.High < Left.Low)
            then
               return Bool_False;
            else
               return Bool_Unknown;
            end if;

         when Libadalang.Common.Ada_Op_Neq =>
            return Not_Bool
              (Compare_Range (Libadalang.Common.Ada_Op_Eq, Left, Right));

         when others =>
            return Bool_Unknown;
      end case;
   end Compare_Range;

   function Boolean_Value  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State := Empty_Flow_State) return Abstract_Bool
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Bool_Unknown;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Identifier =>
            declare
               Text : constant String :=
                 Text_Utils.Normalize_Rule_Name
                   (Langkit_Support.Text.To_UTF8
                      (Libadalang.Analysis.Text (Node)));
            begin
               if Text = "true" then
                  return Bool_True;
               elsif Text = "false" then
                  return Bool_False;
               else
                  return Flow_Bool_Lookup
                    (State,
                     Libadalang.Analysis.Ada_Node
                       (Node.As_Name.P_Referenced_Defining_Name));
               end if;
            end;

         when Libadalang.Common.Ada_Paren_Expr =>
            return Boolean_Value (Node.As_Paren_Expr.F_Expr, State);

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Expr : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
            begin
               if Expr.F_Op = Libadalang.Common.Ada_Op_Not then
                  return Not_Bool (Boolean_Value (Expr.F_Expr, State));
               else
                  return Bool_Unknown;
               end if;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               Left  : constant Abstract_Bool :=
                 Boolean_Value (Expr.F_Left, State);
               Right : constant Abstract_Bool :=
                 Boolean_Value (Expr.F_Right, State);
               Op    : constant Libadalang.Common.Ada_Node_Kind_Type :=
                 Expr.F_Op;
            begin
               case Op is
                  when Libadalang.Common.Ada_Op_And
                     | Libadalang.Common.Ada_Op_And_Then =>
                     return And_Bool (Left, Right);
                  when Libadalang.Common.Ada_Op_Or
                     | Libadalang.Common.Ada_Op_Or_Else =>
                     return Or_Bool (Left, Right);
                  when Libadalang.Common.Ada_Op_Eq =>
                     declare
                        Bool_Result  : constant Abstract_Bool :=
                          Eq_Bool (Left, Right);
                        Int_Result   : constant Abstract_Bool :=
                          Compare_Integers
                            (Op, Integer_Value (Expr.F_Left, State),
                             Integer_Value (Expr.F_Right, State));
                        Range_Result : constant Abstract_Bool :=
                          Compare_Range
                            (Op, Range_Value (Expr.F_Left, State),
                             Range_Value (Expr.F_Right, State));
                     begin
                        if Bool_Result /= Bool_Unknown then
                           return Bool_Result;
                        elsif Int_Result /= Bool_Unknown then
                           return Int_Result;
                        elsif Range_Result /= Bool_Unknown then
                           return Range_Result;
                        elsif Is_Null_Literal (Expr.F_Left)
                          and then Is_Null_Literal (Expr.F_Right)
                        then
                           return Bool_True;
                        else
                           return Bool_Unknown;
                        end if;
                     end;
                  when Libadalang.Common.Ada_Op_Neq =>
                     declare
                        Bool_Result  : constant Abstract_Bool :=
                          Not_Bool (Eq_Bool (Left, Right));
                        Int_Result   : constant Abstract_Bool :=
                          Compare_Integers
                            (Op, Integer_Value (Expr.F_Left, State),
                             Integer_Value (Expr.F_Right, State));
                        Range_Result : constant Abstract_Bool :=
                          Compare_Range
                            (Op, Range_Value (Expr.F_Left, State),
                             Range_Value (Expr.F_Right, State));
                     begin
                        if Bool_Result /= Bool_Unknown then
                           return Bool_Result;
                        elsif Int_Result /= Bool_Unknown then
                           return Int_Result;
                        elsif Range_Result /= Bool_Unknown then
                           return Range_Result;
                        elsif Is_Null_Literal (Expr.F_Left)
                          and then Is_Null_Literal (Expr.F_Right)
                        then
                           return Bool_False;
                        else
                           return Bool_Unknown;
                        end if;
                     end;
                  when Libadalang.Common.Ada_Op_Xor =>
                     return Not_Bool (Eq_Bool (Left, Right));
                  when Libadalang.Common.Ada_Op_Lt
                     | Libadalang.Common.Ada_Op_Lte
                     | Libadalang.Common.Ada_Op_Gt
                     | Libadalang.Common.Ada_Op_Gte =>
                     declare
                        Int_Result : constant Abstract_Bool :=
                          Compare_Integers
                            (Op, Integer_Value (Expr.F_Left, State),
                             Integer_Value (Expr.F_Right, State));
                     begin
                        if Int_Result /= Bool_Unknown then
                           return Int_Result;
                        else
                           return Compare_Range
                             (Op, Range_Value (Expr.F_Left, State),
                              Range_Value (Expr.F_Right, State));
                        end if;
                     end;
                  when others =>
                     return Bool_Unknown;
               end case;
            end;

         when Libadalang.Common.Ada_Membership_Expr =>
            declare
               Expr      : constant Libadalang.Analysis.Membership_Expr :=
                 Node.As_Membership_Expr;
               Subject   : constant Abstract_Int :=
                 Integer_Value (Expr.F_Expr, State);
               Known_All : Boolean := True;
               Matches   : Boolean := False;
            begin
               if not Subject.Known then
                  return Bool_Unknown;
               end if;

               for I in 1 .. Expr.F_Membership_Exprs.Children_Count loop
                  declare
                     Alternative : constant Libadalang.Analysis.Ada_Node :=
                       Expr.F_Membership_Exprs.Child (I);
                  begin
                     if Alternative.Kind in Libadalang.Common.Ada_Bin_Op_Range
                       and then Alternative.As_Bin_Op.F_Op =
                         Libadalang.Common.Ada_Op_Double_Dot
                     then
                        declare
                           Left_Bound  : constant Abstract_Int :=
                             Integer_Value
                               (Alternative.As_Bin_Op.F_Left, State);
                           Right_Bound : constant Abstract_Int :=
                             Integer_Value
                               (Alternative.As_Bin_Op.F_Right, State);
                        begin
                           if Left_Bound.Known and then Right_Bound.Known then
                              Matches := Matches or else
                                (Subject.Value >= Left_Bound.Value
                                 and then Subject.Value <= Right_Bound.Value);
                           else
                              Known_All := False;
                           end if;
                        end;
                     else
                        declare
                           Value : constant Abstract_Int :=
                             Integer_Value (Alternative, State);
                        begin
                           if Value.Known then
                              Matches := Matches or else
                                Subject.Value = Value.Value;
                           else
                              Known_All := False;
                           end if;
                        end;
                     end if;
                  end;
               end loop;

               if not Known_All then
                  return Bool_Unknown;
               elsif Expr.F_Op = Libadalang.Common.Ada_Op_In then
                  return Bool_From (Matches);
               else
                  return Bool_From (not Matches);
               end if;
            end;

         when Libadalang.Common.Ada_If_Expr =>
            declare
               If_Node : constant Libadalang.Analysis.If_Expr :=
                 Node.As_If_Expr;

               --  Mirrors Integer_Value's Elsif_Value for the boolean case.
               function Elsif_Value (Index : Positive) return Abstract_Bool is
               begin
                  if Index > If_Node.F_Alternatives.Children_Count then
                     return Boolean_Value (If_Node.F_Else_Expr, State);
                  end if;

                  declare
                     Alt  : constant Libadalang.Analysis.Elsif_Expr_Part :=
                       If_Node.F_Alternatives.Child (Index)
                         .As_Elsif_Expr_Part;
                     Cond : constant Abstract_Bool :=
                       Boolean_Value (Alt.F_Cond_Expr, State);
                  begin
                     if Cond = Bool_True then
                        return Boolean_Value (Alt.F_Then_Expr, State);
                     elsif Cond = Bool_False then
                        return Elsif_Value (Index + 1);
                     else
                        return Bool_Unknown;
                     end if;
                  end;
               end Elsif_Value;

               Cond : constant Abstract_Bool :=
                 Boolean_Value (If_Node.F_Cond_Expr, State);
            begin
               if Cond = Bool_True then
                  return Boolean_Value (If_Node.F_Then_Expr, State);
               elsif Cond = Bool_False then
                  return Elsif_Value (1);
               else
                  return Bool_Unknown;
               end if;
            end;

         when others =>
            return Bool_Unknown;
      end case;
   end Boolean_Value;

   function Mirror_Comparison
     (Op : Libadalang.Common.Ada_Node_Kind_Type)
      return Libadalang.Common.Ada_Node_Kind_Type
   is
   begin
      case Op is
         when Libadalang.Common.Ada_Op_Lt =>
            return Libadalang.Common.Ada_Op_Gt;
         when Libadalang.Common.Ada_Op_Lte =>
            return Libadalang.Common.Ada_Op_Gte;
         when Libadalang.Common.Ada_Op_Gt =>
            return Libadalang.Common.Ada_Op_Lt;
         when Libadalang.Common.Ada_Op_Gte =>
            return Libadalang.Common.Ada_Op_Lte;
         when others =>
            return Op;
      end case;
   end Mirror_Comparison;

   procedure Narrow_Identifier_By_Comparison
     (Key         : Libadalang.Analysis.Ada_Node;
      Op          : Libadalang.Common.Ada_Node_Kind_Type;
      Bound       : Abstract_Int;
      True_State  : in out Flow_State;
      False_State : in out Flow_State)
   is
      Existing    : constant Abstract_Range :=
        Flow_Range_Lookup (True_State, Key);
      True_Range  : Abstract_Range := Existing;
      False_Range : Abstract_Range := Existing;
   begin
      if not Bound.Known or else Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      case Op is
         when Libadalang.Common.Ada_Op_Gt =>
            --  Key > Bound: true narrows Key's low bound up to Bound + 1;
            --  false narrows its high bound down to Bound.
            if not True_Range.Has_Low or else True_Range.Low < Bound.Value + 1
            then
               True_Range := (Has_Low => True, Low => Bound.Value + 1,
                               Has_High => True_Range.Has_High,
                               High => True_Range.High);
            end if;
            if not False_Range.Has_High or else False_Range.High > Bound.Value
            then
               False_Range := (Has_High => True, High => Bound.Value,
                                Has_Low => False_Range.Has_Low,
                                Low => False_Range.Low);
            end if;

         when Libadalang.Common.Ada_Op_Gte =>
            if not True_Range.Has_Low or else True_Range.Low < Bound.Value then
               True_Range := (Has_Low => True, Low => Bound.Value,
                               Has_High => True_Range.Has_High,
                               High => True_Range.High);
            end if;
            if not False_Range.Has_High
              or else False_Range.High > Bound.Value - 1
            then
               False_Range := (Has_High => True, High => Bound.Value - 1,
                                Has_Low => False_Range.Has_Low,
                                Low => False_Range.Low);
            end if;

         when Libadalang.Common.Ada_Op_Lt =>
            if not True_Range.Has_High
              or else True_Range.High > Bound.Value - 1
            then
               True_Range := (Has_High => True, High => Bound.Value - 1,
                               Has_Low => True_Range.Has_Low,
                               Low => True_Range.Low);
            end if;
            if not False_Range.Has_Low or else False_Range.Low < Bound.Value
            then
               False_Range := (Has_Low => True, Low => Bound.Value,
                                Has_High => False_Range.Has_High,
                                High => False_Range.High);
            end if;

         when Libadalang.Common.Ada_Op_Lte =>
            if not True_Range.Has_High or else True_Range.High > Bound.Value
            then
               True_Range := (Has_High => True, High => Bound.Value,
                               Has_Low => True_Range.Has_Low,
                               Low => True_Range.Low);
            end if;
            if not False_Range.Has_Low
              or else False_Range.Low < Bound.Value + 1
            then
               False_Range := (Has_Low => True, Low => Bound.Value + 1,
                                Has_High => False_Range.Has_High,
                                High => False_Range.High);
            end if;

         when Libadalang.Common.Ada_Op_Eq =>
            --  Key = Bound: true pins Key to the single value Bound; false
            --  doesn't imply a bound in either direction, so False_Range
            --  is left as Existing.
            True_Range :=
              (Has_Low => True, Low => Bound.Value,
               Has_High => True, High => Bound.Value);

         when others =>
            return;
      end case;

      Flow_Range_Set (True_State, Key, True_Range);
      Flow_Range_Set (False_State, Key, False_Range);
   exception
      when others =>
         null;
   end Narrow_Identifier_By_Comparison;

   procedure Narrow_By_Condition  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Cond        : Libadalang.Analysis.Ada_Node'Class;
      State       : Flow_State;
      True_State  : out Flow_State;
      False_State : out Flow_State)
   is
   begin
      True_State := State;
      False_State := State;

      if Libadalang.Analysis.Is_Null (Cond) then
         return;
      end if;

      if Cond.Kind = Libadalang.Common.Ada_Paren_Expr then
         Narrow_By_Condition
           (Cond.As_Paren_Expr.F_Expr, State, True_State, False_State);
         return;
      end if;

      if Cond.Kind = Libadalang.Common.Ada_Un_Op
        and then Cond.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Not
      then
         --  "not Inner" is true exactly when Inner is false, so its
         --  narrowed states are Inner's swapped.
         Narrow_By_Condition
           (Cond.As_Un_Op.F_Expr, State, False_State, True_State);
         return;
      end if;

      if Cond.Kind not in Libadalang.Common.Ada_Bin_Op_Range then
         return;
      end if;

      declare
         Expr : constant Libadalang.Analysis.Bin_Op := Cond.As_Bin_Op;
         Op   : constant Libadalang.Common.Ada_Node_Kind_Type := Expr.F_Op;
      begin
         case Op is
            when Libadalang.Common.Ada_Op_And
               | Libadalang.Common.Ada_Op_And_Then =>
               --  Both operands must hold for Cond to be true, so True_State
               --  narrows by each in turn; the false side of a conjunction
               --  can't be narrowed (only one operand need be false).
               declare
                  Left_True, Left_False   : Flow_State;
                  Right_True, Right_False : Flow_State;
               begin
                  Narrow_By_Condition (Expr.F_Left, State, Left_True, Left_False);
                  Narrow_By_Condition
                    (Expr.F_Right, Left_True, Right_True, Right_False);
                  True_State := Right_True;
               end;

            when Libadalang.Common.Ada_Op_Or
               | Libadalang.Common.Ada_Op_Or_Else =>
               --  Symmetric to the conjunction case (De Morgan): neither
               --  operand can hold for Cond to be false.
               declare
                  Left_True, Left_False   : Flow_State;
                  Right_True, Right_False : Flow_State;
               begin
                  Narrow_By_Condition (Expr.F_Left, State, Left_True, Left_False);
                  Narrow_By_Condition
                    (Expr.F_Right, Left_False, Right_True, Right_False);
                  False_State := Right_False;
               end;

            when Libadalang.Common.Ada_Op_Lt | Libadalang.Common.Ada_Op_Lte
               | Libadalang.Common.Ada_Op_Gt | Libadalang.Common.Ada_Op_Gte
               | Libadalang.Common.Ada_Op_Eq =>
               declare
                  Left_Is_Id  : constant Boolean :=
                    Expr.F_Left.Kind = Libadalang.Common.Ada_Identifier;
                  Right_Is_Id : constant Boolean :=
                    Expr.F_Right.Kind = Libadalang.Common.Ada_Identifier;
               begin
                  if Left_Is_Id and then not Right_Is_Id then
                     Narrow_Identifier_By_Comparison
                       (Libadalang.Analysis.Ada_Node
                          (Expr.F_Left.As_Name.P_Referenced_Defining_Name),
                        Op, Integer_Value (Expr.F_Right, State),
                        True_State, False_State);
                  elsif Right_Is_Id and then not Left_Is_Id then
                     Narrow_Identifier_By_Comparison
                       (Libadalang.Analysis.Ada_Node
                          (Expr.F_Right.As_Name.P_Referenced_Defining_Name),
                        Mirror_Comparison (Op), Integer_Value (Expr.F_Left, State),
                        True_State, False_State);
                  end if;
               end;

            when others =>
               null;  --  adalang-analyzer: ignore Null_Statement
         end case;
      end;
   end Narrow_By_Condition;

   function Choice_Interval
     (Choice : Libadalang.Analysis.Ada_Node'Class;
      State  : Flow_State := Empty_Flow_State) return Static_Interval
   is
      Value : constant Abstract_Int := Integer_Value (Choice, State);
   begin
      if Value.Known then
         return (Known => True, Low => Value.Value, High => Value.Value);
      elsif Choice.Kind = Libadalang.Common.Ada_Bin_Op
        and then Choice.As_Bin_Op.F_Op =
          Libadalang.Common.Ada_Op_Double_Dot
      then
         declare
            Low  : constant Abstract_Int :=
              Integer_Value (Choice.As_Bin_Op.F_Left, State);
            High : constant Abstract_Int :=
              Integer_Value (Choice.As_Bin_Op.F_Right, State);
         begin
            if Low.Known and then High.Known then
               return (Known => True, Low => Low.Value, High => High.Value);
            end if;
         end;
      end if;

      return (Known => False, Low => 0, High => 0);
   end Choice_Interval;

end Adalang_Analyzer.Flow_Eval;
