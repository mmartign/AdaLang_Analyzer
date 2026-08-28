with Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Loop_Static_Nonempty_Clean is
   F : Ada.Text_IO.File_Type;
begin
   Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
   for I in 1 .. 10 loop
      Ada.Text_IO.Put_Line ("working");
      Ada.Text_IO.Close (F);
   end loop;
end Precision_Unclosed_File_Handle_Loop_Static_Nonempty_Clean;
