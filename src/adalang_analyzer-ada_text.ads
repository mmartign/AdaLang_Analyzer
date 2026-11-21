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

--  Libadalang-facing text helpers shared by the flow evaluator and the
--  checks: reading a node's verbatim source text, and canonicalizing it
--  for textual-equality comparisons (duplicate operands, repeated
--  conditions, identical branches, ...).
package Adalang_Analyzer.Ada_Text is

   function Node_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String;
   --  Verbatim source text spanned by Node, or "" for a null node.

   function Safe_Filename
     (Unit : Libadalang.Analysis.Analysis_Unit) return String;
   --  Unit filename for diagnostics, or "<unknown>" if Libadalang cannot
   --  provide one while another semantic failure is already being handled.

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

   function Is_Attribute_Out_Argument
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node is the argument an attribute call stores into: the
   --  item of "T'Read (Stream, Item)" (RM 13.13.2) or the object of
   --  "T'Asm_Output (Constraint, Object)" (System.Machine_Code). The
   --  arguments are those of the attribute reference, or of a call whose
   --  name it is. Such an argument is written, not read.

   function Is_Escaping_Attribute_Prefix
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node is the prefix of X'Access, X'Unchecked_Access,
   --  X'Unrestricted_Access or X'Address: the object can be written
   --  through the value the attribute gives, wherever it goes.

   function Is_False_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when Node is the literal False ("False", "Standard.False", in
   --  parentheses or not).

   function Follows_A_Call
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;
   --  True when a statement before Node in its statement list, or before
   --  the statement holding it in an enclosing list of the same body,
   --  makes a call: Node is reached only if that call returns. What it
   --  cannot tell counts as a call.

end Adalang_Analyzer.Ada_Text;
