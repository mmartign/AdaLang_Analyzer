with Ada.Direct_IO;
with Ada.Text_IO;

procedure Precision_Unclosed_Direct_Io_Finding is
   package Integer_Direct_IO is new Ada.Direct_IO (Integer);
   F : Integer_Direct_IO.File_Type;
begin
   Integer_Direct_IO.Open (F, Integer_Direct_IO.In_File, "data.bin");
   Ada.Text_IO.Put_Line ("opened");
end Precision_Unclosed_Direct_Io_Finding;
