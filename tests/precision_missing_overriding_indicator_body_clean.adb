procedure Precision_Missing_Overriding_Indicator_Body_Clean is
   package Shapes is
      type Shape is tagged null record;
      procedure Draw (Item : Shape);
   end Shapes;

   package body Shapes is
      type Circle is new Shape with null record;
      overriding procedure Draw (Item : Circle);

      procedure Draw (Item : Shape) is
      begin
         null;
      end Draw;

      procedure Draw (Item : Circle) is
      begin
         Draw (Shape (Item));
      end Draw;
   end Shapes;
begin
   null;
end Precision_Missing_Overriding_Indicator_Body_Clean;
