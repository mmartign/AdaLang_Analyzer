--  What the parts of a condition do not say. Each claim marked in the
--  body is false for some value the subprogram can be given: none of them
--  is to be proved.
package Verification_Mutation_Condition_Parts with SPARK_Mode => On is

   type Slot is (First, Second, Third);
   subtype Inner is Slot range Second .. Third;
   subtype Ends is Slot with Static_Predicate => Ends in First | Third;
   type Marks is array (Slot) of Integer;
   type Table is array (1 .. 8) of Integer;
   subtype Place is Integer range 1 .. 8;

   function Fine (X, Y : Integer) return Boolean is (X > 0 and then Y > 0);
   function Low (N : Integer) return Boolean is (N < 10);
   function All_Positive (M : Marks) return Boolean is
     (for all S in Slot => M (S) > 0);

   procedure Not_Selected (On : Boolean; Loose : Integer)
     with Pre => (if On then Loose > 0);
   procedure Other_Branch (On : Boolean; Left, Stray : Integer)
     with Pre => (if On then Left > 0 else Stray > 0);
   procedure Outside_Subtype (Scored : Marks)
     with Pre => (for all S in Inner => Scored (S) > 0);
   procedure Outside_Predicate (Sparse : Marks)
     with Pre => (for all S in Ends => Sparse (S) > 0);
   procedure Outside_Range (Filled : Table)
     with Pre => (for all K in 2 .. 4 => Filled (K) >= 0);
   procedure Stronger (Graded : Marks)
     with Pre => (for all S in Slot => Graded (S) > 0);
   procedure Not_All (Mixed : Marks)
     with Pre => not (for all S in Slot => Mixed (S) > 0);
   procedure Other_Actual (T : Table; I, J : Place; Kept : Integer)
     with Pre => Fine (T (I), Kept);
   procedure Formal_Is_No_Object (T : Table; I, J : Place)
     with Pre => Low (T (I));
   procedure Not_Returned_True (Ranked : Marks)
     with Pre => not All_Positive (Ranked);

end Verification_Mutation_Condition_Parts;
