with Ada.Direct_IO;
use Ada.Direct_IO;

procedure Precision_Unclosed_Direct_Io_Bare_Name_Finding is
   package Integer_Direct_IO is new Direct_IO (Integer);
   F : Integer_Direct_IO.File_Type;
begin
   Integer_Direct_IO.Create (F, Integer_Direct_IO.Out_File, "data.bin");
end Precision_Unclosed_Direct_Io_Bare_Name_Finding;
