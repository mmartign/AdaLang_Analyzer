--  3 levels of nested if-statements: below the default -nesting-threshold
--  (4), above the lowered threshold (2) that
--  tests/run_cli_parameter_effects.sh uses to prove -nesting-threshold is
--  actually threaded into Deep_Nesting.
procedure Cli_Nesting_Threshold is
begin
   if True then
      if True then
         if True then
            null;
         end if;
      end if;
   end if;
end Cli_Nesting_Threshold;
