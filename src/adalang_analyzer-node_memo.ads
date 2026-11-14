--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  The result of a question about a node, asked of Libadalang once. Many
--  checks ask what the same name refers to. For a name that does not
--  resolve, Libadalang raises and handles an exception each time it is
--  asked, and unwinding dominates a run when a unit's dependencies are
--  missing: most of the time of the performance smoke test on macOS.
--
--  The answers kept are those for nodes of one unit, the unit of the node
--  last asked about; the units of a run are never reparsed.
generic
   type Result_Type is private;
   with function Compute
     (Node : Libadalang.Analysis.Ada_Node) return Result_Type;
package Adalang_Analyzer.Node_Memo is

   function Get (Node : Libadalang.Analysis.Ada_Node) return Result_Type;

end Adalang_Analyzer.Node_Memo;
