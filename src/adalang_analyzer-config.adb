--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded;
with Ada.Text_IO;

package body Adalang_Analyzer.Config is

   Previous_Verbose_Line : Ada.Strings.Unbounded.Unbounded_String;
   Have_Previous_Line    : Boolean := False;

   function Assurance_Profile_Name return String is
   begin
      case Active_Assurance_Profile is
         when No_Assurance_Profile => return "none";
         when DO_178C_Level_A      => return "DO-178C Level A support";
         when DO_178C_Level_B      => return "DO-178C Level B support";
         when DO_178C_Level_C      => return "DO-178C Level C support";
         when DO_178C_Level_D      => return "DO-178C Level D support";
      end case;
   end Assurance_Profile_Name;

   function Structural_Coverage_Objective return String is
   begin
      case Active_Assurance_Profile is
         when DO_178C_Level_A =>
            return "MC/DC";
         when DO_178C_Level_B =>
            return "decision";
         when DO_178C_Level_C =>
            return "statement";
         when No_Assurance_Profile | DO_178C_Level_D =>
            return "none";
      end case;
   end Structural_Coverage_Objective;

   procedure Log_Verbose (Message : String) is
      Line : constant String := "adalang-analyzer [INFO]: " & Message;
   begin
      if Verbose_Mode
        and then not Quiet_Mode
        and then
          (not Have_Previous_Line
           or else Line /=
             Ada.Strings.Unbounded.To_String (Previous_Verbose_Line))
      then
         Ada.Text_IO.Put_Line (Line);
         Previous_Verbose_Line :=
           Ada.Strings.Unbounded.To_Unbounded_String (Line);
         Have_Previous_Line := True;
      end if;
   end Log_Verbose;

end Adalang_Analyzer.Config;
