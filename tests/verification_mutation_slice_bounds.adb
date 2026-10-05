procedure Verification_Mutation_Slice_Bounds
  with SPARK_Mode
is
   type Vector is array (Positive range <>) of Integer;
   subtype Index is Integer range 1 .. 10;

   Data    : constant Vector (1 .. 10) := (others => 0);
   Reserve : constant Vector (1 .. 10) := (others => 1);

   --  The trivial preconditions make GNATprove check each function on its
   --  own: at the calls below the bounds happen to fit.

   --  The high bound is any Integer.
   function Open_High (From : Index; Upper : Integer) return Integer
     with Pre => True
   is
      Unbounded_High : constant Vector := Data (From .. Upper);
   begin
      return Unbounded_High'Length;
   end Open_High;

   --  The low bound can be zero, below the array, with a slice that is
   --  not null.
   function Below (Count : Natural) return Integer
     with Pre => True
   is
      Low_Outside : constant Vector := Data (Count .. 3);
   begin
      return Low_Outside'Length;
   end Below;

   --  The high bound is above the array; the slice is null only for some
   --  values of From.
   function Above (From : Index) return Integer
     with Pre => True
   is
      High_Outside : constant Vector := Data (From .. 20);
   begin
      return High_Outside'Length;
   end Above;

   --  Looks like a null slice, and is one unless Count is zero: then it
   --  is the one-element slice 0 .. 0, outside the array.
   function Almost_Null (Count : Natural) return Integer
     with Pre => True
   is
      Zero_To_Zero : constant Vector := Reserve (Count .. 0);
   begin
      return Zero_To_Zero'Length;
   end Almost_Null;

   --  Nothing says the object has two elements.
   function Head (Short : Vector) return Integer
     with Pre => Short'Last < Positive'Last
   is
      Too_Long : constant Vector := Short (Short'First .. Short'First + 1);
   begin
      return Too_Long'Length;
   end Head;

   Seen : constant Boolean :=
     Open_High (1, 3) >= 0
     and then Below (1) >= 0
     and then Above (1) >= 0
     and then Almost_Null (1) >= 0
     and then Head (Data) >= 0;
begin
   pragma Assert (Seen or else not Seen);
end Verification_Mutation_Slice_Bounds;
