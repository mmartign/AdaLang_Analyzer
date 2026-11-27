--  At the shape of the loop-exit regression (FP-183): one pass of a loop
--  that writes an element of an array does not set the whole array. Must
--  fire.
procedure Precision_Uninitialized_Output_Loop_Element_Write_Finding is
   type Buffer is array (1 .. 4) of Integer;

   procedure Fill (B : out Buffer) is
      I : Positive := 1;
   begin
      loop
         B (I) := I;
         exit when I = 2;
         I := I + 1;
      end loop;
   end Fill;

   B : Buffer;
begin
   Fill (B);
end Precision_Uninitialized_Output_Loop_Element_Write_Finding;
