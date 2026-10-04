package Precision_Non_Tagged_Derived_Type_Clean is
   type Root is tagged null record;
   type Child is new Root with record
      X : Integer := 0;
   end record;
   type Hidden is new Root with private;
   subtype Small is Integer range 0 .. 9;
private
   type Hidden is new Root with null record;
end Precision_Non_Tagged_Derived_Type_Clean;
