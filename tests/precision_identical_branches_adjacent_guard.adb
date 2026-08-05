procedure Precision_Identical_Branches_Adjacent_Guard is
   A, B, X : Integer := 1;
begin
   if A = 1 then
      X := 1;
   elsif B = 1 then
      X := 1;
   end if;
end Precision_Identical_Branches_Adjacent_Guard;
