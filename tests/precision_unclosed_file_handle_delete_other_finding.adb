--  Unclosed_File_Handle: at the same shape, deleting another file leaves
--  the first one open, which must be reported (FP-180).

with Ada.Text_IO; use Ada.Text_IO;

procedure Precision_Unclosed_File_Handle_Delete_Other_Finding
  (Script, Log : String)
is
   F : File_Type;
   G : File_Type;
begin
   Open (F, In_File, Script);
   Open (G, In_File, Log);
   Delete (G);
end Precision_Unclosed_File_Handle_Delete_Other_Finding;
