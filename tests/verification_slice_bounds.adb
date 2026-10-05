procedure Verification_Slice_Bounds
  with SPARK_Mode
is
   type Vector is array (Positive range <>) of Integer;
   subtype Index is Integer range 1 .. 10;

   Data  : constant Vector (1 .. 10) := (others => 0);
   Spare : constant Vector (1 .. 10) := (others => 1);

   --  The trivial preconditions make GNATprove check each function on its
   --  own and not only where it is called.

   --  Both bounds are literals inside 1 .. 10.
   function Middle return Integer
     with Pre => True
   is
      Part : constant Vector := Data (2 .. 5);
   begin
      return Part'Length;
   end Middle;

   --  A null slice: its bounds are not checked, wherever they are.
   function Nothing return Integer
     with Pre => True
   is
      Part : constant Vector := Spare (12 .. 11);
   begin
      return Part'Length;
   end Nothing;

   --  Both bounds are of a subtype inside the array's index range.
   function Between (From, To : Index) return Integer
     with Pre => True
   is
      Part : constant Vector := Data (From .. To);
   begin
      return Part'Length;
   end Between;

   --  The bounds are those of the sliced object itself. Not called below:
   --  it has a contract, so it is verified for every array that meets it.
   function Head (Items : Vector) return Integer
     with Pre => Items'Length >= 2 and then Items'Last < Positive'Last
   is
      Part : constant Vector := Items (Items'First .. Items'First + 1);
   begin
      return Part'Length;
   end Head;

   Seen : constant Boolean :=
     Middle >= 0
     and then Nothing >= 0
     and then Between (2, 3) >= 0;
begin
   pragma Assert (Seen or else not Seen);
end Verification_Slice_Bounds;
