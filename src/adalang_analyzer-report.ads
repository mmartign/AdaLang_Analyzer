--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

with Adalang_Analyzer.Rules;

--  Central sink for every check: counts each violation and, unless quiet
--  mode is set, prints its location, message, rule metadata, and a source
--  excerpt with a caret under the offending span. Also owns the run's
--  violation counters, since they are incremented at exactly this choke
--  point.
package Adalang_Analyzer.Report is

   Maximum_Highlight_Width : constant Positive := 120;

   Source_File_Count : Natural := 0;
   Violations        : Natural := 0;
   Rule_Violations   : array (Rules.Rule_Kind) of Natural := (others => 0);
   Skipped_Nodes     : Natural := 0;

   function Source_Line
     (Filename : String; Line_Number : Natural) return String;
   --  Re-reads Filename to fetch the text of one line for the violation
   --  report. Returns "" rather than raising if the file or line is
   --  unavailable, since the excerpt is a display convenience, not
   --  required for the violation itself to be valid.

   function Is_Suppressed
     (Source_Text : String; Rule_Name : String) return Boolean;
   --  True when the source line carrying a node contains an explicit,
   --  rule-specific suppression comment:
   --  "--  adalang-analyzer: ignore <Rule_Name>".

   function Is_Generated_Config_File (Filename : String) return Boolean;
   --  GNAT emits *_config.ads files containing implementation pragmas that
   --  describe the compilation environment. They are generated metadata,
   --  not application source, so No_Pragma does not report them.

   function Highlight_Width
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural;
   --  Length of the caret underline for Node: the node's on-line span, or
   --  a single caret when it crosses lines or has no width. Capped at
   --  Maximum_Highlight_Width so a large construct doesn't dominate the
   --  terminal output.

   procedure Report_Violation_At
     (Filename    : String;
      Line_Number : Natural;
      Column      : Natural;
      Caret_Width : Natural;
      Rule        : Rules.Rule_Kind;
      Message     : String);
   --  Shared by Report_Rule_Violation (AST-node checks) and
   --  Report_Line_Violation (raw source-text checks that have no single
   --  Ada_Node to anchor a report on).

   procedure Report_Rule_Violation
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Rule    : Rules.Rule_Kind;
      Message : String);
   --  AST-node violation report: derives the location and caret width from
   --  Node's source span.

   procedure Report_Line_Violation
     (Filename    : String;
      Line_Number : Natural;
      Column      : Natural;
      Caret_Width : Natural;
      Rule        : Rules.Rule_Kind;
      Message     : String);
   --  Raw source-text violation report, for checks (Long_Line,
   --  Trailing_Whitespace) that scan file text directly rather than the
   --  Libadalang AST.

end Adalang_Analyzer.Report;
