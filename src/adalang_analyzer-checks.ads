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

--  The rule engine: the single recursive AST walk that drives the whole
--  analysis. For each node it runs the checks keyed on that node's own
--  kind and recurses into every child, so every check runs in one pass
--  over the tree rather than one pass per check. Evaluate_Node is the
--  only entry point Adalang_Analyzer.CLI needs; everything else --
--  the node-kind dispatcher and the always-run structural checks -- is
--  private to this package's body, which delegates the bulk of the
--  per-construct logic to its private children: Checks.Data_Flow
--  (declaration-reference tracking), Checks.Declarations (per-subprogram
--  and per-declaration checks), Checks.Expressions (binary/unary operator
--  checks), and Checks.Control_Flow (statement, assignment, case, loop,
--  if/elsif/else, and exception-handler checks).
package Adalang_Analyzer.Checks is

   procedure Evaluate_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class);
   --  Runs every enabled check against Node and recurses into its
   --  children. A semantic property query inside a single node's checks
   --  (name resolution, expression typing, ...) that raises Property_Error
   --  is confined to that node: it is counted in
   --  Adalang_Analyzer.Report.Skipped_Nodes rather than aborting analysis
   --  of the rest of the file.

private

   function Is_Ada_Unchecked_Deallocation
     (Name : Libadalang.Analysis.Name'Class) return Boolean;
   --  True when Name denotes Ada.Unchecked_Deallocation, either by its
   --  fully qualified spelling or, for an unqualified
   --  "Unchecked_Deallocation", by resolving the name and checking its
   --  fully qualified declaration. Declared here (rather than only in the
   --  body) so Checks.Control_Flow's Use_After_Free implementation can
   --  reuse the same resolution to recognize a call to the user-named
   --  procedure a Generic_Subp_Instantiation of it introduces.

end Adalang_Analyzer.Checks;
