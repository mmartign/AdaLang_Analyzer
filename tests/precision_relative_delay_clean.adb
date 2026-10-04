with Ada.Calendar;

procedure Precision_Relative_Delay_Clean is
   use type Ada.Calendar.Time;
   Next : constant Ada.Calendar.Time := Ada.Calendar.Clock + 1.0;
begin
   delay until Next;
end Precision_Relative_Delay_Clean;
