--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Text_IO;

with Adalang_Analyzer.Config;

procedure Recoverable_Diagnostic_Test is

   procedure Trigger (Message : String) is
   begin
      raise Constraint_Error with Message;
   exception
      when E : others =>
         Adalang_Analyzer.Config.Report_Recoverable_Failure_Once
           (Rule       => "Test_Rule",
            Operation  => "exercise diagnostic",
            Source     => "test_input.adb",
            Occurrence => E);
   end Trigger;

begin
   Trigger ("deliberate recoverable failure");
   Trigger ("deliberate recoverable failure");
   Trigger ("deliberate recoverable failure (memoized)");
   Ada.Text_IO.Put_Line ("recoverable diagnostic test passed");
end Recoverable_Diagnostic_Test;
