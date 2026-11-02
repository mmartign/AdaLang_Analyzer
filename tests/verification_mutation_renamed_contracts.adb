package body Verification_Mutation_Renamed_Contracts
  with SPARK_Mode
is
   procedure Lemma (Val : Integer; Size : Positive) is null;

   --  Nothing bounds X.
   procedure Unbounded (X : Integer) is
   begin
      Same (X, 4);
   end Unbounded;

   --  By position Lemma (X, 1): X < 1 is false. By name it would be
   --  Lemma (Val => 1, Size => X), which holds.
   procedure By_Name (X : Integer) is
   begin
      Crossed (X, 1);
   end By_Name;

   --  Size 9 breaks Size <= 8, through two renamings.
   procedure Too_Big (X : Integer) is
   begin
      Twice (X, 9);
   end Too_Big;
end Verification_Mutation_Renamed_Contracts;
