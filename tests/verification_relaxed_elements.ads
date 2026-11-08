--  The elements of an array of an object with relaxed initialization
--  (SPARK RM 6.10): an element given a value of a scalar type has one, a
--  slice given a value with no part that has none has one in every
--  element, and so has an element or a slice passed as the actual of an
--  out parameter that has a value on return -- one with no relaxed
--  initialization, or one whose postcondition says so. X'Initialized of an
--  element, of a slice and of the whole array follows, and so does a read
--  of an element. A precondition, an assertion and a loop invariant that
--  say X (I)'Initialized, also for every I of a range, give the same, and
--  the parameter of a quantified expression is in its range where the
--  predicate is evaluated. Every claim here holds; GNATprove proves each.
--  verification_mutation_relaxed_elements has those that do not.
package Verification_Relaxed_Elements
  with SPARK_Mode
is
   type Arr is array (1 .. 4) of Integer;
   type Bytes is array (Natural range <>) of Integer;
   subtype Bytes_2 is Bytes (0 .. 1);

   procedure Fill_Two (Pair : out Bytes_2) with Global => null;
   procedure Fill_Relaxed_Two (Soft_Pair : out Bytes_2)
     with Global => null, Relaxed_Initialization => Soft_Pair,
          Post => Soft_Pair'Initialized;

   procedure Element_Writes (Row : out Arr; Elem_Read : out Integer)
     with Relaxed_Initialization => Row;
   function Pick (Given_Rows : Arr; Upto : Positive) return Boolean
     with Relaxed_Initialization => Given_Rows,
          Pre => Upto in 2 .. 4 and then Given_Rows (1)'Initialized
                 and then (for all K in 2 .. Upto =>
                             Given_Rows (K)'Initialized);
   function All_Positive (Ranged : Arr; Upto : Natural) return Boolean
   is (for all K in 1 .. Upto => Ranged (K) > 0)
     with Relaxed_Initialization => Ranged,
          Pre => Upto <= 4 and then
                 (for all K in 1 .. Upto => Ranged (K)'Initialized);
   procedure Slice_Write (Band : out Arr; Band_Read : out Integer)
     with Relaxed_Initialization => Band;
   procedure Slice_Actuals (Strip : out Bytes; Strip_Read : out Integer)
     with Relaxed_Initialization => Strip,
          Pre => Strip'First = 0 and then Strip'Last = 3;
   procedure Loop_Elements (Lane : out Arr; Lane_Read : out Integer)
     with Relaxed_Initialization => Lane;
   procedure Known_Index (Spot : out Arr; At_Index : Positive)
     with Relaxed_Initialization => Spot, Pre => At_Index <= 4;
end Verification_Relaxed_Elements;
