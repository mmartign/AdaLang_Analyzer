with Ada.Text_IO; use Ada.Text_IO;
procedure Precision_Unused_Parameter_Nested_Reference_Clean (X : Integer) is
   procedure Inner is
   begin
      Put_Line (Integer'Image (X));
   end Inner;
begin
   Inner;
end Precision_Unused_Parameter_Nested_Reference_Clean;
