procedure Uninitialized_Output_Array_Loop_Partial_Range is

   type Triple is array (1 .. 3) of Integer;

   procedure Set_Partial (Arr : out Triple) is
   begin
      --  The loop only visits 2 of Arr's 3 indices, so Arr (3) is never
      --  written. This must still be flagged: Same_Parameter's coarse
      --  whole-object treatment of "Arr (I) := ..." must not be mistaken
      --  for full coverage just because the range is statically
      --  non-empty and escape-free.
      for I in 1 .. 2 loop
         Arr (I) := 0;
      end loop;
   end Set_Partial;

begin
   null;
end Uninitialized_Output_Array_Loop_Partial_Range;
