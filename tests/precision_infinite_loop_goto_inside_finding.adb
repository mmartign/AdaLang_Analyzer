--  A goto to a label inside the loop, even from a nested loop, does not
--  leave it: the outer loop still has no termination path.
procedure Precision_Infinite_Loop_Goto_Inside_Finding
  (Next : access function return Integer; Choice : out Integer)
is
begin
   loop
      <<Again>>
      Choice := Next.all;
      for I in 1 .. 3 loop
         if Choice = I then
            goto Again;
         end if;
      end loop;
   end loop;
end Precision_Infinite_Loop_Goto_Inside_Finding;
