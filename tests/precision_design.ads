package Precision_Design is
   Hidden_Failure : exception;

   type Buffer (Size : Natural) is record
      Data : String (1 .. Size);
   end record;
   type Small_Buffer is new Buffer (Size => 8);
   type Forward (Size : Natural) is new Buffer (Size);

   type Ratio is digits 6;
   type Bounded is digits 6 range 0.0 .. 1.0;
   subtype Sub_Ratio is Ratio;
   type Money is delta 0.01 range 0.0 .. 100.0;

   subtype Index is Integer range 1 .. 10;
   type Table is array (Integer range 1 .. 4) of Integer;
   Field : String (1 .. 5) := "hello";
   Tolerance : constant Integer := 3;

   generic
      type Item is private;
      Zero : Item;
      Scale : Integer := 1;
   package Holder is
      Stored : Item := Zero;
   end Holder;

   type Root is tagged record
      Count : Integer := 0;
   end record
     with Type_Invariant => Root.Count >= 0;
   procedure Reset (This : in out Root);
   procedure Bump (This : in out Root) with Pre'Class => True;

   type Child is new Root with null record;
   overriding procedure Reset (This : in out Child);
   overriding procedure Bump (This : in out Child);

   procedure Run (Value : in Index; R : in out Root'Class);
private
   Private_Failure : exception;
end Precision_Design;
