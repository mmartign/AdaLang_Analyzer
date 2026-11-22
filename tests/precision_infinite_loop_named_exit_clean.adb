--  "exit Outer;" from inside a nested loop leaves Outer: Outer has a
--  termination path (honki_tonks_zivilisationen's save-game menu, FP-167).
procedure Precision_Infinite_Loop_Named_Exit_Clean
  (Next : access function return Integer; Choice : out Integer)
is
begin
   Outer :
   loop
      Inner :
      loop
         Choice := Next.all;
         case Choice is
            when 1 =>
               exit Outer;
            when 2 =>
               exit Inner;
            when others =>
               null;
         end case;
      end loop Inner;
   end loop Outer;
end Precision_Infinite_Loop_Named_Exit_Clean;
