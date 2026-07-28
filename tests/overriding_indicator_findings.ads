package Overriding_Indicator_Findings is
   type Shape is tagged null record;
   procedure Draw (Self : Shape);

   type Circle is new Shape with null record;
   procedure Draw (Self : Circle);
end Overriding_Indicator_Findings;
