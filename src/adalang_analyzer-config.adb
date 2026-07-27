--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Strings.Hash;
with Ada.Text_IO;

package body Adalang_Analyzer.Config is

   package Diagnostic_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   Reported_Diagnostics : Diagnostic_Sets.Set;

   function Canonical_Diagnostic (Message : String) return String is
      Memoized_Suffix : constant String := " (memoized)";
   begin
      if Message'Length >= Memoized_Suffix'Length
        and then Message
          (Message'Last - Memoized_Suffix'Length + 1 .. Message'Last) =
            Memoized_Suffix
      then
         return
           (if Message'Length = Memoized_Suffix'Length
            then ""
            else Canonical_Diagnostic
              (Message
                 (Message'First ..
                    Message'Last - Memoized_Suffix'Length)));
      end if;
      return Message;
   end Canonical_Diagnostic;

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

   procedure Log_Verbose_Once (Message : String) is
      Canonical : constant String := Canonical_Diagnostic (Message);
   begin
      if not Reported_Diagnostics.Contains (Canonical) then
         Reported_Diagnostics.Include (Canonical);
         Log_Verbose (Canonical);
      end if;
   end Log_Verbose_Once;

end Adalang_Analyzer.Config;
