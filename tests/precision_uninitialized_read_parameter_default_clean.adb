--  Uninitialized_Read: the default expression of a formal is evaluated
--  where a call leaves the formal out, not where the subprogram is
--  declared. GWindows declares an imported CreateWindowEx with "dwStyle :
--  Interfaces.C.unsigned := Style" before Style is set, and calls it
--  after; a pragma that names it there calls nothing (FP-179).

procedure Precision_Uninitialized_Read_Parameter_Default_Clean
  (Styles : Integer; Code : out Integer)
is
   Style   : Integer;
   ExStyle : Integer := 0;

   function Create_Window
     (Ex_Style : Integer := ExStyle;
      Style_In : Integer := Style;
      Parent   : Integer) return Integer;
   pragma Import (C, Create_Window, "create_window");

   procedure Notify (Value : Integer := Style);
   pragma Import (C, Notify, "notify");
   pragma Machine_Attribute (Notify, "ms_abi");
begin
   if Styles > 0 then
      Style := Styles;
   else
      Style := 1;
   end if;
   Code := Create_Window (Parent => 0);
   Notify;
end Precision_Uninitialized_Read_Parameter_Default_Clean;
