package body Precision_Oop_Shapes is
   function Make return Shape is (Shape'(Sides => 3));
   function Area (Item : in Shape) return Integer is (Item.Sides);

   procedure Grow (This : in out Shape) is
   begin
      This.Sides := This.Sides + 1;
   end Grow;

   procedure Draw (This : in Shape) is null;
   procedure Hide (This : in Shape) is null;

   procedure Move (This : in out Shape; By : in Integer) is
   begin
      This.Sides := This.Sides + By;
   end Move;

   procedure Reset (This : in out Shape) is
   begin
      This.Sides := 0;
   end Reset;

   protected body Guard is
      entry Wait when Open is
      begin
         Open := False;
      end Wait;

      entry Wait_Total when Total > 0 is
      begin
         Open := True;
      end Wait_Total;
   end Guard;
end Precision_Oop_Shapes;
