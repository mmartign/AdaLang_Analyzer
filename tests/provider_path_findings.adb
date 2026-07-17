package body Provider_Path_Findings is
   procedure Run is
      Left  : Float := 1.5;
      Right : Float := 2.5;
      Value : Integer := 0;
   begin
      Value := Value;
      Value := 1;
      Value := 2;

      if Left = Right then
         Value := Value + 1;
      end if;
   end Run;
end Provider_Path_Findings;
