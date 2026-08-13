procedure Verification_Mutation_Runtime
  (X : Integer;
   Sink : out Integer)
with SPARK_Mode,
     Pre => X = 11
is
   subtype Small is Integer range 0 .. 10;
   type Values is array (Small) of Integer;

   V : Small;
   A : Values := (others => 0);
begin
   V := X;
   Sink := A (X);
   Sink := 1 / (X - 11);
   Sink := Integer'Last + X;
end Verification_Mutation_Runtime;
