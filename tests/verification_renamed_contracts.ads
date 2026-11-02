--  A call of a renaming asks what the subprogram it renames asks. The
--  precondition names the formals of that subprogram, which take the
--  renaming's by position: their names mean nothing. Every claim here
--  holds. verification_mutation_renamed_contracts has those that do not.
package Verification_Renamed_Contracts
  with SPARK_Mode
is
   procedure Lemma (Val : Integer; Size : Positive)
     with Pre => Size <= 8 and then Val < Size;

   procedure Same (Val : Integer; Size : Positive) renames Lemma;

   --  The names of the formals are crossed: Size is Val of Lemma.
   procedure Crossed (Size : Integer; Val : Positive) renames Lemma;

   procedure Twice (Val : Integer; Size : Positive) renames Same;

   procedure Use_Same (X : Integer) with Pre => X in 0 .. 3;
   procedure Use_Crossed (X : Integer) with Pre => X in 0 .. 3;
   procedure Use_Twice (X : Integer) with Pre => X in 0 .. 3;
end Verification_Renamed_Contracts;
