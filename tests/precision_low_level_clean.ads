package Precision_Low_Level_Clean is
   type Byte is mod 2 ** 8;

   type Plain is record
      Kind : Byte;
      Size : Byte;
   end record;

   Counter : aliased Integer := 0;
   type Int_Ref is access all Integer;
   Ref : constant Int_Ref := Counter'Access;
end Precision_Low_Level_Clean;
