--  The defects of verification_outside_objects, one name each: none of
--  these initializations may be proved, and GNATprove rejects them.
package Verification_Mutation_Outside_Objects
  with SPARK_Mode
is
   Before_Call, One_Path, Bare, Expanded, Operator, In_Contract, In_Out_Early,
   In_Declaration, In_Assertion : Integer;

   type Cells is array (1 .. 4) of Integer;
   subtype Few is Integer range 1 .. 2;
   type Pair is record
      P, Q : Integer;
   end record;
   type Whole is record
      A : Integer;
      B : Cells;
   end record;
   type Nest is record
      I : Pair;
      Z : Integer;
   end record;
   type Twice is record
      I, J : Pair;
   end record;
   type Defaulted is record
      A : Integer := 0;
      B : Integer;
   end record;
   type Variant (N : Natural) is record
      L : Integer;
      case N is
         when 0 =>
            Y : Integer;
         when others =>
            W : Integer;
      end case;
   end record;
   type Base is tagged record
      A : Integer;
   end record;
   type Extended is new Base with record
      B : Integer;
   end record;
   type Number is new Integer;

   --  Relaxed_Initialization: code can leave these with parts that have no
   --  value, whatever an Output or an out parameter says.
   type Soft is new Integer with Relaxed_Initialization;
   type Soft_Pair is record
      A : Soft;
      B : Integer;
   end record;
   Relaxed_Global, Second_Relaxed : Integer with Relaxed_Initialization;
   Soft_Global : Soft;

   procedure Maybe_Relaxed (C : Boolean)
     with Global => (Output => Relaxed_Global);
   procedure Maybe_Second (C : Boolean)
     with Global => (Output => Second_Relaxed);
   procedure Maybe_Soft (C : Boolean) with Global => (Output => Soft_Global);
   procedure Maybe_Cells (C : Boolean; X : out Cells)
     with Relaxed_Initialization => X;
   procedure Maybe_Pair (C : Boolean; X : out Soft_Pair);

   procedure After_Relaxed_Output (C : Boolean; R : out Integer)
     with Global => (Output => Relaxed_Global);
   procedure After_Soft_Output (C : Boolean; R : out Integer)
     with Global => (Output => Soft_Global);
   procedure Set_Then_Output (C : Boolean; R : out Integer)
     with Global => (Output => Second_Relaxed);
   procedure After_Relaxed_Out (C : Boolean; R : out Integer);
   procedure After_Component_Out (C : Boolean; R : out Integer);
   procedure Parts_Then_Out (C : Boolean; R : out Integer);

   function Read_Bare return Integer with Global => (Input => Bare);
   function Read_Expanded return Integer with Global => (Input => Expanded);
   function "+" (L, R : Number) return Number
     with Global => (Input => Operator);
   function Read_In_Contract return Integer
     with Global => (Input => In_Contract);
   function Read_In_Declaration return Integer
     with Global => (Input => In_Declaration);
   function Read_In_Assertion return Integer
     with Global => (Input => In_Assertion);
   procedure Read_Before_Call (R : out Integer)
     with Global => (Input => Before_Call);
   procedure Set_Before_Call with Global => (Output => Before_Call);
   procedure Read_One_Path (R : out Integer)
     with Global => (Input => One_Path);
   procedure Set_One_Path with Global => (Output => One_Path);
   procedure Keep_In_Out with Global => (In_Out => In_Out_Early);

   procedure Call_Too_Early (R : out Integer)
     with Global => (Output => Before_Call);
   procedure Call_After_Branch (C : Boolean; R : out Integer)
     with Global => (Output => One_Path);
   procedure Bare_Too_Early (R : out Integer)
     with Global => (Output => Bare);
   procedure Expanded_Too_Early (R : out Integer)
     with Global => (Output => Expanded);
   procedure Operator_Too_Early (X : Number; R : out Number)
     with Global => (Output => Operator);
   procedure Contract_Too_Early
     with Global => (Output => In_Contract), Pre => Read_In_Contract > 0;
   procedure In_Out_Too_Early with Global => (Output => In_Out_Early);
   procedure Declaration_Too_Early (R : out Integer)
     with Global => (Output => In_Declaration);
   procedure Assertion_Too_Early
     with Global => (Output => In_Assertion);

   procedure Nested_Early (R : out Integer) with Global => null;
   procedure Through_Instance (R : out Integer) with Global => null;
   procedure Nested_No_Contract (R : out Integer) with Global => null;
   procedure Nested_Branch (C : Boolean; R : out Integer) with Global => null;

   procedure Missing_Component (Short : out Whole);
   procedure Component_One_Path (C : Boolean; Branch : out Whole);
   procedure Missing_Nested (Deep : out Nest);
   procedure Same_Name_Elsewhere (Doubled : out Twice);
   procedure Default_Not_Taken (Default : out Defaulted);
   procedure Variant_Branch (Choice : out Variant);
   procedure Missing_Parent (Child_Part : out Extended);
   function Other_Component return Integer;
   function Other_Object return Integer;

   procedure Short_Loop (Short_Range : out Cells);
   procedure Subtype_Loop (Sub_Range : out Cells);
   procedure Conditional_Loop (C : Boolean; Guarded : out Cells);
   procedure Exit_Loop (Left_Early : out Cells);
   procedure Other_Index_Loop (Other_Index : out Cells);
   function Element_By_Element return Integer;

   --  What an actual names is what such a parameter can leave without a
   --  value, through its indexes and components too; and every name the
   --  aspect lists is such a parameter.
   type Open_Cells is array (Positive range <>) of Integer;
   type Soft_Box is record
      D : Open_Cells (1 .. 4);
   end record with Relaxed_Initialization;
   procedure Maybe_Some (C : Boolean; X : out Open_Cells)
     with Relaxed_Initialization => X;
   procedure Maybe_Two (C : Boolean; X, Y : out Cells; Z : out Integer)
     with Relaxed_Initialization => (X, Y);
   procedure After_Relaxed_Slice (C : Boolean; R : out Integer);
   procedure After_Component_Slice (C : Boolean; R : out Integer);
   procedure After_Second_Listed (C : Boolean; R : out Integer);
end Verification_Mutation_Outside_Objects;
