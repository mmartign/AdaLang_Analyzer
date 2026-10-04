package Precision_Positional_Pkg is
   procedure Move (From : in Integer; To : in Integer);
   procedure Scale (Value : in Integer; Factor : in Integer := 2);
   procedure Single (Value : in Integer);

   generic
      type Item is private;
      Zero : Item;
   package Holder is
      Stored : Item := Zero;
   end Holder;

   generic
      type Item is private;
   package Box is
      type Ref is access Item;
   end Box;

   type Point is record
      X, Y : Integer;
   end record;
   type Triple is array (1 .. 3) of Integer;
   type Money is delta 0.01 range 0.0 .. 1000.0;
   type Colour is (Red, Green, Blue);
end Precision_Positional_Pkg;
