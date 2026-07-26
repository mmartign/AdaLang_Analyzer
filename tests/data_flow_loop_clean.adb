--  Negative fixture for loop-carried data-flow. Assignments at the end of an
--  iteration are read by the next condition or iteration and are not dead.
procedure Data_Flow_Loop_Clean is
   Current, Next : Integer := 0;
begin
   while Current < 3 loop
      Next := Current + 1;
      Current := Next;
   end loop;
end Data_Flow_Loop_Clean;
