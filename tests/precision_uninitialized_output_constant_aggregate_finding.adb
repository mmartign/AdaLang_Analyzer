--  At the same shape, the aggregate can raise when 0 is stored in a
--  component whose own constraint excludes it (Storage_Count range 1 .. 8),
--  or when the constant has a subtype other than the component's (a
--  Natural of unknown value into a Positive): the handler can then run
--  before the out parameter is set.
with System.Storage_Elements; use System.Storage_Elements;
procedure Precision_Uninitialized_Output_Constant_Aggregate_Finding
  (N : Natural)
is
   type Sized is record
      Length : Storage_Count range 1 .. 8;
   end record;
   type Sizes is array (Natural range <>) of Sized;
   type Leveled is record
      Level : Positive;
   end record;
   Seed : constant Natural := N;

   procedure Get_Sizes (S : out Sizes; Count : out Natural) is
   begin
      S := [others => (Length => 0)];
      Count := 0;
      Count := Count + S'Length;
   exception
      when Constraint_Error =>
         Count := 0;
   end Get_Sizes;

   procedure Get_Level (R : out Leveled; Count : out Natural) is
   begin
      R := (Level => Seed);
      Count := 0;
      Count := Count + N;
   exception
      when Constraint_Error =>
         Count := 0;
   end Get_Level;

   A : Sizes (1 .. 2);
   L : Leveled;
   C : Natural;
begin
   Get_Sizes (A, C);
   Get_Level (L, C);
end Precision_Uninitialized_Output_Constant_Aggregate_Finding;
