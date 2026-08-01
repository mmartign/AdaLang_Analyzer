procedure Uninitialized_Output_Composite_Clean is
   type Pair is record
      A, B : Integer;
   end record;

   type Triple is array (1 .. 3) of Integer;

   procedure Set_Pair (Rec : out Pair) is
   begin
      --  Every field is written directly, by name. Nothing here tracks
      --  per-field coverage, but a direct write to each named field must
      --  still count as writing the whole out parameter.
      Rec.A := 0;
      Rec.B := 0;
   end Set_Pair;

   procedure Set_Triple (Arr : out Triple) is
   begin
      --  Each element is written by its own literal index (not a loop,
      --  which this analysis does not attempt to prove covers every
      --  index). A direct indexed write must still count as writing the
      --  whole out parameter.
      Arr (1) := 0;
      Arr (2) := 0;
      Arr (3) := 0;
   end Set_Triple;

begin
   null;
end Uninitialized_Output_Composite_Clean;
