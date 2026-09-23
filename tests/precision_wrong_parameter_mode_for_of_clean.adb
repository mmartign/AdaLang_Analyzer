procedure Precision_Wrong_Parameter_Mode_For_Of_Clean is
   package Pins is
      type Pin is tagged record
         Level : Boolean := False;
      end record;
      procedure Set (This : in out Pin);
      type Pin_Array is array (Positive range <>) of Pin;
      procedure Set_All (Group : in out Pin_Array);
   end Pins;

   package body Pins is
      procedure Set (This : in out Pin) is
      begin
         This.Level := True;
      end Set;

      procedure Set_All (Group : in out Pin_Array) is
      begin
         for Item of Group loop
            Item.Set;
         end loop;
      end Set_All;
   end Pins;
begin
   null;
end Precision_Wrong_Parameter_Mode_For_Of_Clean;
