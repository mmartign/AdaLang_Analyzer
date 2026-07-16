--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

package body Adalang_Analyzer.Flow_Domain is

   use type Libadalang.Analysis.Ada_Node;

   function Bool_Name (Value : Abstract_Bool) return String is
   begin
      case Value is
         when Bool_False =>
            return "false";
         when Bool_True =>
            return "true";
         when Bool_Unknown =>
            return "unknown";
      end case;
   end Bool_Name;

   function Not_Bool (Value : Abstract_Bool) return Abstract_Bool is
   begin
      case Value is
         when Bool_False =>
            return Bool_True;
         when Bool_True =>
            return Bool_False;
         when Bool_Unknown =>
            return Bool_Unknown;
      end case;
   end Not_Bool;

   function And_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_False or else Right = Bool_False then
         return Bool_False;
      elsif Left = Bool_True and then Right = Bool_True then
         return Bool_True;
      else
         return Bool_Unknown;
      end if;
   end And_Bool;

   function Or_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_True or else Right = Bool_True then
         return Bool_True;
      elsif Left = Bool_False and then Right = Bool_False then
         return Bool_False;
      else
         return Bool_Unknown;
      end if;
   end Or_Bool;

   function Eq_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_Unknown or else Right = Bool_Unknown then
         return Bool_Unknown;
      elsif Left = Right then
         return Bool_True;
      else
         return Bool_False;
      end if;
   end Eq_Bool;

   function Bool_From (Value : Boolean) return Abstract_Bool is
   begin
      if Value then
         return Bool_True;
      else
         return Bool_False;
      end if;
   end Bool_From;

   function Known_Int (Value : Long_Long_Integer) return Abstract_Int is
   begin
      return (Known => True, Value => Value);
   end Known_Int;

   function Range_From_Int (Value : Abstract_Int) return Abstract_Range is
   begin
      if Value.Known then
         return
           (Has_Low => True, Low => Value.Value,
            Has_High => True, High => Value.Value);
      else
         return Unknown_Range;
      end if;
   end Range_From_Int;

   function Range_Union (Left, Right : Abstract_Range) return Abstract_Range is
      Result : Abstract_Range;
   begin
      if Left.Has_Low and then Right.Has_Low then
         Result.Has_Low := True;
         Result.Low := Long_Long_Integer'Min (Left.Low, Right.Low);
      end if;

      if Left.Has_High and then Right.Has_High then
         Result.Has_High := True;
         Result.High := Long_Long_Integer'Max (Left.High, Right.High);
      end if;

      return Result;
   end Range_Union;

   function Flow_Lookup
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Int
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return Unknown_Int;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            return State.Bindings (I).Value;
         end if;
      end loop;

      return Unknown_Int;
   end Flow_Lookup;

   function Flow_Bool_Lookup
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Bool
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return Bool_Unknown;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            return State.Bindings (I).Bool_Value;
         end if;
      end loop;

      return Bool_Unknown;
   end Flow_Bool_Lookup;

   function Flow_Range_Lookup
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Range
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return Unknown_Range;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            return State.Bindings (I).Range_Value;
         end if;
      end loop;

      return Unknown_Range;
   end Flow_Range_Lookup;

   procedure Flow_Set
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node;
      Value : Abstract_Int)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            State.Bindings (I).Value := Value;
            if Value.Known then
               State.Bindings (I).Range_Value := Range_From_Int (Value);
            end if;
            return;
         end if;
      end loop;

      if State.Count < Max_Flow_Vars then
         State.Count := State.Count + 1;
         State.Bindings (State.Count) :=
           (Decl => Key, Value => Value, Bool_Value => Bool_Unknown,
            Range_Value => Range_From_Int (Value));
      end if;
   end Flow_Set;

   procedure Flow_Bool_Set
     (State      : in out Flow_State;
      Key        : Libadalang.Analysis.Ada_Node;
      Bool_Value : Abstract_Bool)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            State.Bindings (I).Bool_Value := Bool_Value;
            return;
         end if;
      end loop;

      if State.Count < Max_Flow_Vars then
         State.Count := State.Count + 1;
         State.Bindings (State.Count) :=
           (Decl => Key, Value => Unknown_Int, Bool_Value => Bool_Value,
            Range_Value => Unknown_Range);
      end if;
   end Flow_Bool_Set;

   procedure Flow_Range_Set
     (State       : in out Flow_State;
      Key         : Libadalang.Analysis.Ada_Node;
      Range_Value : Abstract_Range)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            State.Bindings (I).Range_Value := Range_Value;
            return;
         end if;
      end loop;

      if State.Count < Max_Flow_Vars then
         State.Count := State.Count + 1;
         State.Bindings (State.Count) :=
           (Decl => Key, Value => Unknown_Int, Bool_Value => Bool_Unknown,
            Range_Value => Range_Value);
      end if;
   end Flow_Range_Set;

   procedure Flow_Havoc
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. State.Count loop
         if State.Bindings (I).Decl = Key then
            State.Bindings (I).Value := Unknown_Int;
            State.Bindings (I).Bool_Value := Bool_Unknown;
            State.Bindings (I).Range_Value := Unknown_Range;
            return;
         end if;
      end loop;
   end Flow_Havoc;

   function Flow_Join (Left, Right : Flow_State) return Flow_State is
      Result : Flow_State := Empty_Flow_State;
   begin
      for I in 1 .. Left.Count loop
         declare
            Decl        : constant Libadalang.Analysis.Ada_Node :=
              Left.Bindings (I).Decl;
            Left_Value  : constant Abstract_Int := Left.Bindings (I).Value;
            Right_Value : constant Abstract_Int :=
              Flow_Lookup (Right, Decl);
            Left_Bool   : constant Abstract_Bool :=
              Left.Bindings (I).Bool_Value;
            Right_Bool  : constant Abstract_Bool :=
              Flow_Bool_Lookup (Right, Decl);
            Left_Range  : constant Abstract_Range :=
              Left.Bindings (I).Range_Value;
            Right_Range : constant Abstract_Range :=
              Flow_Range_Lookup (Right, Decl);
         begin
            if Left_Value.Known and then Right_Value.Known
              and then Left_Value.Value = Right_Value.Value
            then
               Flow_Set (Result, Decl, Left_Value);
            end if;

            if Left_Bool /= Bool_Unknown and then Left_Bool = Right_Bool then
               Flow_Bool_Set (Result, Decl, Left_Bool);
            end if;

            if Left_Range.Has_Low or else Left_Range.Has_High then
               Flow_Range_Set
                 (Result, Decl, Range_Union (Left_Range, Right_Range));
            end if;
         end;
      end loop;

      return Result;
   end Flow_Join;

end Adalang_Analyzer.Flow_Domain;
