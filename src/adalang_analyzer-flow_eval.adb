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

with Ada.Exceptions;

with Langkit_Support.Text;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config; use Adalang_Analyzer.Config;
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

   --  Whether an operator node computes in a modular type, and with which
   --  modulus when that is known. Modular "+", "-", "*", "**" and unary "-"
   --  wrap instead of overflowing, so their mathematical result is the
   --  Ada result only after reduction: 255 + 1 is 0 for a "mod 256" type
   --  (FP-091).
   type Modular_Info is record
      Is_Modular : Boolean := False;
      Modulus    : Abstract_Int := Unknown_Int;
   end record;

   function Modular_Type_Of
     (Node : Libadalang.Analysis.Ada_Node'Class) return Modular_Info;

   --  The same for a type, of whatever expression or declaration.
   function Modular_Type
     (Typ : Libadalang.Analysis.Base_Type_Decl) return Modular_Info;

   function Expanded_Name_Target
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Dotted_Name
        or else Node.As_Dotted_Name.F_Suffix.Kind /=
          Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      --  A selected component resolves to a component or discriminant; an
      --  expanded name resolves to the entity itself.
      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Node.As_Dotted_Name.F_Suffix.P_Referenced_Decl;
      begin
         if not Libadalang.Analysis.Is_Null (Decl)
           and then Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
                               | Libadalang.Common.Ada_Param_Spec
                               | Libadalang.Common.Ada_For_Loop_Var_Decl
                               | Libadalang.Common.Ada_Enum_Literal_Decl
                               | Libadalang.Common.Ada_Number_Decl
         then
            return Libadalang.Analysis.Ada_Node
              (Node.As_Dotted_Name.F_Suffix);
         end if;
      end;
      return Libadalang.Analysis.No_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Expanded_Name_Target;

   --  Expanded_Name_Target for a name that is only going to be looked up
   --  in State: resolving a name is costly, and a lookup can only find an
   --  object State holds a binding for, so the name is resolved only when
   --  State has a binding spelled like its last identifier.
   function Tracked_Expanded_Name
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Dotted_Name
        or else Binding_Count (State) = 0
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      declare
         Name : constant String :=
           Text_Utils.Normalize_Rule_Name
             (Ada_Text.Node_Text (Node.As_Dotted_Name.F_Suffix));
      begin
         for Index in 1 .. Binding_Count (State) loop
            if Text_Utils.Normalize_Rule_Name
                 (Ada_Text.Node_Text (Binding_At (State, Index).Decl)) = Name
            then
               return Expanded_Name_Target (Node);
            end if;
         end loop;
      end;
      return Libadalang.Analysis.No_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Tracked_Expanded_Name;

   --  The identifier Node stands for when it names an object directly or
   --  by an expanded name; No_Ada_Node otherwise.
   function Object_Identifier
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node is
     (if Libadalang.Analysis.Is_Null (Node)
        then Libadalang.Analysis.No_Ada_Node
      elsif Node.Kind = Libadalang.Common.Ada_Identifier
        then Libadalang.Analysis.Ada_Node (Node)
      else Expanded_Name_Target (Node));

   function Declared_Bound_Value
     (Bound : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Abstract_Int;

   function Is_Two_To_The_63
     (Expr  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Boolean;

   --  The static integer expression of a number declaration. Libadalang
   --  gives every operator in such an expression as universal_integer,
   --  whatever its operands are: in "Wrapped : constant := Byte'(200) +
   --  Byte'(100)" the "+" is that of Byte and the number is 44, and
   --  "Byte'Last + 1" is 0. The types of the operands that are not
   --  operators themselves are given right, so the type of each operator
   --  is worked out from them here (FP-113).
   type Static_Kind is (Not_Static, Universal, Signed, Modular);

   type Static_Integer is record
      Kind    : Static_Kind := Not_Static;
      Value   : Long_Long_Integer := 0;
      Modulus : Long_Long_Integer := 0;
   end record;

   No_Static_Integer  : constant Static_Integer := (others => <>);
   Universal_Expected : constant Static_Integer :=
     (Kind => Universal, others => <>);
   Max_Static_Depth   : constant := 64;

   --  The kind of the type Decl declares or, for an object, is of. The
   --  operands that have a type of their own -- a constant, T'First and
   --  T'Last, a qualified expression -- get their kind from the
   --  declaration they name and not from the type Libadalang gives their
   --  node, which is universal_integer for one that is the whole
   --  expression of a number declaration.
   function Declared_Kind
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Static_Integer
   is
      Typ  : Libadalang.Analysis.Base_Type_Decl;
      Info : Modular_Info;
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return No_Static_Integer;
      elsif Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl then
         Typ := Decl.As_Base_Type_Decl;
      elsif Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range then
         Typ := Decl.As_Object_Decl.F_Type_Expr.P_Designated_Type_Decl;
      else
         return No_Static_Integer;
      end if;

      if Libadalang.Analysis.Is_Null (Typ) then
         return No_Static_Integer;
      end if;

      Info := Modular_Type (Typ);
      if Info.Is_Modular then
         if Info.Modulus.Known then
            return (Kind => Modular, Value => 0,
                    Modulus => Info.Modulus.Value);
         end if;
         return No_Static_Integer;
      elsif Typ.P_Is_Int_Type then
         return (Kind => Signed, others => <>);
      end if;
      return No_Static_Integer;
   exception
      when others =>
         return No_Static_Integer;
   end Declared_Kind;

   --  Value as a result of kind Kind: reduced by the modulus for a modular
   --  type, as it is for any other.
   function Of_Kind
     (Kind : Static_Integer; Value : Abstract_Int) return Static_Integer
   is
   begin
      if not Value.Known or else Kind.Kind = Not_Static then
         return No_Static_Integer;
      elsif Kind.Kind = Modular then
         return (Kind => Modular, Value => Value.Value mod Kind.Modulus,
                 Modulus => Kind.Modulus);
      end if;
      return (Kind => Kind.Kind, Value => Value.Value, Modulus => 0);
   end Of_Kind;

   --  The kind of an operator whose operands are Left and Right, either
   --  way round. Universal when both are: the context then says what the
   --  operator is.
   function Common_Kind
     (Left  : Static_Integer;
      Right : Static_Integer)  --  adalang-analyzer: ignore Swappable_Parameters
      return Static_Integer
   is
   begin
      if Left.Kind = Not_Static or else Right.Kind = Not_Static then
         return No_Static_Integer;
      elsif Left.Kind = Universal then
         return Right;
      elsif Right.Kind = Universal
        or else (Left.Kind = Right.Kind
                 and then Left.Modulus = Right.Modulus)
      then
         return Left;
      end if;
      return No_Static_Integer;
   end Common_Kind;

   function Static_Number
     (Expr     : Libadalang.Analysis.Ada_Node'Class;
      Expected : Static_Integer;
      Depth    : Natural) return Static_Integer
   is
      --  Kind or, for an operator of universal operands, the kind this
      --  context expects.
      function Here (Kind : Static_Integer) return Static_Integer
      is (if Kind.Kind = Universal then Expected else Kind);
   begin
      if Libadalang.Analysis.Is_Null (Expr) or else Depth > Max_Static_Depth
      then
         return No_Static_Integer;
      end if;

      case Expr.Kind is
         when Libadalang.Common.Ada_Paren_Expr =>
            return Static_Number
              (Expr.As_Paren_Expr.F_Expr, Expected, Depth + 1);

         when Libadalang.Common.Ada_Int_Literal =>
            declare
               Parsed : Long_Long_Integer := 0;
            begin
               if Numeric_Literals.Parse_Integer_Text
                    (Ada_Text.Node_Text (Expr), Parsed)
               then
                  return (Kind => Universal, Value => Parsed, Modulus => 0);
               end if;
               return No_Static_Integer;
            end;

         when Libadalang.Common.Ada_Identifier
            | Libadalang.Common.Ada_Dotted_Name =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Expr.As_Name.P_Referenced_Decl;
            begin
               if Libadalang.Analysis.Is_Null (Decl) then
                  return No_Static_Integer;
               elsif Decl.Kind = Libadalang.Common.Ada_Number_Decl then
                  --  A named number is of no type, whatever the type of
                  --  the expression it is declared with.
                  declare
                     Inner : constant Static_Integer :=
                       Static_Number
                         (Decl.As_Number_Decl.F_Expr,
                          Universal_Expected, Depth + 1);
                  begin
                     if Inner.Kind = Not_Static then
                        return No_Static_Integer;
                     end if;
                     return Of_Kind
                       (Universal_Expected, Known_Int (Inner.Value));
                  end;
               elsif Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
               then
                  --  A constant, whose initializer is typed as it is
                  --  written.
                  return Of_Kind
                    (Declared_Kind (Decl),
                     Declared_Bound_Value (Expr, Empty_Flow_State));
               end if;
               return No_Static_Integer;
            end;

         when Libadalang.Common.Ada_Attribute_Ref =>
            --  T'First and T'Last: Declared_Bound_Value knows no other.
            return Of_Kind
              (Declared_Kind
                 (Expr.As_Attribute_Ref.F_Prefix.P_Referenced_Decl),
               Declared_Bound_Value (Expr, Empty_Flow_State));

         when Libadalang.Common.Ada_Qual_Expr =>
            declare
               Target : constant Static_Integer :=
                 Declared_Kind
                   (Expr.As_Qual_Expr.F_Prefix.P_Referenced_Decl);
               Inner  : constant Static_Integer :=
                 (if Target.Kind = Not_Static then No_Static_Integer
                  else Static_Number
                         (Expr.As_Qual_Expr.F_Suffix, Target, Depth + 1));
            begin
               if Inner.Kind = Not_Static
                 or else
                   (Inner.Kind /= Universal
                    and then (Inner.Kind /= Target.Kind
                              or else Inner.Modulus /= Target.Modulus))
               then
                  return No_Static_Integer;
               end if;
               return Of_Kind (Target, Known_Int (Inner.Value));
            end;

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Operand : constant Static_Integer :=
                 Static_Number (Expr.As_Un_Op.F_Expr, Expected, Depth + 1);
               Kind    : constant Static_Integer := Here (Operand);
            begin
               if Kind.Kind = Not_Static then
                  --  "-(2 ** 63)", the first value of a 64-bit type: its
                  --  operand alone is one past Long_Long_Integer'Last.
                  if Expected.Kind /= Modular
                    and then Expr.As_Un_Op.F_Op =
                      Libadalang.Common.Ada_Op_Minus
                    and then Is_Two_To_The_63
                      (Expr.As_Un_Op.F_Expr, Empty_Flow_State)
                  then
                     return Of_Kind
                       (Expected, Known_Int (Long_Long_Integer'First));
                  end if;
                  return No_Static_Integer;
               end if;

               case Expr.As_Un_Op.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Of_Kind (Kind, Known_Int (Operand.Value));
                  when Libadalang.Common.Ada_Op_Minus =>
                     return Of_Kind (Kind, Safe_Sub (0, Operand.Value));
                  when Libadalang.Common.Ada_Op_Abs =>
                     if Operand.Value >= 0 then
                        return Of_Kind (Kind, Known_Int (Operand.Value));
                     end if;
                     return Of_Kind (Kind, Safe_Sub (0, Operand.Value));
                  when others =>
                     return No_Static_Integer;
               end case;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Op    : constant Libadalang.Common.Ada_Node_Kind_Type :=
                 Expr.As_Bin_Op.F_Op;
               Left  : constant Static_Integer :=
                 Static_Number (Expr.As_Bin_Op.F_Left, Expected, Depth + 1);
               --  The exponent is an Integer whatever the base is.
               Right : constant Static_Integer :=
                 Static_Number
                   (Expr.As_Bin_Op.F_Right,
                    (if Op in Libadalang.Common.Ada_Op_Pow
                     then Universal_Expected else Expected),
                    Depth + 1);
               Kind  : constant Static_Integer :=
                 (if Op in Libadalang.Common.Ada_Op_Pow
                  then
                    (if Right.Kind in Universal | Signed
                     then Here (Left)
                     else No_Static_Integer)
                  else Here (Common_Kind (Left, Right)));
            begin
               if Kind.Kind = Not_Static then
                  --  "2 ** 63 - 1", the last value of a 64-bit type.
                  if Expected.Kind /= Modular
                    and then Op in Libadalang.Common.Ada_Op_Minus
                    and then Right.Kind in Universal | Signed
                    and then Right.Value >= 1
                    and then Is_Two_To_The_63
                      (Expr.As_Bin_Op.F_Left, Empty_Flow_State)
                  then
                     return Of_Kind
                       (Expected,
                        Known_Int
                          (Long_Long_Integer'Last - (Right.Value - 1)));
                  end if;
                  return No_Static_Integer;
               end if;

               case Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Of_Kind
                       (Kind, Safe_Add (Left.Value, Right.Value));
                  when Libadalang.Common.Ada_Op_Minus =>
                     return Of_Kind
                       (Kind, Safe_Sub (Left.Value, Right.Value));
                  when Libadalang.Common.Ada_Op_Mult =>
                     return Of_Kind
                       (Kind, Safe_Mul (Left.Value, Right.Value));
                  when Libadalang.Common.Ada_Op_Pow =>
                     return Of_Kind
                       (Kind, Safe_Pow (Left.Value, Right.Value));
                  when Libadalang.Common.Ada_Op_Div =>
                     if Right.Value = 0 then
                        return No_Static_Integer;
                     end if;
                     return Of_Kind
                       (Kind, Known_Int (Left.Value / Right.Value));
                  when Libadalang.Common.Ada_Op_Mod =>
                     if Right.Value = 0 then
                        return No_Static_Integer;
                     end if;
                     return Of_Kind
                       (Kind, Known_Int (Left.Value mod Right.Value));
                  when Libadalang.Common.Ada_Op_Rem =>
                     if Right.Value = 0 then
                        return No_Static_Integer;
                     end if;
                     return Of_Kind
                       (Kind, Known_Int (Left.Value rem Right.Value));
                  when others =>
                     return No_Static_Integer;
               end case;
            end;

         when others =>
            return No_Static_Integer;
      end case;
   exception
      when others =>
         return No_Static_Integer;
   end Static_Number;

   function Named_Number_Value
     (Node : Libadalang.Analysis.Ada_Node'Class) return Abstract_Int
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind not in Libadalang.Common.Ada_Identifier
                               | Libadalang.Common.Ada_Dotted_Name
      then
         return Unknown_Int;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Node.As_Name.P_Referenced_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Decl)
           or else Decl.Kind /= Libadalang.Common.Ada_Number_Decl
         then
            return Unknown_Int;
         end if;

         declare
            Result : constant Static_Integer :=
              Static_Number
                (Decl.As_Number_Decl.F_Expr, Universal_Expected, 0);
         begin
            if Result.Kind = Not_Static then
               return Unknown_Int;
            end if;
            return Known_Int (Result.Value);
         end;
      end;
   exception
      when others =>
         return Unknown_Int;
   end Named_Number_Value;

   function Integer_Value_Unwrapped  --  adalang-analyzer: ignore Cyclomatic_Complexity
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
               Parsed : Long_Long_Integer := 0;
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
            declare
               Held : constant Abstract_Int :=
                 Flow_Lookup
                   (State,
                    Libadalang.Analysis.Ada_Node
                      (Node.As_Name.P_Referenced_Defining_Name));
            begin
               if Held.Known then
                  return Held;
               end if;
               --  State holds no named number.
               return Named_Number_Value (Node);
            end;

         when Libadalang.Common.Ada_Dotted_Name =>
            --  "Pkg.Number"; an object so named was looked up before.
            return Named_Number_Value (Node);

         when Libadalang.Common.Ada_Attribute_Ref =>
            --  T'Size, where T is named outright: T'Base is another
            --  subtype, and the size of an object is the target's affair.
            declare
               Attr : constant Libadalang.Analysis.Attribute_Ref :=
                 Node.As_Attribute_Ref;
               Decl : Libadalang.Analysis.Basic_Decl;
            begin
               if Text_Utils.Normalize_Rule_Name
                    (Ada_Text.Node_Text (Attr.F_Attribute)) /= "size"
                 or else Attr.F_Prefix.Kind not in
                   Libadalang.Common.Ada_Identifier
                     | Libadalang.Common.Ada_Dotted_Name
                 or else
                   (not Libadalang.Analysis.Is_Null (Attr.F_Args)
                    and then Attr.F_Args.Children_Count > 0)
               then
                  return Unknown_Int;
               end if;

               Decl := Attr.F_Prefix.P_Referenced_Decl;
               if Libadalang.Analysis.Is_Null (Decl)
                 or else Decl.Kind not in Libadalang.Common.Ada_Base_Type_Decl
               then
                  return Unknown_Int;
               end if;
               return Type_Size (Decl.As_Base_Type_Decl);
            end;

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
   end Integer_Value_Unwrapped;

   function Integer_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State := Empty_Flow_State) return Abstract_Int
   is
      Target : constant Libadalang.Analysis.Ada_Node :=
        Tracked_Expanded_Name (Node, State);
      Result : constant Abstract_Int :=
        (if Libadalang.Analysis.Is_Null (Target)
         then Integer_Value_Unwrapped (Node, State)
         else Integer_Value_Unwrapped (Target, State));
   begin
      if not Result.Known
        or else Node.Kind not in Libadalang.Common.Ada_Un_Op
                               | Libadalang.Common.Ada_Bin_Op_Range
      then
         return Result;
      end if;

      declare
         Modular : constant Modular_Info := Modular_Type_Of (Node);
      begin
         if not Modular.Is_Modular then
            return Result;
         elsif Modular.Modulus.Known then
            return Known_Int (Result.Value mod Modular.Modulus.Value);
         end if;
         return Unknown_Int;
      end;
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

   function Range_Value_Unwrapped
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Abstract_Range
   is
      function From_Endpoints
        (Low, High : Abstract_Int) return Abstract_Range
      is
      begin
         if Low.Known and then High.Known and then Low.Value <= High.Value then
            return
              (Has_Low => True, Low => Low.Value,
               Has_High => True, High => High.Value);
         end if;
         return Unknown_Range;
      end From_Endpoints;

      function Safe_Divide
        (Left, Right : Long_Long_Integer) return Abstract_Int
      is
      begin
         if Right = 0
           or else
             (Left = Long_Long_Integer'First and then Right = -1)
         then
            return Unknown_Int;
         end if;
         return Known_Int (Left / Right);
      end Safe_Divide;
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
      elsif Node.Kind = Libadalang.Common.Ada_Qual_Expr then
         return Range_Value (Node.As_Qual_Expr.F_Suffix, State);
      elsif Node.Kind = Libadalang.Common.Ada_Un_Op then
         declare
            Expr  : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
            Value : constant Abstract_Range :=
              Range_Value (Expr.F_Expr, State);
         begin
            if Expr.F_Op = Libadalang.Common.Ada_Op_Plus then
               return Value;
            elsif Expr.F_Op = Libadalang.Common.Ada_Op_Minus
              and then Value.Has_Low
              and then Value.Has_High
              and then Value.Low /= Long_Long_Integer'First
              and then Value.High /= Long_Long_Integer'First
            then
               return
                 (Has_Low => True, Low => -Value.High,
                  Has_High => True, High => -Value.Low);
            end if;
            return Unknown_Range;
         end;
      elsif Node.Kind in Libadalang.Common.Ada_Bin_Op_Range then
         declare
            Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
            Left  : constant Abstract_Range :=
              Range_Value (Expr.F_Left, State);
            Right : constant Abstract_Range :=
              Range_Value (Expr.F_Right, State);
         begin
            if not Left.Has_Low
              or else not Left.Has_High
              or else not Right.Has_Low
              or else not Right.Has_High
            then
               return Range_From_Int (Integer_Value (Node, State));
            end if;

            case Expr.F_Op is
               when Libadalang.Common.Ada_Op_Plus =>
                  return From_Endpoints
                    (Safe_Add (Left.Low, Right.Low),
                     Safe_Add (Left.High, Right.High));

               when Libadalang.Common.Ada_Op_Minus =>
                  return From_Endpoints
                    (Safe_Sub (Left.Low, Right.High),
                     Safe_Sub (Left.High, Right.Low));

               when Libadalang.Common.Ada_Op_Mult =>
                  declare
                     P1 : constant Abstract_Int :=
                       Safe_Mul (Left.Low, Right.Low);
                     P2 : constant Abstract_Int :=
                       Safe_Mul (Left.Low, Right.High);
                     P3 : constant Abstract_Int :=
                       Safe_Mul (Left.High, Right.Low);
                     P4 : constant Abstract_Int :=
                       Safe_Mul (Left.High, Right.High);
                  begin
                     if not P1.Known
                       or else not P2.Known
                       or else not P3.Known
                       or else not P4.Known
                     then
                        return Unknown_Range;
                     end if;
                     return
                       (Has_Low => True,
                        Low => Long_Long_Integer'Min
                          (Long_Long_Integer'Min (P1.Value, P2.Value),
                           Long_Long_Integer'Min (P3.Value, P4.Value)),
                        Has_High => True,
                        High => Long_Long_Integer'Max
                          (Long_Long_Integer'Max (P1.Value, P2.Value),
                           Long_Long_Integer'Max (P3.Value, P4.Value)));
                  end;

               when Libadalang.Common.Ada_Op_Div =>
                  if Right.Low <= 0 and then Right.High >= 0 then
                     return Unknown_Range;
                  end if;
                  declare
                     Q1 : constant Abstract_Int :=
                       Safe_Divide (Left.Low, Right.Low);
                     Q2 : constant Abstract_Int :=
                       Safe_Divide (Left.Low, Right.High);
                     Q3 : constant Abstract_Int :=
                       Safe_Divide (Left.High, Right.Low);
                     Q4 : constant Abstract_Int :=
                       Safe_Divide (Left.High, Right.High);
                  begin
                     if not Q1.Known
                       or else not Q2.Known
                       or else not Q3.Known
                       or else not Q4.Known
                     then
                        return Unknown_Range;
                     end if;
                     return
                       (Has_Low => True,
                        Low => Long_Long_Integer'Min
                          (Long_Long_Integer'Min (Q1.Value, Q2.Value),
                           Long_Long_Integer'Min (Q3.Value, Q4.Value)),
                        Has_High => True,
                        High => Long_Long_Integer'Max
                          (Long_Long_Integer'Max (Q1.Value, Q2.Value),
                           Long_Long_Integer'Max (Q3.Value, Q4.Value)));
                  end;

               when others =>
                  return Range_From_Int (Integer_Value (Node, State));
            end case;
         end;
      else
         return Range_From_Int (Integer_Value (Node, State));
      end if;
   end Range_Value_Unwrapped;

   function Range_Value
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Abstract_Range
   is
      Target : constant Libadalang.Analysis.Ada_Node :=
        Tracked_Expanded_Name (Node, State);
      Result : constant Abstract_Range :=
        (if Libadalang.Analysis.Is_Null (Target)
         then Range_Value_Unwrapped (Node, State)
         else Range_Value_Unwrapped (Target, State));
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind not in Libadalang.Common.Ada_Un_Op
                               | Libadalang.Common.Ada_Bin_Op_Range
      then
         return Result;
      end if;

      declare
         Modular : constant Modular_Info := Modular_Type_Of (Node);
      begin
         if not Modular.Is_Modular
           or else
             (Result.Has_Low and then Result.Has_High
              and then Result.Low >= 0
              and then Modular.Modulus.Known
              and then Result.High < Modular.Modulus.Value)
         then
            return Result;
         elsif Modular.Modulus.Known then
            --  Somewhere in the computed interval the operation wraps, so
            --  only the type's own range is left.
            return
              (Has_Low => True, Low => 0,
               Has_High => True, High => Modular.Modulus.Value - 1);
         end if;
         return Unknown_Range;
      end;
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
            elsif Left.Has_Low and then Left.Has_High
              and then Right.Has_Low and then Right.Has_High
              and then Left.Low = Left.High
              and then Right.Low = Right.High
              and then Left.Low = Right.Low
            then
               --  Each side has one value, the same one.
               return Bool_True;
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
      elsif not Libadalang.Analysis.Is_Null
                  (Tracked_Expanded_Name (Node, State))
      then
         return Boolean_Value (Tracked_Expanded_Name (Node, State), State);
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
   exception
      when others =>
         return Bool_Unknown;
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
      when Exc : others =>
         Log_Verbose_Once
           ("skipping comparison narrowing: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Narrow_Identifier_By_Comparison;

   --  State narrowed by the two outcomes of a membership test taken as
   --  "in", whatever its own operator: Member is the state in which the
   --  tested identifier belongs to one of the alternatives, Other the one
   --  in which it belongs to none.
   type Membership_States is record
      Member : Flow_State;
      Other  : Flow_State;
   end record;

   --  Narrows the tracked range of the identifier tested by Expr. As with
   --  a comparison, an outcome the tracked range already rules out gets an
   --  empty range (Low > High), which marks that state as infeasible and
   --  adds nothing to a later join.
   function Narrow_Identifier_By_Membership
     (Expr  : Libadalang.Analysis.Membership_Expr;
      State : Flow_State) return Membership_States
   is
      --  Bounds holds every member of one alternative; Exact says that
      --  every value within Bounds is a member too, which is what excluding
      --  the alternative on the "not a member" side needs.
      type Alternative_Set is record
         Bounds : Abstract_Range := Unknown_Range;
         Exact  : Boolean := False;
      end record;

      function Is_Empty (Bounds : Abstract_Range) return Boolean is
        (Bounds.Has_Low and then Bounds.Has_High
         and then Bounds.Low > Bounds.High);

      function Set_Of
        (Alternative : Libadalang.Analysis.Ada_Node) return Alternative_Set
      is
         Result : Alternative_Set;
      begin
         if Alternative.Kind in Libadalang.Common.Ada_Bin_Op_Range
           and then Alternative.As_Bin_Op.F_Op =
             Libadalang.Common.Ada_Op_Double_Dot
         then
            declare
               Low  : constant Abstract_Int :=
                 Integer_Value (Alternative.As_Bin_Op.F_Left, State);
               High : constant Abstract_Int :=
                 Integer_Value (Alternative.As_Bin_Op.F_Right, State);
            begin
               Result.Bounds :=
                 (Has_Low => Low.Known, Low => Low.Value,
                  Has_High => High.Known, High => High.Value);
               Result.Exact := Low.Known and then High.Known;
            end;
            return Result;
         end if;

         if Alternative.Kind in Libadalang.Common.Ada_Name then
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Alternative.As_Name.P_Referenced_Decl;
            begin
               if not Libadalang.Analysis.Is_Null (Decl)
                 and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
               then
                  --  A subtype mark: Type_Range resolves only the bounds
                  --  that still hold their elaboration-time value.
                  Result.Bounds := Type_Range (Decl.As_Base_Type_Decl, State);
                  Result.Exact :=
                    Result.Bounds.Has_Low and then Result.Bounds.Has_High
                    and then not Has_Subtype_Predicate
                      (Decl.As_Base_Type_Decl);
                  return Result;
               end if;
            end;
         end if;

         declare
            Value : constant Abstract_Int :=
              Integer_Value (Alternative, State);
         begin
            if Value.Known then
               Result := (Bounds => Range_From_Int (Value), Exact => True);
            end if;
         end;
         return Result;
      end Set_Of;

      Result : Membership_States := (Member => State, Other => State);
      Count  : constant Natural := Expr.F_Membership_Exprs.Children_Count;
      Sets   : array (1 .. Count) of Alternative_Set;
      Key    : Libadalang.Analysis.Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Object_Identifier (Expr.F_Expr)) then
         return Result;
      end if;
      Key := Libadalang.Analysis.Ada_Node
        (Object_Identifier (Expr.F_Expr).As_Name
           .P_Referenced_Defining_Name);
      if Libadalang.Analysis.Is_Null (Key) then
         return Result;
      end if;

      for I in Sets'Range loop
         Sets (I) := Set_Of (Expr.F_Membership_Exprs.Child (I));
      end loop;

      --  A member lies within the hull of the alternatives that can hold
      --  anything at all.
      declare
         Existing : constant Abstract_Range := Flow_Range_Lookup (State, Key);
         Hull     : Abstract_Range := Unknown_Range;
         Seen     : Boolean := False;
         Narrowed : Abstract_Range := Existing;
      begin
         for Set of Sets loop
            if not Is_Empty (Set.Bounds) then
               if Seen then
                  Hull := Range_Union (Hull, Set.Bounds);
               else
                  Hull := Set.Bounds;
                  Seen := True;
               end if;
            end if;
         end loop;

         if Seen then
            if Hull.Has_Low
              and then (not Narrowed.Has_Low or else Narrowed.Low < Hull.Low)
            then
               Narrowed.Has_Low := True;
               Narrowed.Low := Hull.Low;
            end if;
            if Hull.Has_High
              and then
                (not Narrowed.Has_High or else Narrowed.High > Hull.High)
            then
               Narrowed.Has_High := True;
               Narrowed.High := Hull.High;
            end if;
            if Narrowed /= Existing then
               Flow_Range_Set (Result.Member, Key, Narrowed);
            end if;
         end if;
      end;

      --  A non-member is outside every alternative, but an interval can
      --  only drop an alternative that covers one of its own ends. Repeat
      --  until stable, so that trimming one end past an alternative lets
      --  the next alternative trim it further.
      declare
         Existing : constant Abstract_Range := Flow_Range_Lookup (State, Key);
         Narrowed : Abstract_Range := Existing;
         Changed  : Boolean := True;
      begin
         while Changed and then not Is_Empty (Narrowed) loop
            Changed := False;
            for Set of Sets loop
               if Set.Exact and then not Is_Empty (Set.Bounds)
                 and then not Is_Empty (Narrowed)
               then
                  declare
                     Trimmed : Abstract_Range := Narrowed;
                  begin
                     if Trimmed.Has_Low
                       and then Trimmed.Low in
                         Set.Bounds.Low .. Set.Bounds.High
                       and then Set.Bounds.High < Long_Long_Integer'Last
                     then
                        Trimmed.Low := Set.Bounds.High + 1;
                     end if;
                     if Trimmed.Has_High
                       and then Trimmed.High in
                         Set.Bounds.Low .. Set.Bounds.High
                       and then Set.Bounds.Low > Long_Long_Integer'First
                     then
                        Trimmed.High := Set.Bounds.Low - 1;
                     end if;
                     if Trimmed /= Narrowed then
                        Narrowed := Trimmed;
                        Changed := True;
                     end if;
                  end;
               end if;
            end loop;
         end loop;

         if Narrowed /= Existing then
            Flow_Range_Set (Result.Other, Key, Narrowed);
         end if;
      end;

      return Result;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping membership narrowing: " &
            Ada.Exceptions.Exception_Message (Exc));
         return (Member => State, Other => State);
   end Narrow_Identifier_By_Membership;

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

      if Cond.Kind = Libadalang.Common.Ada_Membership_Expr then
         declare
            Narrowed : constant Membership_States :=
              Narrow_Identifier_By_Membership
                (Cond.As_Membership_Expr, State);
         begin
            --  "not in" is true exactly when "in" is false, as for "not".
            if Cond.As_Membership_Expr.F_Op = Libadalang.Common.Ada_Op_In
            then
               True_State := Narrowed.Member;
               False_State := Narrowed.Other;
            else
               True_State := Narrowed.Other;
               False_State := Narrowed.Member;
            end if;
         end;
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
                  Left_Id     : constant Libadalang.Analysis.Ada_Node :=
                    Object_Identifier (Expr.F_Left);
                  Right_Id    : constant Libadalang.Analysis.Ada_Node :=
                    Object_Identifier (Expr.F_Right);
                  Left_Is_Id  : constant Boolean :=
                    not Libadalang.Analysis.Is_Null (Left_Id);
                  Right_Is_Id : constant Boolean :=
                    not Libadalang.Analysis.Is_Null (Right_Id);
               begin
                  if Left_Is_Id and then not Right_Is_Id then
                     Narrow_Identifier_By_Comparison
                       (Libadalang.Analysis.Ada_Node
                          (Left_Id.As_Name.P_Referenced_Defining_Name),
                        Op, Integer_Value (Expr.F_Right, State),
                        True_State, False_State);
                  elsif Right_Is_Id and then not Left_Is_Id then
                     Narrow_Identifier_By_Comparison
                       (Libadalang.Analysis.Ada_Node
                          (Right_Id.As_Name.P_Referenced_Defining_Name),
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

   --  True when Expr still has the value it had when the declaration it
   --  belongs to was elaborated: every name in it denotes a constant, a
   --  named number, an "in" parameter, a loop parameter, an enumeration
   --  literal, a subtype or a package. A subtype or array bound that reads a
   --  variable was fixed at elaboration, so the variable's value in a later
   --  state says nothing about it (FP-087).
   function Is_Elaboration_Stable
     (Expr : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      function Is_Stable_Name
        (Name : Libadalang.Analysis.Name) return Boolean
      is
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Decl) then
            return False;
         end if;

         case Decl.Kind is
            when Libadalang.Common.Ada_Number_Decl
               | Libadalang.Common.Ada_For_Loop_Var_Decl
               | Libadalang.Common.Ada_Enum_Literal_Decl
               | Libadalang.Common.Ada_Base_Type_Decl
               | Libadalang.Common.Ada_Base_Package_Decl
               | Libadalang.Common.Ada_Package_Renaming_Decl
               | Libadalang.Common.Ada_Generic_Package_Instantiation =>
               return True;
            when Libadalang.Common.Ada_Object_Decl_Range =>
               return Decl.As_Object_Decl.F_Has_Constant
                 and then Libadalang.Analysis.Is_Null
                   (Decl.As_Object_Decl.F_Renaming_Clause);
            when Libadalang.Common.Ada_Param_Spec =>
               return Decl.As_Param_Spec.F_Mode.Kind in
                 Libadalang.Common.Ada_Mode_In
                   | Libadalang.Common.Ada_Mode_Default;
            when others =>
               return False;
         end case;
      end Is_Stable_Name;
   begin
      if Libadalang.Analysis.Is_Null (Expr) then
         return False;
      end if;

      case Expr.Kind is
         when Libadalang.Common.Ada_Identifier =>
            return Is_Stable_Name (Expr.As_Name);
         when Libadalang.Common.Ada_Attribute_Ref =>
            --  The attribute designator is an identifier node too, but
            --  names nothing.
            return Is_Elaboration_Stable (Expr.As_Attribute_Ref.F_Prefix)
              and then
                (Libadalang.Analysis.Is_Null (Expr.As_Attribute_Ref.F_Args)
                 or else Is_Elaboration_Stable
                   (Expr.As_Attribute_Ref.F_Args));
         when others =>
            for I in 1 .. Expr.Children_Count loop
               if not Libadalang.Analysis.Is_Null (Expr.Child (I))
                 and then not Is_Elaboration_Stable (Expr.Child (I))
               then
                  return False;
               end if;
            end loop;
            return True;
      end case;
   exception
      when others =>
         return False;
   end Is_Elaboration_Stable;

   --  True when Expr is 2 ** 63, written as that power or as a literal,
   --  parenthesized or not: the magnitude a 64-bit type's first value is
   --  written with, which Long_Long_Integer cannot hold, so the ordinary
   --  evaluation reports it unknown.
   function Is_Two_To_The_63
     (Expr  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Expr) then
         return False;
      elsif Expr.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Is_Two_To_The_63 (Expr.As_Paren_Expr.F_Expr, State);
      elsif Expr.Kind = Libadalang.Common.Ada_Int_Literal then
         declare
            Image  : constant String := Ada_Text.Node_Text (Expr);
            Digit  : String (1 .. Image'Length);
            Length : Natural := 0;
         begin
            for Item of Image loop
               if Item /= '_' then
                  Length := Length + 1;
                  Digit (Length) := Item;
               end if;
            end loop;
            return Digit (1 .. Length) in
              "9223372036854775808" | "16#8000000000000000#";
         end;
      elsif Expr.Kind not in Libadalang.Common.Ada_Bin_Op_Range
        or else Expr.As_Bin_Op.F_Op /= Libadalang.Common.Ada_Op_Pow
      then
         return False;
      end if;

      declare
         Base     : constant Abstract_Int :=
           Declared_Bound_Value (Expr.As_Bin_Op.F_Left, State);
         Exponent : constant Abstract_Int :=
           Declared_Bound_Value (Expr.As_Bin_Op.F_Right, State);
      begin
         return Base.Known and then Base.Value = 2
           and then Exponent.Known and then Exponent.Value = 63;
      end;
   end Is_Two_To_The_63;

   --  The value a bound written in a declaration had when that declaration
   --  was elaborated: "T'First" / "T'Last" of an integer subtype, or any
   --  elaboration-stable expression Integer_Value can fold in State.
   function Declared_Bound_Value
     (Bound : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Abstract_Int
   is
      --  Value, the mathematical result of the operator Bound, as the
      --  operator gives it: reduced by the modulus when Bound is of a
      --  modular type, whose arithmetic wraps (FP-113).
      function Wrapped (Value : Abstract_Int) return Abstract_Int is
      begin
         if not Value.Known then
            return Value;
         end if;

         declare
            Modular : constant Modular_Info := Modular_Type_Of (Bound);
         begin
            if not Modular.Is_Modular then
               return Value;
            elsif Modular.Modulus.Known then
               return Known_Int (Value.Value mod Modular.Modulus.Value);
            end if;
            return Unknown_Int;
         end;
      end Wrapped;
   begin
      if Libadalang.Analysis.Is_Null (Bound) then
         return Unknown_Int;
      end if;

      if Bound.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Declared_Bound_Value (Bound.As_Paren_Expr.F_Expr, State);
      end if;

      if Bound.Kind = Libadalang.Common.Ada_Attribute_Ref then
         declare
            Attr : constant Libadalang.Analysis.Attribute_Ref :=
              Bound.As_Attribute_Ref;
            Name : constant String :=
              Text_Utils.Normalize_Rule_Name
                (Ada_Text.Node_Text (Attr.F_Attribute));
            Decl : Libadalang.Analysis.Basic_Decl :=
              Libadalang.Analysis.No_Basic_Decl;
         begin
            if Name in "first" | "last"
              and then
                (Libadalang.Analysis.Is_Null (Attr.F_Args)
                 or else Attr.F_Args.Children_Count = 0)
            then
               Decl := Attr.F_Prefix.P_Referenced_Decl;
            end if;

            if not Libadalang.Analysis.Is_Null (Decl)
              and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
            then
               declare
                  Prefix_Range : constant Abstract_Range :=
                    Type_Range (Decl.As_Base_Type_Decl, State);
               begin
                  if Name = "first" and then Prefix_Range.Has_Low then
                     return Known_Int (Prefix_Range.Low);
                  elsif Name = "last" and then Prefix_Range.Has_High then
                     return Known_Int (Prefix_Range.High);
                  end if;
               end;
            end if;
            return Unknown_Int;
         end;
      end if;

      if not Is_Elaboration_Stable (Bound) then
         return Unknown_Int;
      end if;

      declare
         Folded : constant Abstract_Int := Integer_Value (Bound, State);
      begin
         if Folded.Known then
            return Folded;
         end if;
      end;

      --  State tracks neither named numbers nor constants declared outside
      --  the subprogram under analysis, so follow those to their own
      --  initializers, through the arithmetic a bound is usually written
      --  with ("Max - 1").
      case Bound.Kind is
         when Libadalang.Common.Ada_Identifier
            | Libadalang.Common.Ada_Dotted_Name =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Bound.As_Name.P_Referenced_Decl;
            begin
               if Libadalang.Analysis.Is_Null (Decl) then
                  return Unknown_Int;
               elsif Decl.Kind = Libadalang.Common.Ada_Number_Decl then
                  return Named_Number_Value (Bound);
               elsif Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range then
                  --  Is_Elaboration_Stable has established it is a
                  --  constant.
                  return Declared_Bound_Value
                    (Decl.As_Object_Decl.F_Default_Expr, State);
               end if;
               return Unknown_Int;
            end;

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Operand : constant Abstract_Int :=
                 Declared_Bound_Value (Bound.As_Un_Op.F_Expr, State);
            begin
               if not Operand.Known then
                  --  "-(2 ** 63)", the first value of a 64-bit type: its
                  --  operand alone is one past Long_Long_Integer'Last.
                  if Bound.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Minus
                    and then Is_Two_To_The_63 (Bound.As_Un_Op.F_Expr, State)
                  then
                     return Known_Int (Long_Long_Integer'First);
                  end if;
                  return Unknown_Int;
               elsif Bound.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Plus then
                  return Operand;
               elsif Bound.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Minus then
                  return Wrapped (Safe_Sub (0, Operand.Value));
               end if;
               return Unknown_Int;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Left  : constant Abstract_Int :=
                 Declared_Bound_Value (Bound.As_Bin_Op.F_Left, State);
               Right : constant Abstract_Int :=
                 Declared_Bound_Value (Bound.As_Bin_Op.F_Right, State);
            begin
               --  "2 ** 63 - 1", the last value of a 64-bit type, by the
               --  same token.
               if not Left.Known and then Right.Known
                 and then Right.Value >= 1
                 and then Bound.As_Bin_Op.F_Op =
                   Libadalang.Common.Ada_Op_Minus
                 and then Is_Two_To_The_63 (Bound.As_Bin_Op.F_Left, State)
               then
                  return Known_Int
                    (Long_Long_Integer'Last - (Right.Value - 1));
               end if;

               if not Left.Known or else not Right.Known then
                  return Unknown_Int;
               end if;

               case Libadalang.Common.Ada_Node_Kind_Type'
                 (Bound.As_Bin_Op.F_Op)
               is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Wrapped (Safe_Add (Left.Value, Right.Value));
                  when Libadalang.Common.Ada_Op_Minus =>
                     return Wrapped (Safe_Sub (Left.Value, Right.Value));
                  when Libadalang.Common.Ada_Op_Mult =>
                     return Wrapped (Safe_Mul (Left.Value, Right.Value));
                  when Libadalang.Common.Ada_Op_Pow =>
                     return Wrapped (Safe_Pow (Left.Value, Right.Value));
                  when others =>
                     return Unknown_Int;
               end case;
            end;

         when others =>
            return Unknown_Int;
      end case;
   exception
      when others =>
         return Unknown_Int;
   end Declared_Bound_Value;

   --  0 .. Modulus - 1 when Typ is a modular type, or a subtype or derived
   --  type of one that adds no range constraint of its own; Unknown_Range
   --  otherwise, including for a modulus Long_Long_Integer cannot hold.
   function Unconstrained_Modular_Range
     (Typ   : Libadalang.Analysis.Base_Type_Decl;
      State : Flow_State) return Abstract_Range
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
      Parent    : Libadalang.Analysis.Subtype_Indication;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return Unknown_Range;
         elsif Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            Parent := Current.As_Subtype_Decl.F_Subtype;
         elsif Current.Kind not in Libadalang.Common.Ada_Type_Decl then
            return Unknown_Range;
         elsif Current.As_Type_Decl.F_Type_Def.Kind =
           Libadalang.Common.Ada_Mod_Int_Type_Def
         then
            declare
               Modulus : constant Abstract_Int :=
                 Declared_Bound_Value
                   (Current.As_Type_Decl.F_Type_Def.As_Mod_Int_Type_Def
                      .F_Expr,
                    State);
            begin
               if Modulus.Known and then Modulus.Value >= 1 then
                  return
                    (Has_Low => True, Low => 0,
                     Has_High => True, High => Modulus.Value - 1);
               end if;
               return Unknown_Range;
            end;
         elsif Current.As_Type_Decl.F_Type_Def.Kind =
           Libadalang.Common.Ada_Derived_Type_Def
         then
            Parent :=
              Current.As_Type_Decl.F_Type_Def.As_Derived_Type_Def
                .F_Subtype_Indication;
         else
            return Unknown_Range;
         end if;

         if not Libadalang.Analysis.Is_Null (Parent.F_Constraint) then
            return Unknown_Range;
         end if;
         Current := Parent.P_Designated_Type_Decl;
      end loop;
      return Unknown_Range;
   exception
      when others =>
         return Unknown_Range;
   end Unconstrained_Modular_Range;

   function Modular_Type_Of
     (Node : Libadalang.Analysis.Ada_Node'Class) return Modular_Info
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind not in Libadalang.Common.Ada_Expr
      then
         return (others => <>);
      end if;
      return Modular_Type (Node.As_Expr.P_Expression_Type);
   exception
      when others =>
         --  An operator whose type cannot be resolved is not assumed to be
         --  free of wrap-around.
         return (Is_Modular => True, Modulus => Unknown_Int);
   end Modular_Type_Of;

   function Modular_Type
     (Typ : Libadalang.Analysis.Base_Type_Decl) return Modular_Info
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return (others => <>);
         elsif Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            Current :=
              Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
         elsif Current.Kind not in Libadalang.Common.Ada_Type_Decl then
            return (others => <>);
         elsif Current.As_Type_Decl.F_Type_Def.Kind =
           Libadalang.Common.Ada_Mod_Int_Type_Def
         then
            declare
               Modulus : constant Abstract_Int :=
                 Declared_Bound_Value
                   (Current.As_Type_Decl.F_Type_Def.As_Mod_Int_Type_Def
                      .F_Expr,
                    Empty_Flow_State);
            begin
               return
                 (Is_Modular => True,
                  Modulus    =>
                    (if Modulus.Known and then Modulus.Value >= 1
                     then Modulus else Unknown_Int));
            end;
         elsif Current.As_Type_Decl.F_Type_Def.Kind =
           Libadalang.Common.Ada_Derived_Type_Def
         then
            Current :=
              Current.As_Type_Decl.F_Type_Def.As_Derived_Type_Def
                .F_Subtype_Indication.P_Designated_Type_Decl;
         elsif Current.As_Type_Decl.F_Type_Def.Kind =
           Libadalang.Common.Ada_Private_Type_Def
         then
            --  A private type may be completed by a modular one.
            return (Is_Modular => True, Modulus => Unknown_Int);
         else
            return (others => <>);
         end if;
      end loop;
      return (Is_Modular => True, Modulus => Unknown_Int);
   exception
      when others =>
         --  A type that cannot be followed to its definition is not
         --  assumed to be free of wrap-around.
         return (Is_Modular => True, Modulus => Unknown_Int);
   end Modular_Type;

   function Expression_Modulus
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Is_Modular : out Boolean) return Abstract_Int
   is
      Info : constant Modular_Info := Modular_Type_Of (Node);
   begin
      Is_Modular := Info.Is_Modular;
      return Info.Modulus;
   end Expression_Modulus;

   function Type_Range
     (Typ   : Libadalang.Analysis.Base_Type_Decl;
      State : Flow_State) return Abstract_Range
   is
      Result : Abstract_Range := Unknown_Range;
   begin
      if Libadalang.Analysis.Is_Null (Typ)
        or else not Typ.P_Is_Int_Type
      then
         return Result;
      end if;

      Result := Unconstrained_Modular_Range (Typ, State);
      if Result.Has_Low and then Result.Has_High then
         return Result;
      end if;
      Result := Unknown_Range;

      declare
         Bounds : constant Libadalang.Analysis.Discrete_Range :=
           Typ.P_Discrete_Range;
         Low    : constant Abstract_Int :=
           Declared_Bound_Value
             (Libadalang.Analysis.Low_Bound (Bounds), State);
         High   : constant Abstract_Int :=
           Declared_Bound_Value
             (Libadalang.Analysis.High_Bound (Bounds), State);
      begin
         if Low.Known then
            Result.Has_Low := True;
            Result.Low := Low.Value;
         end if;
         if High.Known then
            Result.Has_High := True;
            Result.High := High.Value;
         end if;
      end;
      return Result;
   exception
      when others =>
         return Unknown_Range;
   end Type_Range;

   --  The number of bits the values of Bounds take: without a sign bit
   --  unless one of them is negative, and none when there is no value.
   function Bits_For (Bounds : Abstract_Range) return Abstract_Int is
      Widest : constant := 64;
   begin
      if not (Bounds.Has_Low and then Bounds.Has_High) then
         return Unknown_Int;
      elsif Bounds.Low > Bounds.High then
         return Known_Int (0);
      elsif Bounds.Low >= 0 then
         for Bits in 0 .. Widest - 2 loop
            if Bounds.High < 2 ** Bits then
               return Known_Int (Long_Long_Integer (Bits));
            end if;
         end loop;
         return Known_Int (Widest - 1);
      end if;

      for Bits in 1 .. Widest - 1 loop
         if Bounds.Low >= -(2 ** (Bits - 1))
           and then Bounds.High <= 2 ** (Bits - 1) - 1
         then
            return Known_Int (Long_Long_Integer (Bits));
         end if;
      end loop;
      return Known_Int (Widest);
   end Bits_For;

   --  N when Expr, the modulus of a modular type, is written "2 ** N":
   --  the type then takes N bits, also where 2 ** N is more than
   --  Long_Long_Integer holds. Unknown_Int otherwise.
   function Power_Of_Two_Bits
     (Expr : Libadalang.Analysis.Ada_Node'Class) return Abstract_Int
   is
      Widest_Modulus : constant := 128;
   begin
      if Libadalang.Analysis.Is_Null (Expr) then
         return Unknown_Int;
      elsif Expr.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Power_Of_Two_Bits (Expr.As_Paren_Expr.F_Expr);
      elsif Expr.Kind not in Libadalang.Common.Ada_Bin_Op_Range
        or else Expr.As_Bin_Op.F_Op /= Libadalang.Common.Ada_Op_Pow
      then
         return Unknown_Int;
      end if;

      declare
         Base     : constant Abstract_Int :=
           Declared_Bound_Value (Expr.As_Bin_Op.F_Left, Empty_Flow_State);
         Exponent : constant Abstract_Int :=
           Declared_Bound_Value (Expr.As_Bin_Op.F_Right, Empty_Flow_State);
      begin
         if Base.Known and then Base.Value = 2
           and then Exponent.Known
           and then Exponent.Value in 0 .. Widest_Modulus
         then
            return Exponent;
         end if;
         return Unknown_Int;
      end;
   end Power_Of_Two_Bits;

   function Type_Size
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return Abstract_Int
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl :=
        (if Libadalang.Analysis.Is_Null (Typ)
         then Libadalang.Analysis.No_Base_Type_Decl
         else Typ.As_Base_Type_Decl);

      function Aspect_Named
        (Name : Wide_Wide_String) return Libadalang.Analysis.Aspect
      is (Current.P_Get_Aspect
            (Langkit_Support.Text.To_Unbounded_Text (Name)));

      --  The size of Current from the range of its values. Type_Range
      --  gives none for a type that is not an integer type.
      function From_Range return Abstract_Int
      is (Bits_For (Type_Range (Current, Empty_Flow_State)));
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return Unknown_Int;
         elsif Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            --  A subtype that adds a constraint has the size of its own
            --  values; one that adds none is its parent over again.
            declare
               Indication : constant Libadalang.Analysis.Subtype_Indication :=
                 Current.As_Subtype_Decl.F_Subtype;
            begin
               if not Libadalang.Analysis.Is_Null (Indication.F_Constraint)
               then
                  return From_Range;
               end if;
               Current := Indication.P_Designated_Type_Decl;
            end;
         elsif Current.Kind /= Libadalang.Common.Ada_Concrete_Type_Decl then
            --  A generic formal type, an incomplete type, a task type.
            return Unknown_Int;
         else
            declare
               Def       : constant Libadalang.Analysis.Type_Def :=
                 Current.As_Type_Decl.F_Type_Def;
               Specified : constant Libadalang.Analysis.Aspect :=
                 Aspect_Named ("size");
            begin
               --  A Size its parent is given is that of a derived type
               --  only when the derived type adds no constraint, and the
               --  parent is then come to below.
               if Libadalang.Analysis.Exists (Specified)
                 and then not Libadalang.Analysis.Inherited (Specified)
               then
                  return Integer_Value
                    (Libadalang.Analysis.Value (Specified));
               elsif Libadalang.Analysis.Exists (Aspect_Named ("value_size"))
               then
                  return Unknown_Int;
               end if;

               case Def.Kind is
                  when Libadalang.Common.Ada_Signed_Int_Type_Def =>
                     return From_Range;

                  when Libadalang.Common.Ada_Mod_Int_Type_Def =>
                     declare
                        Bits : constant Abstract_Int :=
                          Power_Of_Two_Bits (Def.As_Mod_Int_Type_Def.F_Expr);
                     begin
                        if Bits.Known then
                           return Bits;
                        end if;
                        return From_Range;
                     end;

                  when Libadalang.Common.Ada_Enum_Type_Def =>
                     if Current.P_Is_Char_Type
                       or else not Libadalang.Analysis.Is_Null
                         (Current.P_Get_Enum_Representation_Clause)
                     then
                        return Unknown_Int;
                     end if;
                     return Bits_For
                       ((Has_Low  => True, Low => 0,
                         Has_High => True,
                         High     =>
                           Long_Long_Integer
                             (Def.As_Enum_Type_Def.F_Enum_Literals
                                .Children_Count) - 1));

                  when Libadalang.Common.Ada_Derived_Type_Def =>
                     declare
                        Derived    : constant
                          Libadalang.Analysis.Derived_Type_Def :=
                            Def.As_Derived_Type_Def;
                        Indication : constant
                          Libadalang.Analysis.Subtype_Indication :=
                            Derived.F_Subtype_Indication;
                     begin
                        if not Libadalang.Analysis.Is_Null
                                 (Derived.F_Record_Extension)
                          or else not Libadalang.Analysis.Is_Null
                            (Current.P_Get_Enum_Representation_Clause)
                        then
                           return Unknown_Int;
                        elsif not Libadalang.Analysis.Is_Null
                                    (Indication.F_Constraint)
                        then
                           return From_Range;
                        end if;
                        --  It inherits the Size its parent is given, or
                        --  has the size of the same values.
                        Current := Indication.P_Designated_Type_Decl;
                     end;

                  when others =>
                     return Unknown_Int;
               end case;
            end;
         end if;
      end loop;
      return Unknown_Int;
   exception
      when others =>
         return Unknown_Int;
   end Type_Size;

   function Has_Subtype_Predicate
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return Boolean
   is
      Max_Depth : constant := 64;

      function Declares_Predicate
        (Decl : Libadalang.Analysis.Basic_Decl) return Boolean
      is
         function Has_Named_Aspect (Name : String) return Boolean is
           (Libadalang.Analysis.Exists
              (Decl.P_Get_Aspect
                 (Langkit_Support.Text.To_Unbounded_Text
                    (Langkit_Support.Text.To_Text (Name)))));
      begin
         return Has_Named_Aspect ("Predicate")
           or else Has_Named_Aspect ("Static_Predicate")
           or else Has_Named_Aspect ("Dynamic_Predicate");
      end Declares_Predicate;

      Current : Libadalang.Analysis.Base_Type_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Typ) then
         return True;
      end if;
      Current := Typ.As_Base_Type_Decl;

      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return True;
         end if;

         --  A predicate may sit on either view of a private type.
         for Part of Current.P_All_Parts loop
            if Declares_Predicate (Part) then
               return True;
            end if;
         end loop;

         if Current.P_Is_Private then
            Current := Current.P_Full_View;
            if Libadalang.Analysis.Is_Null (Current) then
               return True;
            end if;
         end if;

         if Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            Current :=
              Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
         elsif Current.Kind in Libadalang.Common.Ada_Type_Decl then
            declare
               Definition : constant Libadalang.Analysis.Type_Def :=
                 Current.As_Type_Decl.F_Type_Def;
            begin
               case Definition.Kind is
                  when Libadalang.Common.Ada_Derived_Type_Def =>
                     Current :=
                       Definition.As_Derived_Type_Def.F_Subtype_Indication
                         .P_Designated_Type_Decl;
                  when Libadalang.Common.Ada_Enum_Type_Def
                     | Libadalang.Common.Ada_Signed_Int_Type_Def
                     | Libadalang.Common.Ada_Mod_Int_Type_Def =>
                     --  A root discrete type: nothing left to inherit from.
                     return False;
                  when others =>
                     --  A formal type's actual may carry a predicate.
                     return True;
               end case;
            end;
         else
            return True;
         end if;
      end loop;

      return True;
   exception
      when others =>
         return True;
   end Has_Subtype_Predicate;

   function Discrete_Definition_Range
     (Definition : Libadalang.Analysis.Ada_Node'Class;
      State      : Flow_State) return Abstract_Range
   is
      function Subtype_Mark_Range
        (Name : Libadalang.Analysis.Name) return Abstract_Range
      is
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
      begin
         if not Libadalang.Analysis.Is_Null (Decl)
           and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
         then
            return Type_Range (Decl.As_Base_Type_Decl, State);
         end if;
         return Unknown_Range;
      end Subtype_Mark_Range;
   begin
      if Libadalang.Analysis.Is_Null (Definition) then
         return Unknown_Range;
      end if;

      if Definition.Kind in Libadalang.Common.Ada_Bin_Op_Range
        and then Definition.As_Bin_Op.F_Op =
          Libadalang.Common.Ada_Op_Double_Dot
      then
         declare
            Low  : constant Abstract_Int :=
              Declared_Bound_Value (Definition.As_Bin_Op.F_Left, State);
            High : constant Abstract_Int :=
              Declared_Bound_Value (Definition.As_Bin_Op.F_Right, State);
         begin
            return
              (Has_Low => Low.Known, Low => Low.Value,
               Has_High => High.Known, High => High.Value);
         end;
      elsif Definition.Kind in Libadalang.Common.Ada_Subtype_Indication_Range
      then
         declare
            Indication : constant Libadalang.Analysis.Subtype_Indication :=
              Definition.As_Subtype_Indication;
         begin
            if Libadalang.Analysis.Is_Null (Indication.F_Constraint) then
               return Subtype_Mark_Range (Indication.F_Name);
            elsif Indication.F_Constraint.Kind =
              Libadalang.Common.Ada_Range_Constraint
            then
               return Discrete_Definition_Range
                 (Indication.F_Constraint.As_Range_Constraint.F_Range
                    .F_Range,
                  State);
            end if;
            return Unknown_Range;
         end;
      elsif Definition.Kind = Libadalang.Common.Ada_Attribute_Ref then
         if Text_Utils.Normalize_Rule_Name
              (Ada_Text.Node_Text (Definition.As_Attribute_Ref.F_Attribute)) =
              "range"
           and then
             (Libadalang.Analysis.Is_Null (Definition.As_Attribute_Ref.F_Args)
              or else
                Definition.As_Attribute_Ref.F_Args.Children_Count = 0)
         then
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Definition.As_Attribute_Ref.F_Prefix.P_Referenced_Decl;
            begin
               --  "Arr'Range" of a constrained array subtype, as well as
               --  "Index'Range" of an integer one.
               if not Libadalang.Analysis.Is_Null (Decl)
                 and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
                 and then Decl.As_Base_Type_Decl.P_Is_Array_Type
               then
                  return Array_Index_Range
                    (Decl.As_Base_Type_Decl, 1, State);
               end if;
            end;
            return Subtype_Mark_Range (Definition.As_Attribute_Ref.F_Prefix);
         end if;
         return Unknown_Range;
      elsif Definition.Kind in Libadalang.Common.Ada_Identifier
                             | Libadalang.Common.Ada_Dotted_Name
      then
         return Subtype_Mark_Range (Definition.As_Name);
      end if;
      return Unknown_Range;
   exception
      when others =>
         return Unknown_Range;
   end Discrete_Definition_Range;

   --  The Dimension-th range of an index constraint such as the
   --  "(1 .. 10)" of "String (1 .. 10)"; Unknown_Range for any other
   --  constraint.
   function Index_Constraint_Range
     (Constraint : Libadalang.Analysis.Constraint;
      Dimension  : Positive;
      State      : Flow_State) return Abstract_Range
   is
   begin
      if Libadalang.Analysis.Is_Null (Constraint)
        or else Constraint.Kind /= Libadalang.Common.Ada_Composite_Constraint
        or else not Constraint.As_Composite_Constraint.P_Is_Index_Constraint
        or else Constraint.As_Composite_Constraint.F_Constraints
          .Children_Count < Dimension
      then
         return Unknown_Range;
      end if;

      return Discrete_Definition_Range
        (Constraint.As_Composite_Constraint.F_Constraints.Child (Dimension)
           .As_Composite_Constraint_Assoc.F_Constraint_Expr,
         State);
   exception
      when others =>
         return Unknown_Range;
   end Index_Constraint_Range;

   function Array_Index_Range
     (Array_Type : Libadalang.Analysis.Base_Type_Decl;
      Dimension  : Positive;
      State      : Flow_State) return Abstract_Range
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Array_Type;

      --  Follows a subtype or derived type to what it is declared from:
      --  Result is that declaration's own index constraint when it has
      --  one; otherwise Current moves on to the type it names.
      procedure Step
        (Indication : Libadalang.Analysis.Subtype_Indication;
         Result     : out Abstract_Range;
         Done       : out Boolean) is
      begin
         Result := Unknown_Range;
         if Libadalang.Analysis.Is_Null (Indication.F_Constraint) then
            Current := Indication.P_Designated_Type_Decl;
            Done := False;
         else
            Result :=
              Index_Constraint_Range
                (Indication.F_Constraint, Dimension, State);
            Done := True;
         end if;
      end Step;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return Unknown_Range;
         end if;

         declare
            Result : Abstract_Range;
            Done   : Boolean;
         begin
            if Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
               Step (Current.As_Subtype_Decl.F_Subtype, Result, Done);
            elsif Current.Kind in Libadalang.Common.Ada_Type_Decl then
               declare
                  Definition : constant Libadalang.Analysis.Type_Def :=
                    Current.As_Type_Decl.F_Type_Def;
               begin
                  if Definition.Kind = Libadalang.Common.Ada_Array_Type_Def
                  then
                     declare
                        Indices : constant Libadalang.Analysis.Array_Indices :=
                          Definition.As_Array_Type_Def.F_Indices;
                     begin
                        --  An unconstrained array type has no bounds of
                        --  its own: each object brings its own, and the
                        --  index subtype only limits what those can be
                        --  (FP-088).
                        if Indices.Kind in
                          Libadalang.Common.Ada_Constrained_Array_Indices_Range
                          and then Indices.As_Constrained_Array_Indices
                            .F_List.Children_Count >= Dimension
                        then
                           return Discrete_Definition_Range
                             (Indices.As_Constrained_Array_Indices.F_List
                                .Child (Dimension),
                              State);
                        end if;
                        return Unknown_Range;
                     end;
                  elsif Definition.Kind =
                    Libadalang.Common.Ada_Derived_Type_Def
                  then
                     Step
                       (Definition.As_Derived_Type_Def.F_Subtype_Indication,
                        Result, Done);
                  else
                     return Unknown_Range;
                  end if;
               end;
            else
               return Unknown_Range;
            end if;

            if Done then
               return Result;
            end if;
         end;
      end loop;

      return Unknown_Range;
   exception
      when others =>
         return Unknown_Range;
   end Array_Index_Range;

   function Array_Object_Index_Range
     (Prefix    : Libadalang.Analysis.Ada_Node'Class;
      Dimension : Positive;
      State     : Flow_State) return Abstract_Range
   is
      Type_Expr : Libadalang.Analysis.Type_Expr :=
        Libadalang.Analysis.No_Type_Expr;
      Initial   : Libadalang.Analysis.Expr := Libadalang.Analysis.No_Expr;

      --  The bounds an object of an unconstrained array subtype takes from
      --  Initial, its initial value, and keeps: those of a string literal,
      --  which starts at the index subtype's first value, or those of the
      --  array object Initial names. Unknown_Range for any other value.
      function Initial_Value_Range return Abstract_Range is
         Designated : constant Libadalang.Analysis.Base_Type_Decl :=
           Type_Expr.P_Designated_Type_Decl;
         Value      : Libadalang.Analysis.Expr := Initial;
      begin
         if Libadalang.Analysis.Is_Null (Designated)
           or else not Designated.P_Is_Array_Type
           or else Designated.P_Is_Definite_Subtype (Prefix)
         then
            return Unknown_Range;
         end if;

         while Value.Kind = Libadalang.Common.Ada_Paren_Expr loop
            Value := Value.As_Paren_Expr.F_Expr;
         end loop;

         if Value.Kind = Libadalang.Common.Ada_String_Literal then
            declare
               Index : constant Abstract_Range :=
                 (if Dimension = 1
                    and then Designated.P_Index_Type (0).P_Is_Int_Type
                  then Type_Range (Designated.P_Index_Type (0), State)
                  else Unknown_Range);
               Count : constant Long_Long_Integer :=
                 Long_Long_Integer
                   (Value.As_String_Literal.P_Denoted_Value'Length);
            begin
               if not Index.Has_Low then
                  return Unknown_Range;
               end if;
               return
                 (Has_Low => True, Low => Index.Low,
                  Has_High => True, High => Index.Low + Count - 1);
            end;
         elsif Value.Kind = Libadalang.Common.Ada_Identifier
           and then not Libadalang.Analysis."="
             (Libadalang.Analysis.Ada_Node (Value),
              Libadalang.Analysis.Ada_Node (Prefix))
         then
            return Array_Object_Index_Range (Value, Dimension, State);
         end if;
         return Unknown_Range;
      exception
         when others =>
            return Unknown_Range;
      end Initial_Value_Range;
   begin
      if Libadalang.Analysis.Is_Null (Prefix)
        or else Prefix.Kind not in Libadalang.Common.Ada_Expr
      then
         return Unknown_Range;
      end if;

      --  An object or component declared with its own index constraint
      --  ("Buffer : String (1 .. 80)") has the unconstrained type as its
      --  expression type, so the constraint is read off the declaration.
      if Prefix.Kind in Libadalang.Common.Ada_Identifier
                      | Libadalang.Common.Ada_Dotted_Name
      then
         declare
            Decl : constant Libadalang.Analysis.Basic_Decl :=
              Prefix.As_Name.P_Referenced_Decl;
         begin
            if not Libadalang.Analysis.Is_Null (Decl) then
               if Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range then
                  Type_Expr := Decl.As_Object_Decl.F_Type_Expr;
                  if Libadalang.Analysis.Is_Null
                       (Decl.As_Object_Decl.F_Renaming_Clause)
                  then
                     Initial := Decl.As_Object_Decl.F_Default_Expr;
                  end if;
               elsif Decl.Kind = Libadalang.Common.Ada_Component_Decl then
                  Type_Expr :=
                    Decl.As_Component_Decl.F_Component_Def.F_Type_Expr;
               end if;
            end if;
         end;

         if not Libadalang.Analysis.Is_Null (Type_Expr)
           and then Type_Expr.Kind in
             Libadalang.Common.Ada_Subtype_Indication_Range
           and then not Libadalang.Analysis.Is_Null
             (Type_Expr.As_Subtype_Indication.F_Constraint)
         then
            return Index_Constraint_Range
              (Type_Expr.As_Subtype_Indication.F_Constraint, Dimension,
               State);
         elsif not Libadalang.Analysis.Is_Null (Type_Expr)
           and then not Libadalang.Analysis.Is_Null (Initial)
         then
            declare
               Result : constant Abstract_Range := Initial_Value_Range;
            begin
               if Result.Has_Low or else Result.Has_High then
                  return Result;
               end if;
            end;
         end if;
      end if;

      declare
         Array_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Prefix.As_Expr.P_Expression_Type;
      begin
         if Libadalang.Analysis.Is_Null (Array_Type)
           or else not Array_Type.P_Is_Array_Type
         then
            return Unknown_Range;
         end if;
         return Array_Index_Range (Array_Type, Dimension, State);
      end;
   exception
      when others =>
         return Unknown_Range;
   end Array_Object_Index_Range;

   No_Constraint      : constant Subtype_Constraint :=
     (Present => False, Bounds => Unknown_Range);
   Unknown_Constraint : constant Subtype_Constraint :=
     (Present => True, Bounds => Unknown_Range);

   function Declared_Constraint
     (Indication : Libadalang.Analysis.Ada_Node'Class;
      State      : Flow_State) return Subtype_Constraint
   is
   begin
      if Libadalang.Analysis.Is_Null (Indication) then
         return Unknown_Constraint;
      elsif Indication.Kind not in
        Libadalang.Common.Ada_Subtype_Indication_Range
      then
         --  An anonymous array or access type: no scalar is stored in an
         --  object of it as a whole.
         return No_Constraint;
      end if;

      declare
         Constraint : constant Libadalang.Analysis.Constraint :=
           Indication.As_Subtype_Indication.F_Constraint;
         Designated : constant Libadalang.Analysis.Base_Type_Decl :=
           Indication.As_Subtype_Indication.P_Designated_Type_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Constraint)
           or else Constraint.Kind =
             Libadalang.Common.Ada_Composite_Constraint
         then
            --  An index or discriminant constraint is not about a scalar.
            return No_Constraint;
         elsif Constraint.Kind = Libadalang.Common.Ada_Range_Constraint
           and then not Libadalang.Analysis.Is_Null (Designated)
           and then Designated.P_Is_Int_Type
         then
            return
              (Present => True,
               Bounds  => Discrete_Definition_Range (Indication, State));
         end if;

         --  A digits or delta constraint, or a range of a type whose
         --  values this evaluator does not order.
         return Unknown_Constraint;
      end;
   exception
      when others =>
         return Unknown_Constraint;
   end Declared_Constraint;

   --  The definition Typ takes its structure from: its own, or that of the
   --  type it is a subtype of or derived from, behind any private view.
   --  No_Type_Def when that can't be found.
   function Structural_Definition
     (Typ : Libadalang.Analysis.Base_Type_Decl)
      return Libadalang.Analysis.Type_Def
   is
      Max_Depth : constant := 64;
      Current   : Libadalang.Analysis.Base_Type_Decl := Typ;
   begin
      for Depth in 1 .. Max_Depth loop
         if Libadalang.Analysis.Is_Null (Current) then
            return Libadalang.Analysis.No_Type_Def;
         elsif Current.Kind = Libadalang.Common.Ada_Subtype_Decl then
            Current :=
              Current.As_Subtype_Decl.F_Subtype.P_Designated_Type_Decl;
         elsif Current.Kind not in Libadalang.Common.Ada_Type_Decl then
            return Libadalang.Analysis.No_Type_Def;
         else
            declare
               Definition : constant Libadalang.Analysis.Type_Def :=
                 Current.As_Type_Decl.F_Type_Def;
            begin
               if Libadalang.Analysis.Is_Null (Definition) then
                  return Libadalang.Analysis.No_Type_Def;
               elsif Definition.Kind =
                 Libadalang.Common.Ada_Derived_Type_Def
               then
                  Current :=
                    Definition.As_Derived_Type_Def.F_Subtype_Indication
                      .P_Designated_Type_Decl;
               elsif Definition.Kind =
                 Libadalang.Common.Ada_Private_Type_Def
               then
                  declare
                     Full : constant Libadalang.Analysis.Base_Type_Decl :=
                       Current.P_Full_View;
                  begin
                     if Libadalang.Analysis.Is_Null (Full)
                       or else Libadalang.Analysis."=" (Full, Current)
                     then
                        return Libadalang.Analysis.No_Type_Def;
                     end if;
                     Current := Full;
                  end;
               else
                  return Definition;
               end if;
            end;
         end if;
      end loop;
      return Libadalang.Analysis.No_Type_Def;
   end Structural_Definition;

   --  The constraint an array type puts on each of its components, where
   --  Prefix_Type is the type of the prefix of an indexed component: the
   --  array type, or an access type to it.
   function Component_Constraint
     (Prefix_Type : Libadalang.Analysis.Base_Type_Decl;
      State       : Flow_State) return Subtype_Constraint
   is
      Definition : Libadalang.Analysis.Type_Def :=
        Structural_Definition (Prefix_Type);
   begin
      if not Libadalang.Analysis.Is_Null (Definition)
        and then Definition.Kind = Libadalang.Common.Ada_Type_Access_Def
      then
         Definition :=
           Structural_Definition
             (Definition.As_Type_Access_Def.F_Subtype_Indication
                .P_Designated_Type_Decl);
      end if;

      if Libadalang.Analysis.Is_Null (Definition)
        or else Definition.Kind /= Libadalang.Common.Ada_Array_Type_Def
      then
         return Unknown_Constraint;
      end if;
      return Declared_Constraint
        (Definition.As_Array_Type_Def.F_Component_Type.F_Type_Expr, State);
   end Component_Constraint;

   --  The constraint an access type puts on what its values designate.
   function Designated_Constraint
     (Access_Type : Libadalang.Analysis.Base_Type_Decl;
      State       : Flow_State) return Subtype_Constraint
   is
      Definition : constant Libadalang.Analysis.Type_Def :=
        Structural_Definition (Access_Type);
   begin
      if Libadalang.Analysis.Is_Null (Definition)
        or else Definition.Kind /= Libadalang.Common.Ada_Type_Access_Def
      then
         return Unknown_Constraint;
      end if;
      return Declared_Constraint
        (Definition.As_Type_Access_Def.F_Subtype_Indication, State);
   end Designated_Constraint;

   function Stored_Subtype
     (Dest  : Libadalang.Analysis.Expr'Class;
      State : Flow_State) return Target_Subtype
   is
      Max_Depth : constant := 16;
      Result    : Target_Subtype :=
        (Typ => Dest.P_Expression_Type, Constraint => Unknown_Constraint);
      Current   : Libadalang.Analysis.Expr := Dest.As_Expr;
   begin
      --  Only a scalar is stored under a range: an array or a record is
      --  checked against its type as before.
      if Libadalang.Analysis.Is_Null (Result.Typ)
        or else not Result.Typ.P_Is_Scalar_Type
      then
         Result.Constraint := No_Constraint;
         return Result;
      end if;

      --  Only a renaming goes round again, with the name it renames: what
      --  is stored through "R : Integer renames X" must belong to the
      --  subtype of X, whatever the renaming calls it.
      for Depth in 1 .. Max_Depth loop
         case Current.Kind is
            when Libadalang.Common.Ada_Identifier
               | Libadalang.Common.Ada_Dotted_Name =>
               declare
                  Decl : constant Libadalang.Analysis.Basic_Decl :=
                    Current.As_Name.P_Referenced_Decl;
               begin
                  if Libadalang.Analysis.Is_Null (Decl) then
                     return Result;
                  end if;

                  case Decl.Kind is
                     when Libadalang.Common.Ada_Object_Decl
                        | Libadalang.Common
                            .Ada_Extended_Return_Stmt_Object_Decl =>
                        if Decl.Parent.Kind =
                          Libadalang.Common.Ada_Generic_Formal_Obj_Decl
                        then
                           --  The subtype is that of the actual.
                           return Result;
                        elsif Libadalang.Analysis.Is_Null
                          (Decl.As_Object_Decl.F_Renaming_Clause)
                        then
                           Result.Constraint :=
                             Declared_Constraint
                               (Decl.As_Object_Decl.F_Type_Expr, State);
                           return Result;
                        end if;

                        Current :=
                          Decl.As_Object_Decl.F_Renaming_Clause
                            .F_Renamed_Object.As_Expr;
                        Result :=
                          (Typ        => Current.P_Expression_Type,
                           Constraint => Unknown_Constraint);

                     when Libadalang.Common.Ada_Param_Spec =>
                        --  A formal parameter is declared with a subtype
                        --  mark alone.
                        Result.Constraint := No_Constraint;
                        return Result;

                     when Libadalang.Common.Ada_Component_Decl =>
                        Result.Constraint :=
                          Declared_Constraint
                            (Decl.As_Component_Decl.F_Component_Def
                               .F_Type_Expr,
                             State);
                        return Result;

                     when others =>
                        return Result;
                  end case;
               end;

            when Libadalang.Common.Ada_Call_Expr =>
               if Current.As_Call_Expr.P_Kind in
                 Libadalang.Common.Array_Index
               then
                  Result.Constraint :=
                    Component_Constraint
                      (Current.As_Call_Expr.F_Name.P_Expression_Type, State);
               end if;
               return Result;

            when Libadalang.Common.Ada_Explicit_Deref =>
               Result.Constraint :=
                 Designated_Constraint
                   (Current.As_Explicit_Deref.F_Prefix.P_Expression_Type,
                    State);
               return Result;

            when others =>
               return Result;
         end case;
      end loop;

      Result.Constraint := Unknown_Constraint;
      return Result;
   exception
      when others =>
         Result.Constraint := Unknown_Constraint;
         return Result;
   end Stored_Subtype;

end Adalang_Analyzer.Flow_Eval;
