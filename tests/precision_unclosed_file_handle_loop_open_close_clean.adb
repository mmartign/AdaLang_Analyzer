with Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Loop_Open_Close_Clean
  (N : Positive)
is
   F : Ada.Text_IO.File_Type;
begin
   for I in 1 .. N loop
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
      Ada.Text_IO.Put_Line ("opened");
      Ada.Text_IO.Close (F);
   end loop;
end Precision_Unclosed_File_Handle_Loop_Open_Close_Clean;
