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

with Libadalang.Analysis;

with Adalang_Analyzer.Rules;

--  Central sink for every check: counts each violation and, unless quiet
--  mode is set, prints its location, message, rule metadata, and a source
--  excerpt with a caret under the offending span. Also owns the run's
--  violation counters, since they are incremented at exactly this choke
--  point.
package Adalang_Analyzer.Report is

   Maximum_Highlight_Width : constant Positive := 120;

   type Output_Format is (Text_Output, JSON_Output, SARIF_Output);

   Source_File_Count : Natural := 0;
   Violations        : Natural := 0;
   Baseline_Matches  : Natural := 0;
   Rule_Violations   : array (Rules.Rule_Kind) of Natural := (others => 0);
   Skipped_Nodes     : Natural := 0;

   procedure Set_Output
     (Format   : Output_Format;
      Filename : String := "");
   --  Selects the report representation and optional destination. An empty
   --  filename means standard output. Text output remains the default.

   procedure Set_Configuration_Files
     (Config_Path   : String;
      Baseline_Path : String);
   --  Records optional configuration and baseline inputs in structured
   --  evidence. Empty strings mean that the corresponding input was unused.

   procedure Record_Project_File (Filename : String);
   procedure Record_Scenario_Variable (Value : String);
   procedure Record_Analyzed_File (Filename : String);
   --  Records invocation context and the files that passed the basic
   --  existence/type checks and entered analysis.

   procedure Load_Baseline (Filename : String);
   --  Loads stable finding fingerprints, one per line. Matching findings are
   --  retained in the structured report as "baseline" findings but do not
   --  increment Violations or make the process fail.

   procedure Write_Baseline (Filename : String);
   --  Writes the fingerprints of every finding observed in this run. This is
   --  deliberately a small, diffable text format rather than a serialized
   --  implementation detail.

   procedure Write_Compliance_Report
     (Standard : String;
      Filename : String;
      Format   : Output_Format := Text_Output);
   --  Writes a non-normative, per-objective evidence report for Standard
   --  ("do178c" or "iso26262") to Filename, or to standard output when
   --  Filename is empty. Reports the enabled rules mapped to each
   --  objective, this run's open and baselined findings against them, and
   --  the inline-suppression rationale trail. Format selects the
   --  representation: Text_Output is the original Markdown report;
   --  JSON_Output is the same content as a machine-readable document for
   --  tooling that consumes the report programmatically. SARIF_Output is
   --  not supported here -- the CLI rejects it before this procedure is
   --  ever called, since SARIF's result-oriented schema has no natural slot
   --  for the objective/evidence structure this report is built around
   --  (see --format=sarif for a SARIF rendering of the underlying
   --  findings). This is verification-support evidence, not a compliance
   --  determination; see POSITIONING.md.

   procedure Finalize_Output;
   --  Emits JSON or SARIF output after all source files have been analyzed.
   --  Text diagnostics are emitted as findings arrive, so this is a no-op for
   --  the default format.

   function Selected_Output_Format return Output_Format;

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
      Message     : String;
      Explanation : String := "";
      Evidence    : String := "");
   --  Shared by Report_Rule_Violation (AST-node checks) and
   --  Report_Line_Violation (raw source-text checks that have no single
   --  Ada_Node to anchor a report on).

   procedure Report_Rule_Violation
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Rule    : Rules.Rule_Kind;
      Message : String;
      Explanation : String := "";
      Evidence    : String := "");
   --  AST-node violation report: derives the location and caret width from
   --  Node's source span. Explanation describes why the rule matched;
   --  Evidence records the concrete fact derived by the analysis. Both are
   --  optional so checks can adopt explainable diagnostics incrementally.

   procedure Report_Line_Violation
     (Filename    : String;
      Line_Number : Natural;
      Column      : Natural;
      Caret_Width : Natural;
      Rule        : Rules.Rule_Kind;
      Message     : String;
      Explanation : String := "";
      Evidence    : String := "");
   --  Raw source-text violation report, for checks (Long_Line,
   --  Trailing_Whitespace) that scan file text directly rather than the
   --  Libadalang AST.

end Adalang_Analyzer.Report;
