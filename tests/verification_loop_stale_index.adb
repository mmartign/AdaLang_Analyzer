procedure Verification_Loop_Stale_Index (Arg : Positive) is
   Arr : array (0 .. 2) of Integer := (others => 0);
   Idx : Integer := 0;
   V2  : Integer;
begin
   for I in 1 .. Arg loop
      Idx := 5;
   end loop;
   V2 := Arr (Idx);
end Verification_Loop_Stale_Index;
