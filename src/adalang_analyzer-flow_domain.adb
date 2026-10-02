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

with Ada.Characters.Handling;

with Langkit_Support.Text;
with Libadalang.Common;

package body Adalang_Analyzer.Flow_Domain is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   function Lower_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
     (Ada.Characters.Handling.To_Lower
        (Langkit_Support.Text.To_UTF8 (Node.Text)));

   function Classify
     (Key : Libadalang.Analysis.Ada_Node) return Object_Class
   is
      --  What one aspect, pragma or representation attribute says about the
      --  object it is applied to.
      function Class_Of_Mark (Name : String) return Object_Class is
        (if Name in "address" | "import" | "interface"
           then Aliasing
         elsif Name in "volatile" | "atomic" | "volatile_full_access"
                     | "async_writers" | "export" | "shared"
           then Untracked
         else Tracked);

      Result : Object_Class := Tracked;

      procedure Note (Class : Object_Class) is
      begin
         Result := Object_Class'Max (Result, Class);
      end Note;

      procedure Note_Aspects
        (Aspects : Libadalang.Analysis.Aspect_Spec) is
      begin
         if Libadalang.Analysis.Is_Null (Aspects) then
            return;
         end if;
         for Item of Aspects.F_Aspect_Assocs loop
            Note
              (Class_Of_Mark
                 (Lower_Text (Item.As_Aspect_Assoc.F_Id)));
         end loop;
      end Note_Aspects;

      --  The aspects of the object's type; none when the type does not
      --  resolve, which leaves the object classified by its own marks.
      function Type_Aspects
        (Object : Libadalang.Analysis.Object_Decl)
         return Libadalang.Analysis.Aspect_Spec
      is
         Typ : constant Libadalang.Analysis.Base_Type_Decl :=
           Object.F_Type_Expr.P_Designated_Type_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Typ) then
            return Libadalang.Analysis.No_Aspect_Spec;
         end if;
         return Typ.F_Aspects;
      exception
         when others =>
            return Libadalang.Analysis.No_Aspect_Spec;
      end Type_Aspects;

      Decl : Libadalang.Analysis.Basic_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Key)
        or else Key.Kind /= Libadalang.Common.Ada_Defining_Name
      then
         return Tracked;
      end if;

      Decl := Key.As_Defining_Name.P_Basic_Decl;
      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind not in Libadalang.Common.Ada_Object_Decl_Range
      then
         return Tracked;
      end if;

      if not Libadalang.Analysis.Is_Null
           (Decl.As_Object_Decl.F_Renaming_Clause)
      then
         return Aliasing;
      end if;
      if Decl.As_Object_Decl.F_Has_Aliased then
         Note (Untracked);
      end if;
      Note_Aspects (Decl.As_Object_Decl.F_Aspects);

      --  The pragma and representation-clause spellings of the same marks
      --  sit beside the declaration, naming the object.
      declare
         Name     : constant String := Lower_Text (Key);
         Siblings : constant Libadalang.Analysis.Ada_Node := Decl.Parent;
      begin
         if not Libadalang.Analysis.Is_Null (Siblings) then
            for Index in 1 .. Siblings.Children_Count loop
               declare
                  Item : constant Libadalang.Analysis.Ada_Node :=
                    Siblings.Child (Index);
               begin
                  if Libadalang.Analysis.Is_Null (Item) then
                     goto Next_Sibling;
                  end if;

                  if Item.Kind = Libadalang.Common.Ada_Pragma_Node
                    and then Item.As_Pragma_Node.F_Args.Children_Count > 0
                    and then Class_Of_Mark
                      (Lower_Text (Item.As_Pragma_Node.F_Id)) /= Tracked
                  then
                     --  The object is the first argument, or the second of
                     --  "pragma Import (Convention, Entity, ...)".
                     for Arg in 1 .. Natural'Min
                       (2, Item.As_Pragma_Node.F_Args.Children_Count)
                     loop
                        declare
                           Text : constant String :=
                             Lower_Text
                               (Item.As_Pragma_Node.F_Args.Child (Arg));
                        begin
                           if Text = Name
                             or else
                               (Text'Length > Name'Length + 2
                                and then Text
                                  (Text'Last - Name'Length + 1 .. Text'Last) =
                                  Name
                                and then Text (Text'Last - Name'Length) in
                                  ' ' | '>')
                           then
                              Note
                                (Class_Of_Mark
                                   (Lower_Text (Item.As_Pragma_Node.F_Id)));
                           end if;
                        end;
                     end loop;
                  elsif Item.Kind =
                    Libadalang.Common.Ada_Attribute_Def_Clause
                    and then Item.As_Attribute_Def_Clause.F_Attribute_Expr
                      .Kind = Libadalang.Common.Ada_Attribute_Ref
                  then
                     declare
                        Attr : constant Libadalang.Analysis.Attribute_Ref :=
                          Item.As_Attribute_Def_Clause.F_Attribute_Expr
                            .As_Attribute_Ref;
                     begin
                        if Lower_Text (Attr.F_Prefix) = Name then
                           Note (Class_Of_Mark (Lower_Text (Attr.F_Attribute)));
                        end if;
                     end;
                  elsif Item.Kind = Libadalang.Common.Ada_At_Clause
                    and then Lower_Text (Item.As_At_Clause.F_Name) = Name
                  then
                     Note (Aliasing);
                  end if;

                  <<Next_Sibling>>
               end;
            end loop;
         end if;
      end;

      --  A volatile or atomic type makes every object of it so.
      if Result = Tracked then
         Note_Aspects (Type_Aspects (Decl.As_Object_Decl));
      end if;

      return Result;
   exception
      when others =>
         --  An object whose declaration cannot be examined is not assumed
         --  to be an ordinary one.
         return Aliasing;
   end Classify;

   function Binding_Count (State : Flow_State) return Natural is
     (Natural (State.Bindings.Length));

   function Binding_At
     (State : Flow_State;
      Index : Positive) return Flow_Binding
   is
   begin
      if Index > Binding_Count (State) then
         raise Constraint_Error with "invalid flow binding index";
      end if;
      return State.Bindings.Element (Index);
   end Binding_At;

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
      function Is_Empty (Value : Abstract_Range) return Boolean is
        (Value.Has_Low and then Value.Has_High
         and then Value.Low > Value.High);

      Result : Abstract_Range;
   begin
      if Is_Empty (Left) then
         return Right;
      elsif Is_Empty (Right) then
         return Left;
      end if;

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

      for I in 1 .. Binding_Count (State) loop
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

      for I in 1 .. Binding_Count (State) loop
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

      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = Key then
            return State.Bindings (I).Range_Value;
         end if;
      end loop;

      return Unknown_Range;
   end Flow_Range_Lookup;

   function Flow_Initialization
     (State : Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) return Abstract_Bool
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return Bool_Unknown;
      end if;

      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = Key then
            return State.Bindings (I).Initialized;
         end if;
      end loop;
      return Bool_Unknown;
   end Flow_Initialization;

   procedure Flow_Set_Initialized
     (State       : in out Flow_State;
      Key         : Libadalang.Analysis.Ada_Node;
      Initialized : Abstract_Bool)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = Key then
            declare
               Item : Flow_Binding := State.Bindings (I);
            begin
               Item.Initialized := Initialized;
               State.Bindings.Replace_Element (I, Item);
            end;
            return;
         end if;
      end loop;

      State.Bindings.Append
        ((Decl        => Key,
          Value       => Unknown_Int,
          Bool_Value  => Bool_Unknown,
          Range_Value => Unknown_Range,
          Initialized => Initialized));
   end Flow_Set_Initialized;

   procedure Flow_Set_Stored
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node;
      Value : Abstract_Int)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = Key then
            declare
               Item : Flow_Binding := State.Bindings (I);
            begin
               Item.Value := Value;
               Item.Initialized := Bool_True;
               if Value.Known then
                  Item.Range_Value := Range_From_Int (Value);
               end if;
               State.Bindings.Replace_Element (I, Item);
            end;
            return;
         end if;
      end loop;

      State.Bindings.Append
        ((Decl => Key, Value => Value, Bool_Value => Bool_Unknown,
          Range_Value => Range_From_Int (Value), Initialized => Bool_True));
   end Flow_Set_Stored;

   procedure Flow_Copy_Key
     (State    : in out Flow_State;
      From, To : Libadalang.Analysis.Ada_Node)
   is
      Source : Flow_Binding := (others => <>);
      Found  : Boolean := False;
   begin
      if Libadalang.Analysis.Is_Null (From)
        or else Libadalang.Analysis.Is_Null (To)
      then
         return;
      end if;

      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = From then
            Source := State.Bindings (I);
            Found := True;
         end if;
      end loop;

      for I in reverse 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = To then
            State.Bindings.Delete (I);
         end if;
      end loop;

      if Found then
         Source.Decl := To;
         State.Bindings.Append (Source);
      end if;
   end Flow_Copy_Key;

   procedure Flow_Bool_Set_Stored
     (State      : in out Flow_State;
      Key        : Libadalang.Analysis.Ada_Node;
      Bool_Value : Abstract_Bool)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = Key then
            declare
               Item : Flow_Binding := State.Bindings (I);
            begin
               Item.Bool_Value := Bool_Value;
               if Bool_Value /= Bool_Unknown then
                  Item.Initialized := Bool_True;
               end if;
               State.Bindings.Replace_Element (I, Item);
            end;
            return;
         end if;
      end loop;

      State.Bindings.Append
        ((Decl => Key, Value => Unknown_Int, Bool_Value => Bool_Value,
          Range_Value => Unknown_Range,
          Initialized =>
            (if Bool_Value = Bool_Unknown then Bool_Unknown else Bool_True)));
   end Flow_Bool_Set_Stored;

   procedure Flow_Range_Set_Stored
     (State       : in out Flow_State;
      Key         : Libadalang.Analysis.Ada_Node;
      Range_Value : Abstract_Range)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = Key then
            declare
               Item : Flow_Binding := State.Bindings (I);
            begin
               Item.Range_Value := Range_Value;
               State.Bindings.Replace_Element (I, Item);
            end;
            return;
         end if;
      end loop;

      State.Bindings.Append
        ((Decl => Key, Value => Unknown_Int, Bool_Value => Bool_Unknown,
          Range_Value => Range_Value, Initialized => Bool_Unknown));
   end Flow_Range_Set_Stored;

   procedure Flow_Havoc_Stored
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node)
   is
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         return;
      end if;

      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = Key then
            State.Bindings.Replace_Element
              (I,
               (Decl        => Key,
                Value       => Unknown_Int,
                Bool_Value  => Bool_Unknown,
                Range_Value => Unknown_Range,
                Initialized => Bool_Unknown));
            return;
         end if;
      end loop;
   end Flow_Havoc_Stored;

   procedure Flow_Havoc_All (State : in out Flow_State) is
   begin
      State.Bindings.Clear;
   end Flow_Havoc_All;

   function Flow_Join (Left, Right : Flow_State) return Flow_State is
      Result : Flow_State := Empty_Flow_State;
   begin
      for I in 1 .. Binding_Count (Left) loop
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
            Left_Init   : constant Abstract_Bool :=
              Left.Bindings (I).Initialized;
            Right_Init  : constant Abstract_Bool :=
              Flow_Initialization (Right, Decl);
         begin
            if Left_Value.Known and then Right_Value.Known
              and then Left_Value.Value = Right_Value.Value
            then
               Flow_Set_Stored (Result, Decl, Left_Value);
            end if;

            if Left_Bool /= Bool_Unknown and then Left_Bool = Right_Bool then
               Flow_Bool_Set_Stored (Result, Decl, Left_Bool);
            end if;

            if Left_Range.Has_Low or else Left_Range.Has_High then
               Flow_Range_Set_Stored
                 (Result, Decl, Range_Union (Left_Range, Right_Range));
            end if;

            if Left_Init = Right_Init then
               Flow_Set_Initialized (Result, Decl, Left_Init);
            else
               Flow_Set_Initialized (Result, Decl, Bool_Unknown);
            end if;
         end;
      end loop;

      return Result;
   end Flow_Join;

   function Flow_Equal (Left, Right : Flow_State) return Boolean is
   begin
      if Binding_Count (Left) /= Binding_Count (Right) then
         return False;
      end if;

      for Item of Left.Bindings loop
         declare
            Other_Value : constant Abstract_Int :=
              Flow_Lookup (Right, Item.Decl);
            Other_Bool  : constant Abstract_Bool :=
              Flow_Bool_Lookup (Right, Item.Decl);
            Other_Range : constant Abstract_Range :=
              Flow_Range_Lookup (Right, Item.Decl);
         begin
            if Item.Value /= Other_Value
              or else Item.Bool_Value /= Other_Bool
              or else Item.Range_Value /= Other_Range
              or else Item.Initialized /=
                Flow_Initialization (Right, Item.Decl)
            then
               return False;
            end if;
         end;
      end loop;
      return True;
   end Flow_Equal;

   function Flow_Widen
     (Previous, Next : Flow_State) return Flow_State
   is
      Result : Flow_State := Empty_Flow_State;
   begin
      for Item of Previous.Bindings loop
         declare
            Next_Value : constant Abstract_Int :=
              Flow_Lookup (Next, Item.Decl);
            Next_Bool  : constant Abstract_Bool :=
              Flow_Bool_Lookup (Next, Item.Decl);
            Next_Range : constant Abstract_Range :=
              Flow_Range_Lookup (Next, Item.Decl);
            Next_Init  : constant Abstract_Bool :=
              Flow_Initialization (Next, Item.Decl);
            Wide       : Abstract_Range;
         begin
            if Item.Value.Known
              and then Next_Value.Known
              and then Item.Value.Value = Next_Value.Value
            then
               Flow_Set_Stored (Result, Item.Decl, Item.Value);
            end if;

            if Item.Bool_Value /= Bool_Unknown
              and then Item.Bool_Value = Next_Bool
            then
               Flow_Bool_Set_Stored (Result, Item.Decl, Item.Bool_Value);
            end if;

            Wide.Has_Low :=
              Item.Range_Value.Has_Low
              and then Next_Range.Has_Low
              and then Next_Range.Low >= Item.Range_Value.Low;
            if Wide.Has_Low then
               Wide.Low := Item.Range_Value.Low;
            end if;

            Wide.Has_High :=
              Item.Range_Value.Has_High
              and then Next_Range.Has_High
              and then Next_Range.High <= Item.Range_Value.High;
            if Wide.Has_High then
               Wide.High := Item.Range_Value.High;
            end if;

            if Wide.Has_Low or else Wide.Has_High then
               Flow_Range_Set_Stored (Result, Item.Decl, Wide);
            end if;

            if Item.Initialized = Next_Init then
               Flow_Set_Initialized
                 (Result, Item.Decl, Item.Initialized);
            else
               Flow_Set_Initialized (Result, Item.Decl, Bool_Unknown);
            end if;
         end;
      end loop;
      return Result;
   end Flow_Widen;

   procedure Flow_Forget_All_Values (State : in out Flow_State) is
   begin
      for I in 1 .. Binding_Count (State) loop
         declare
            Item : Flow_Binding := State.Bindings (I);
         begin
            Item.Value := Unknown_Int;
            Item.Bool_Value := Bool_Unknown;
            Item.Range_Value := Unknown_Range;
            State.Bindings.Replace_Element (I, Item);
         end;
      end loop;
   end Flow_Forget_All_Values;

   procedure Flow_Forget_Value
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) is
   begin
      for I in 1 .. Binding_Count (State) loop
         if State.Bindings (I).Decl = Key then
            declare
               Item : Flow_Binding := State.Bindings (I);
            begin
               Item.Value := Unknown_Int;
               Item.Bool_Value := Bool_Unknown;
               Item.Range_Value := Unknown_Range;
               State.Bindings.Replace_Element (I, Item);
            end;
            return;
         end if;
      end loop;
   end Flow_Forget_Value;

   --  Applies a write to Key that the state must not turn into a fact
   --  about Key. True when Key is such an object, in which case the caller
   --  stores nothing.
   function Write_Without_Fact
     (State       : in out Flow_State;
      Key         : Libadalang.Analysis.Ada_Node;
      Initializes : Boolean) return Boolean is
   begin
      case Classify (Key) is
         when Tracked =>
            return False;
         when Untracked =>
            Flow_Havoc_Stored (State, Key);
         when Aliasing =>
            Flow_Forget_All_Values (State);
      end case;
      if Initializes then
         Flow_Set_Initialized (State, Key, Bool_True);
      end if;
      return True;
   end Write_Without_Fact;

   procedure Flow_Set
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node;
      Value : Abstract_Int) is
   begin
      if not Write_Without_Fact (State, Key, Initializes => True) then
         Flow_Set_Stored (State, Key, Value);
      end if;
   end Flow_Set;

   procedure Flow_Bool_Set
     (State      : in out Flow_State;
      Key        : Libadalang.Analysis.Ada_Node;
      Bool_Value : Abstract_Bool) is
   begin
      if not Write_Without_Fact
               (State, Key, Initializes => Bool_Value /= Bool_Unknown)
      then
         Flow_Bool_Set_Stored (State, Key, Bool_Value);
      end if;
   end Flow_Bool_Set;

   procedure Flow_Range_Set
     (State       : in out Flow_State;
      Key         : Libadalang.Analysis.Ada_Node;
      Range_Value : Abstract_Range) is
   begin
      --  Narrowing and seeding, never a write: an object that holds no
      --  facts simply gains none.
      if Classify (Key) = Tracked then
         Flow_Range_Set_Stored (State, Key, Range_Value);
      end if;
   end Flow_Range_Set;

   procedure Flow_Havoc
     (State : in out Flow_State;
      Key   : Libadalang.Analysis.Ada_Node) is
   begin
      if Classify (Key) = Aliasing then
         Flow_Forget_All_Values (State);
      end if;
      Flow_Havoc_Stored (State, Key);
   end Flow_Havoc;

end Adalang_Analyzer.Flow_Domain;
