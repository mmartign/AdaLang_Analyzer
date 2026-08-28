with Ada.Sequential_IO;
with Ada.Text_IO;

procedure Precision_Unclosed_Sequential_Io_Clean is
   package Integer_Sequential_IO is new Ada.Sequential_IO (Integer);
   F : Integer_Sequential_IO.File_Type;
begin
   Integer_Sequential_IO.Open (F, Integer_Sequential_IO.In_File, "data.bin");
   Ada.Text_IO.Put_Line ("opened");
   Integer_Sequential_IO.Close (F);
exception
   when others =>
      if Integer_Sequential_IO.Is_Open (F) then
         Integer_Sequential_IO.Close (F);
      end if;
      raise;
end Precision_Unclosed_Sequential_Io_Clean;
