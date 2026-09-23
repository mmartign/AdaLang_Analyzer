procedure Precision_Wrong_Parameter_Mode_For_Of_Finding is
   type Level_Array is array (Positive range <>) of Integer;

   function Total (Levels : in out Level_Array) return Integer is
      Sum : Integer := 0;
   begin
      for Item of Levels loop
         Sum := Sum + Item;
      end loop;
      return Sum;
   end Total;

   Data : Level_Array := (1, 2, 3);
begin
   if Total (Data) > 10 then
      Data (1) := 0;
   end if;
end Precision_Wrong_Parameter_Mode_For_Of_Finding;
