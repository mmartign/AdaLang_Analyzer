procedure Precision_Named_Loop_Clean is
   I : Integer := 0;
begin
   Outer :
   loop
      I := I + 1;
      exit Outer when I >= 3;
   end loop Outer;
end Precision_Named_Loop_Clean;
