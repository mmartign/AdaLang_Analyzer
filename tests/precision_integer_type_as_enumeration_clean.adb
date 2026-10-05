procedure Precision_Integer_Type_As_Enumeration_Clean is
   type Counter is range 0 .. 100;
   type Mask is mod 16;
   type Colour is (Red, Green, Blue);

   generic
      type Index is range <>;
   package Holder is
      First : Index := Index'First;
   end Holder;

   type Slot is range 1 .. 4;
   package Slots is new Holder (Slot);

   N : Counter := 0;
   M : Mask := 1;
   K : Colour := Red;
begin
   N := N + 1;
   M := not M;
   if K = Red and then Slots.First = 1 then
      null;
   end if;
end Precision_Integer_Type_As_Enumeration_Clean;
