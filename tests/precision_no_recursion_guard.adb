procedure Precision_No_Recursion_Guard (N : Integer) is
begin
   if N > 0 then
      Precision_No_Recursion_Guard (N - 1);
   end if;
end Precision_No_Recursion_Guard;
