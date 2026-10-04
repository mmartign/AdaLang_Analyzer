package Precision_Oop_Shapes is
   type Shape is tagged record
      Sides : Integer := 0;
   end record
     with Type_Invariant => Shape.Sides >= 0;

   function Make return Shape;
   function Area (Item : in Shape) return Integer
     with Pre => Item.Sides > 0;
   procedure Grow (This : in out Shape);
   procedure Draw (This : in Shape);
   procedure Hide (This : in Shape);
   procedure Move (This : in out Shape; By : in Integer);
   procedure Reset (This : in out Shape);

   type Square is new Shape with null record;
   type Tile is new Square with null record;
   type Mosaic is new Tile with null record;

   type Printable is interface;
   type Storable is interface;
   type Comparable is interface;
   type Hashable is interface;
   type Countable is interface;
   type Sizable is interface;
   type Everything is new Shape and Printable and Storable and Comparable
     and Hashable and Countable and Sizable with null record;

   Total : Integer;
   Sensor : Integer := 0 with Volatile;

   protected Guard is
      entry Wait;
      entry Wait_Total;
   private
      Open : Boolean := False;
   end Guard;
end Precision_Oop_Shapes;
