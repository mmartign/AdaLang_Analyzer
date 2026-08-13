procedure Verification_Loop_Variant_Dynamic_Bound
  (Chain : in out String)
is
   Chain_Len : Natural range 0 .. Chain'Length := 0;
begin
   while Chain_Len < Chain'Length loop
      pragma Loop_Invariant (Chain_Len >= 0);
      pragma Loop_Variant (Increases => Chain_Len);

      Chain_Len := Chain_Len + 1;
   end loop;
end Verification_Loop_Variant_Dynamic_Bound;
