package Overriding_Indicator_Clean is
   type Shape is tagged null record;
   procedure Draw (Self : Shape);

   type Circle is new Shape with null record;
   overriding procedure Draw (Self : Circle);
end Overriding_Indicator_Clean;
