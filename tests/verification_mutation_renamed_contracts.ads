--  The calls of verification_renamed_contracts with what makes them wrong.
package Verification_Mutation_Renamed_Contracts
  with SPARK_Mode
is
   procedure Lemma (Val : Integer; Size : Positive)
     with Pre => Size <= 8 and then Val < Size;

   procedure Same (Val : Integer; Size : Positive) renames Lemma;

   --  The names of the formals are crossed: Size is Val of Lemma.
   procedure Crossed (Size : Integer; Val : Positive) renames Lemma;

   procedure Twice (Val : Integer; Size : Positive) renames Same;

   procedure Unbounded (X : Integer);
   procedure By_Name (X : Integer) with Pre => X in 5 .. 8;
   procedure Too_Big (X : Integer) with Pre => X in 0 .. 3;
end Verification_Mutation_Renamed_Contracts;
