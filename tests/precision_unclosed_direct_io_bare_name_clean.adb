with Ada.Direct_IO;
use Ada.Direct_IO;

procedure Precision_Unclosed_Direct_Io_Bare_Name_Clean is
   package Integer_Direct_IO is new Direct_IO (Integer);
   F : Integer_Direct_IO.File_Type;
begin
   Integer_Direct_IO.Create (F, Integer_Direct_IO.Out_File, "data.bin");
   Integer_Direct_IO.Close (F);
exception
   when others =>
      if Integer_Direct_IO.Is_Open (F) then
         Integer_Direct_IO.Close (F);
      end if;
      raise;
end Precision_Unclosed_Direct_Io_Bare_Name_Clean;
