--  AdaLang Analyzer
--
--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--
--  Derived from AdaCore's libadalang-tools and substantially extended,
--  integrated, validated, and maintained by Spazio IT as part of the
--  independent AdaLang Analyzer project.
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
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

   procedure Report_Recoverable_Failure_Once
     (Rule       : String;
      Operation  : String;
      Source     : String;
      Occurrence : Ada.Exceptions.Exception_Occurrence)
   is
      Detail : constant String :=
        Ada.Exceptions.Exception_Name (Occurrence)
        & (if Ada.Exceptions.Exception_Message (Occurrence)'Length = 0
           then ""
           else ": " & Ada.Exceptions.Exception_Message (Occurrence));
      Message : constant String :=
        "adalang-analyzer: warning: recoverable analysis failure; rule="
        & Rule & "; operation=" & Operation & "; source="
        & (if Source'Length = 0 then "<unknown>" else Source)
        & "; fallback=conservative; exception=" & Detail;
      Canonical : constant String := Canonical_Diagnostic (Message);
   begin
      if not Reported_Diagnostics.Contains (Canonical) then
         Reported_Diagnostics.Include (Canonical);
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error, Canonical);
      end if;
   end Report_Recoverable_Failure_Once;

end Adalang_Analyzer.Config;
