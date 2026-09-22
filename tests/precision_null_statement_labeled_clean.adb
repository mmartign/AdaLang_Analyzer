procedure Precision_Null_Statement_Labeled_Clean (X : in out Integer) is
begin
   if X > 0 then
      goto Done;
   end if;
   X := X + 1;
   <<Done>>
   null;
   X := X + 2;
end Precision_Null_Statement_Labeled_Clean;
