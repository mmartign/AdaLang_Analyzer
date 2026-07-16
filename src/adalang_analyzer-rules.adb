--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Rules is

   function Quality_Name (Quality : Software_Quality) return String is
   begin
      case Quality is
         when Quality_Security       => return "Security";
         when Quality_Reliability    => return "Reliability";
         when Quality_Maintainability => return "Maintainability";
      end case;
   end Quality_Name;

   function Severity_Name (Severity : Issue_Severity) return String is
   begin
      case Severity is
         when Severity_Blocker => return "Blocker";
         when Severity_High    => return "High";
         when Severity_Medium  => return "Medium";
         when Severity_Low     => return "Low";
      end case;
   end Severity_Name;

   function Lookup_Rule_Kind
     (Name : String; Found : out Boolean) return Rule_Kind
   is
      Normalized : constant String := Text_Utils.Normalize_Rule_Name (Name);
   begin
      for R in Rule_Kind loop
         if Text_Utils.Normalize_Rule_Name
              (To_String (Rule_Infos (R).Name)) =
            Normalized
         then
            Found := True;
            return R;
         end if;
      end loop;
      Found := False;
      return No_Goto;
   end Lookup_Rule_Kind;

end Adalang_Analyzer.Rules;
