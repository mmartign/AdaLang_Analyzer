with Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Finding is
   F : Ada.Text_IO.File_Type;
begin
   Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
   Ada.Text_IO.Put_Line ("opened");
end Precision_Unclosed_File_Handle_Finding;
