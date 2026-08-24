with Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Guarded_Clean (To_File : Boolean) is
   F : Ada.Text_IO.File_Type;
begin
   if To_File then
      Ada.Text_IO.Create (F, Ada.Text_IO.Out_File, "output.txt");
   end if;

   Ada.Text_IO.Put_Line ("working");

   if To_File then
      Ada.Text_IO.Close (F);
   end if;
end Precision_Unclosed_File_Handle_Guarded_Clean;
