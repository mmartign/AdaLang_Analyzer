with Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Loop_With_Exit_Clean
  (Done : Boolean)
is
   F          : Ada.Text_IO.File_Type;
   Local_Done : Boolean := Done;
begin
   loop
      Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
      Ada.Text_IO.Put_Line ("opened");
      Ada.Text_IO.Close (F);
      exit when Local_Done;
      Local_Done := True;
   end loop;
end Precision_Unclosed_File_Handle_Loop_With_Exit_Clean;
