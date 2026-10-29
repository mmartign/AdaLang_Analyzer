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

   --  The same, for slices that are the target of an assignment, each
   --  bound of which has an index check of its own.

   --  The high bound of the target is any Integer.
   function Fill_Open (From : Index; Wide_Upper : Integer) return Integer
     with Pre => True
   is
      Open_Store : Vector (1 .. 10) := (others => 0);
   begin
      Open_Store (From .. Wide_Upper) := (others => 1);
      return Open_Store (1);
   end Fill_Open;

   --  A target that is null for every value of Nearly_Count but zero.
   function Fill_Almost_Null (Nearly_Count : Natural) return Integer
     with Pre => True
   is
      Nearly : Vector (1 .. 10) := (others => 0);
   begin
      Nearly (Nearly_Count .. 0) := (others => 1);
      return Nearly (1);
   end Fill_Almost_Null;

   --  Not null, the target reaches one past the array when Tail_Count is
   --  twelve.
   function Fill_Tail (Tail_Count : Natural) return Integer
     with Pre => Tail_Count <= 12
   is
      Tail_Store : Vector (1 .. 10) := (others => 0);
   begin
      Tail_Store (1 .. Tail_Count - 1) := (others => 1);
      return Tail_Store (1);
   end Fill_Tail;

   --  Nothing says the target has two elements.
   procedure Clear_Brief (Brief : in out Vector)
     with Pre => Brief'Last < Positive'Last
   is
   begin
      Brief (Brief'First .. Brief'First + 1) := (0, 0);
   end Clear_Brief;

   Seen : constant Boolean :=
     Open_High (1, 3) >= 0
     and then Below (1) >= 0
     and then Above (1) >= 0
     and then Almost_Null (1) >= 0
     and then Head (Data) >= 0
     and then Fill_Open (1, 3) >= 0
     and then Fill_Almost_Null (1) >= 0
     and then Fill_Tail (3) >= 0;
begin
   pragma Assert (Seen or else not Seen);
end Verification_Mutation_Slice_Bounds;
