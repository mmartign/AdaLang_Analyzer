--  A while condition true on entry that the body changes is tested again
--  after every iteration: it is not constant (PHCpack's random distinct
--  indices, FP-166).
procedure Precision_Constant_Condition_While_Reassigned_Clean
  (Size : Positive; Seed : Integer; Last : out Integer)
is
   Res  : array (1 .. 10) of Integer := (others => 0);
   Rnd  : Integer := Seed;
   Redo : Boolean;
begin
   for K in 1 .. Size loop
      Redo := True;
      while Redo loop
         Rnd := (Rnd * 7 + 3) mod 11;
         Redo := False;
         for I in 1 .. K - 1 loop
            if Res (I) = Rnd then
               Redo := True;
            end if;
         end loop;
      end loop;
      Res (K) := Rnd;
   end loop;
   Last := Rnd;
end Precision_Constant_Condition_While_Reassigned_Clean;
