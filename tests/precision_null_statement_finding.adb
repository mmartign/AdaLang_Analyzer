procedure Precision_Null_Statement_Finding (X : in out Integer) is
begin
   if X > 0 then
      null;
      X := X + 1;
   end if;
end Precision_Null_Statement_Finding;
