procedure Verification_Loop_Length_Symbolic_Clean
  (Chain : in out String)
is
   Chain_Len : Natural range 0 .. Chain'Length := 0;
   I         : Integer := 0;
begin
   while Chain_Len < Chain'Length and then I < 3 loop
      pragma Loop_Invariant (Chain_Len in 0 .. Chain'Length);
      pragma Loop_Variant (Increases => I);

      Chain_Len := Chain_Len + 1;
      I := I + 1;
   end loop;
end Verification_Loop_Length_Symbolic_Clean;
