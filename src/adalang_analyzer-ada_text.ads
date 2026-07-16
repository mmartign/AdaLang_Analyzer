--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Libadalang-facing text helpers shared by the flow evaluator and the
--  checks: reading a node's verbatim source text, and canonicalizing it
--  for textual-equality comparisons (duplicate operands, repeated
--  conditions, identical branches, ...).
package Adalang_Analyzer.Ada_Text is

   function Node_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String;
   --  Verbatim source text spanned by Node, or "" for a null node.

   function Canonical_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String;
   --  Whitespace-stripped, lower-cased source text of Node, used to compare
   --  expressions for textual equality regardless of formatting or
   --  identifier casing. String literal contents and character literals
   --  are preserved verbatim so their case and spelling stay significant.

   function Terminates_Statement
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node unconditionally transfers control out of the
   --  statement list it's in (return, raise, goto, or an unconditional
   --  exit), making any following statement in the same list unreachable.
   --  Shared by Adalang_Analyzer.Checks (Unreachable_Code and friends) and
   --  Adalang_Analyzer.Flow_Interp (reachability in the flow interpreter).

end Adalang_Analyzer.Ada_Text;
