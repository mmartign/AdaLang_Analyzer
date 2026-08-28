with Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Nested_Loop_Clean
  (N, M : Positive)
is
   F : Ada.Text_IO.File_Type;
begin
   for I in 1 .. N loop
      for J in 1 .. M loop
         Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
         Ada.Text_IO.Put_Line ("opened");
         Ada.Text_IO.Close (F);
      end loop;
   end loop;
end Precision_Unclosed_File_Handle_Nested_Loop_Clean;
