procedure Uninitialized_Output_Array_Loop_Range_Attribute_Early_Exit is

   type Triple is array (1 .. 3) of Integer;

   procedure Set_All (Arr : out Triple; Stop_Early : Boolean) is
   begin
      --  Same full-coverage iteration domain ("Arr'Range") as the clean
      --  sibling case, but an exit can leave the loop before every index
      --  is written. This must still be flagged: covering the whole index
      --  range only guarantees every index gets *visited*, not that the
      --  write is reached on every one of those visits.
      for I in Arr'Range loop
         if Stop_Early then
            exit;
         end if;
         Arr (I) := 0;
      end loop;
   end Set_All;

begin
   null;
end Uninitialized_Output_Array_Loop_Range_Attribute_Early_Exit;
