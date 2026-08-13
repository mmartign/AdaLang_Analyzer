procedure Verification_Loop_Invariant_Independent_Failure
  (Data : String;
   Y    : out Integer)
  with SPARK_Mode,
       Pre => Data'Length >= 1
is
   I : Natural range 0 .. Data'Length := 0;
begin
   Y := 0;
   while I < Data'Length loop
      pragma Loop_Invariant (I in 0 .. Data'Length);
      pragma Loop_Invariant (Data (Data'First + I) = Data (Data'First + I));

      Y := Y + 1;
      I := I + 1;
   end loop;
end Verification_Loop_Invariant_Independent_Failure;
