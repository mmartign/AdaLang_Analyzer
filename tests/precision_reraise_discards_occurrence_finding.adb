with Ada.Text_IO; use Ada.Text_IO;
procedure Precision_Reraise_Discards_Occurrence_Finding is
   Bad_Input : exception;
begin
   raise Bad_Input;
exception
   when Bad_Input =>
      Put_Line ("logging");
      raise Bad_Input;
end Precision_Reraise_Discards_Occurrence_Finding;
