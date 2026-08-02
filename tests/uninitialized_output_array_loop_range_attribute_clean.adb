procedure Uninitialized_Output_Array_Loop_Range_Attribute_Clean is

   type Triple is array (1 .. 3) of Integer;

   procedure Set_All (Arr : out Triple) is
   begin
      --  "for I in Arr'Range loop" covers Arr's full index range by
      --  definition, independent of what its bounds actually are.
      for I in Arr'Range loop
         Arr (I) := 0;
      end loop;
   end Set_All;

begin
   null;
end Uninitialized_Output_Array_Loop_Range_Attribute_Clean;
