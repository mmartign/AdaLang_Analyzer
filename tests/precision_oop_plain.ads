package Precision_Oop_Plain is
   type Shape is tagged private;
   procedure Grow (This : in out Shape);

   type Point is record
      X : Integer;
   end record;

   Total : Integer := 0;
   Limit : constant Integer := 4;
private
   type Shape is tagged record
      Sides : Integer;
   end record;
end Precision_Oop_Plain;
