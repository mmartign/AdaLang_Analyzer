with Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Clean is
   F : Ada.Text_IO.File_Type;
begin
   Ada.Text_IO.Open (F, Ada.Text_IO.In_File, "input.txt");
   Ada.Text_IO.Put_Line ("opened");
   Ada.Text_IO.Close (F);
exception
   when others =>
      if Ada.Text_IO.Is_Open (F) then
         Ada.Text_IO.Close (F);
      end if;
      raise;
end Precision_Unclosed_File_Handle_Clean;
