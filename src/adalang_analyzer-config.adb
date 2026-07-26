--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Text_IO;

package body Adalang_Analyzer.Config is

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
   begin
      if Verbose_Mode and then not Quiet_Mode then
         Ada.Text_IO.Put_Line ("adalang-analyzer [INFO]: " & Message);
      end if;
   end Log_Verbose;

end Adalang_Analyzer.Config;
