procedure Precision_Identical_Branches_Nonadjacent_Clean is
   A, B, X : Integer := 1;
begin
   if A = 1 then
      X := 1;
   elsif B = 1 then
      X := 2;
   else
      X := 1;
   end if;
end Precision_Identical_Branches_Nonadjacent_Clean;
