--  A condition that holds is taken part by part, so that a part the
--  scalar VC language cannot express does not cost the others: what a
--  conditional expression selects holds under its condition, a quantified
--  expression over a few values holds of each, and a call of an expression
--  function that returned True is its body holding of the actuals. Every
--  claim marked in the body holds; the ones that do not are in
--  Verification_Mutation_Condition_Parts.
package Verification_Condition_Parts with SPARK_Mode => On is

   type Slot is (First, Second, Third);
   subtype Inner is Slot range Second .. Third;
   type Marks is array (Slot) of Integer;
   type Table is array (1 .. 8) of Integer;
   subtype Place is Integer range 1 .. 8;

   function Fine (X, Y : Integer) return Boolean is (X > 0 and then Y > 0);
   function All_Positive (M : Marks) return Boolean is
     (for all S in Slot => M (S) > 0);
   function Guarded (On : Boolean; M : Marks) return Boolean is
     (if On then All_Positive (M) and then M (First) < 100);

   procedure Selected (On : Boolean; Chosen : Integer; T : Table; I : Place)
     with Pre => (if On then Chosen > 0 and then T (I) > 0);
   procedure Otherwise (On : Boolean; Left, Right : Integer)
     with Pre => (if On then Left > 0 else Right > 0);
   procedure Each_Value (Graded : Marks)
     with Pre => (for all S in Slot => Graded (S) > 0);
   procedure Each_In_Subtype (Scored : Marks)
     with Pre => (for all S in Inner => Scored (S) > 0);
   procedure Each_In_Range (Filled : Table)
     with Pre => (for all K in 2 .. 4 => Filled (K) >= 0);
   procedure Body_Read (T : Table; I : Place; Kept : Integer)
     with Pre => Fine (T (I), Kept);
   procedure Body_Quantified (Ranked : Marks) with Pre => All_Positive (Ranked);
   procedure Body_Guarded (On : Boolean; Sorted : Marks)
     with Pre => Guarded (On, Sorted);

end Verification_Condition_Parts;
