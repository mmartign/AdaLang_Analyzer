--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Adalang_Analyzer.Rules;

--  Non-normative objective mapping consumed by
--  Adalang_Analyzer.Report.Write_Compliance_Report. Every rule cited here is
--  drawn from Adalang_Analyzer.Rules.DO_178C_Core_Rules,
--  DO_178C_Level_C_Rules, DO_178C_Level_AB_Rules, or Automotive_Rules -- the
--  same lists Adalang_Analyzer.CLI's Enable_DO_178C_Preset and
--  Enable_Automotive_Preset use to enable checks -- so the compliance
--  report can never claim relevance for a rule the corresponding profile
--  does not actually enable.
--
--  DO-178C objective identifiers and descriptions are AdaLang's own
--  paraphrase of publicly discussed DO-178C Annex A Table A-5 (reviews and
--  analyses of source code) activity categories. ISO 26262 objective
--  identifiers are AdaLang's own thematic grouping of the --automotive
--  preset, in the same non-normative style already used by
--  AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md's "Coverage summary" section --
--  general safety-relevant themes (restricted control flow, storage and
--  aliasing discipline, and so on), not a reference to any ISO 26262 Part,
--  clause, or table number. Neither is a reproduction of the respective
--  standard's normative text, and neither carries that standard's official
--  numbering. See POSITIONING.md's "approved claim vocabulary" for the
--  claims this project may and may not make.
package Adalang_Analyzer.Compliance_Mapping is

   type Standard_Kind is (DO_178C, ISO_26262);

   function Standard_Name (Standard : Standard_Kind) return String;

   function Lookup_Standard
     (Name : String; Found : out Boolean) return Standard_Kind;
   --  Resolves a --compliance-report value (case-insensitive) to a
   --  Standard_Kind. Found is False (with an arbitrary result) when Name
   --  does not name a currently supported standard.

   type Objective is record
      Id           : Unbounded_String;
      Description  : Unbounded_String;
      Mapped_Rules : access constant Rules.Rule_List;
      Manual_Note  : Unbounded_String;
   end record;

   type Objective_Array is array (Positive range <>) of Objective;

   function DO_178C_Objectives return Objective_Array;

   function ISO_26262_Objectives return Objective_Array;

   --  Verification activities DO-178C requires that this analyzer does not
   --  automate at all, carried over near-verbatim from README.md's DO-178C
   --  section and POSITIONING.md so the report never implies coverage this
   --  tool does not have.
   type Unsupported_Item is record
      Name : Unbounded_String;
      Note : Unbounded_String;
   end record;

   type Unsupported_Array is array (Positive range <>) of Unsupported_Item;

   function DO_178C_Unsupported return Unsupported_Array;

   function ISO_26262_Unsupported return Unsupported_Array;

end Adalang_Analyzer.Compliance_Mapping;
