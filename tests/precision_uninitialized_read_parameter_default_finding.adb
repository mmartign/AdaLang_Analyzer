--  Uninitialized_Read: at the same imported subprogram, a call that leaves
--  the formal out before Style is set reads Style with no value, which
--  must be reported at the call (FP-179).

procedure Precision_Uninitialized_Read_Parameter_Default_Finding
  (Styles : Integer; Code : out Integer)
is
   Style : Integer;

   procedure Notify (Value : Integer := Style; Other : Integer := 0);
   pragma Import (C, Notify, "notify");
begin
   Notify (Other => 1);
   Style := Styles;
   Code := Style;
end Precision_Uninitialized_Read_Parameter_Default_Finding;
