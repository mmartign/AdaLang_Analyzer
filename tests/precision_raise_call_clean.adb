procedure Precision_Raise_Call_Clean (X : Integer) is
   procedure Raise_Alert is
   begin
      null;
   end Raise_Alert;
begin
   if X < 0 then
      Raise_Alert;
   end if;
end Precision_Raise_Call_Clean;
