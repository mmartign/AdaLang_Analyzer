procedure Verification_Loop_Branch_Ite_Cond_Unsupported_Precision
  (Chain : in out String;
   Rnd   : in out String)
is
   Chain_Len : Natural range 0 .. Chain'Length := 0;
   Rnd_Len   : Natural range 0 .. Rnd'Length := 0;
begin
   while Chain_Len < Chain'Length and then Rnd_Len < Rnd'Length loop
      pragma Loop_Invariant (Chain_Len in 0 .. Chain'Length);

      if Rnd (Rnd_Len + 1) = 'x' then
         Chain_Len := Chain_Len + 1;
         Chain (Chain_Len) := 'y';
      end if;

      Rnd_Len := Rnd_Len + 1;
   end loop;
end Verification_Loop_Branch_Ite_Cond_Unsupported_Precision;
