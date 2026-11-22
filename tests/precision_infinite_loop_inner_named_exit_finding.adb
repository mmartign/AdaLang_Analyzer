--  Exits that name only the nested loop leave the nested loop, not the
--  outer one: the outer loop has no termination path.
procedure Precision_Infinite_Loop_Inner_Named_Exit_Finding
  (Next : access function return Integer)
is
   Choice : Integer;
begin
   Outer :
   loop
      Inner :
      loop
         Choice := Next.all;
         exit Inner when Choice = 2;
         exit;
      end loop Inner;
   end loop Outer;
end Precision_Infinite_Loop_Inner_Named_Exit_Finding;
