--  T'Size of a static discrete subtype is the number of bits its values
--  take, or the Size its first subtype is given (RM 13.3(55)).
package Verification_Type_Size with SPARK_Mode is

   type Byte is mod 2 ** 8;
   type Wide is mod 2 ** 64;
   type Decimal is mod 10;
   type Percent is range 0 .. 100;
   type Signed is range -5 .. 5;
   type Stored is range 0 .. 100 with Size => 16;
   type Claused is range 0 .. 100;
   for Claused'Size use 24;
   type Colour is (Red, Green, Blue);
   type Coded is (Low, High);
   for Coded use (Low => 1, High => 100);

   subtype Same is Byte;
   subtype Nibble is Byte range 0 .. 15;
   subtype Kept is Stored;
   subtype Cut is Stored range 0 .. 3;
   subtype Nothing is Integer range 1 .. 0;
   subtype Warm is Colour range Red .. Green;
   type Derived is new Stored;
   type Tight is new Stored range 0 .. 3;
   type Shorter is new Percent range 0 .. 10;
   type Length is new Natural;

   --  Each of these is what GNAT gives.
   procedure Known;

   --  None of these is: each says of one type that it has another size.
   procedure Wrong;

   --  Nothing is known of these: a representation clause, the range of
   --  an enumeration subtype, a character type, an object.
   procedure Unknown (Item : Byte);

   --  The use it is put to: a division by the size of a byte.
   procedure Bytes (Bits : Natural; Count : out Natural);

end Verification_Type_Size;
