package body Verification_Renamed_Contracts
  with SPARK_Mode
is
   procedure Lemma (Val : Integer; Size : Positive) is null;

   procedure Use_Same (X : Integer) is
   begin
      Same (X, 4);
   end Use_Same;

   --  By name, Lemma would be given Size => X, which X = 0 breaks.
   procedure Use_Crossed (X : Integer) is
   begin
      Crossed (X, 4);
   end Use_Crossed;

   procedure Use_Twice (X : Integer) is
   begin
      Twice (X, 4);
   end Use_Twice;
end Verification_Renamed_Contracts;
