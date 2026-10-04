package Precision_Unconstrained_Array_Type_Clean is
   type Vector is array (1 .. 8) of Integer;

   generic
      type Item is private;
      type Items is array (Positive range <>) of Item;
   procedure Clear (Target : in out Items; Blank : in Item);
end Precision_Unconstrained_Array_Type_Clean;
