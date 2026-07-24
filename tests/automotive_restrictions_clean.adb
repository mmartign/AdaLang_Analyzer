procedure Automotive_Restrictions_Clean is
   type Values is array (Positive range 1 .. 2) of Integer;

   procedure Increment (X : in out Integer) is
   begin
      X := X + 1;
   end Increment;

   Data : Values := (others => 0);
begin
   for Item of Data loop
      declare
         Value : Integer := Item;
      begin
         Increment (Value);
      end;
   end loop;
end Automotive_Restrictions_Clean;
