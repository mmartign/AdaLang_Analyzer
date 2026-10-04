with System;
with Ada.Unchecked_Conversion;

procedure Precision_Low_Level is
   type Byte is mod 2 ** 8;
   type Nibble is mod 2 ** 4;
   type Int_Ref is access all Integer;

   type Flags is record
      Low  : Nibble;
      High : Nibble;
   end record;
   pragma Pack (Flags);

   type Header is record
      Kind : Byte;
      Size : Byte;
   end record;
   for Header use record
      Kind at 0 range 0 .. 7;
      Size at 1 range 0 .. 7;
   end record;

   type Complete is record
      Kind : Byte;
   end record
     with Pack, Size => 8, Scalar_Storage_Order => System.Low_Order_First,
          Bit_Order => System.Low_Order_First;
   for Complete use record
      Kind at 0 range 0 .. 7;
   end record;

   type Colour is (Red, Green);
   Spacer : Integer := 0;
   for Colour use (Red => 1, Green => 4);

   function To_Ref is new Ada.Unchecked_Conversion (System.Address, Int_Ref);
   function To_Byte is new Ada.Unchecked_Conversion (Nibble, Byte);

   Limit    : constant Integer := 10;
   Counter  : aliased Integer := 0;
   Shared   : Integer := 0 with Volatile;
   Over_Constant : Integer with Address => Limit'Address;
   Over_Variable : constant Integer with Import, Address => Counter'Address;
   Fixed_Place   : Integer with Address => System'To_Address (16#1000#);
   Imported      : Integer with Import, Address => Shared'Address;
   Old_Style     : Integer;
   for Old_Style'Address use Counter'Address;

   Where : constant System.Address := Counter'Address;
   Ref   : constant Int_Ref := Counter'Access;
   Other : constant Int_Ref := To_Ref (Where);

   procedure Show (Value : in Byte) is null;
begin
   Show (To_Byte (Nibble'(3)));
   Spacer := Other.all + Ref.all + Over_Constant + Over_Variable
     + Fixed_Place + Imported + Old_Style;
end Precision_Low_Level;
