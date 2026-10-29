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

   --  A slice that is the target of an assignment has an index check at
   --  each of its bounds as well as the check of the slice. Here both
   --  bounds are of a subtype inside the array's index range.
   function Fill (Lowest, Highest : Index) return Integer
     with Pre => True
   is
      Filled : Vector (1 .. 10) := (others => 0);
   begin
      Filled (Lowest .. Highest) := (others => 1);
      return Filled (1);
   end Fill;

   --  A null target: its bounds are not checked.
   function Fill_Nothing return Integer
     with Pre => True
   is
      Past   : constant := 12;
      Unused : Vector (1 .. 10) := (others => 0);
   begin
      Unused (Past .. Past - 1) := (others => 1);
      return Unused (1);
   end Fill_Nothing;

   --  The high bound is outside the array only when the slice is null,
   --  for a Count of zero or one.
   function Fill_Before (Count : Natural) return Integer
     with Pre => Count <= 11
   is
      Before : Vector (1 .. 10) := (others => 0);
   begin
      Before (1 .. Count - 1) := (others => 1);
      return Before (1);
   end Fill_Before;

   --  The bounds of the target are those of the object itself. Not
   --  called below, as Head.
   procedure Clear_Head (Cells : in out Vector)
     with Pre => Cells'Length >= 2 and then Cells'Last < Positive'Last
   is
   begin
      Cells (Cells'First .. Cells'First + 1) := (0, 0);
   end Clear_Head;

   Seen : constant Boolean :=
     Middle >= 0
     and then Nothing >= 0
     and then Between (2, 3) >= 0
     and then Fill (2, 3) >= 0
     and then Fill_Nothing >= 0
     and then Fill_Before (3) >= 0;
begin
   pragma Assert (Seen or else not Seen);
end Verification_Slice_Bounds;
