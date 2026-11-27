--  At the shape of the conditional-write regression (FP-187): every path
--  writes the in out parameter, which is never read: mode out says it.
--  Must fire.
procedure Precision_Wrong_Parameter_Mode_Every_Path_Write_Finding is
   procedure Check (V : Natural; Override : in out Boolean) is
   begin
      if V = 0 then
         Override := True;
      else
         Override := False;
      end if;
   end Check;

   O : Boolean := False;
begin
   Check (0, O);
end Precision_Wrong_Parameter_Mode_Every_Path_Write_Finding;
