--  Triggers both Too_Many_Parameters and Deep_Nesting at once (with lowered
--  thresholds), so tests/run_cli_parameter_effects.sh can prove that -R/+R
--  toggle each check independently rather than as an all-or-nothing group.
procedure Cli_Switch_Toggle (A, B, C, D : Integer) is
begin
   if A > 0 then
      if B > 0 then
         if C > 0 then
            null;
         end if;
      end if;
   end if;
end Cli_Switch_Toggle;
