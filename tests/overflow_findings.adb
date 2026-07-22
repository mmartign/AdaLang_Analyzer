procedure Overflow_Findings is
   A : Integer := 2_147_483_647;
   B : Integer := -2_147_483_648;
begin
   A := A + 1;
   B := B - 1;
end Overflow_Findings;
