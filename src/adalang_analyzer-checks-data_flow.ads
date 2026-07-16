--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Declaration-reference tracking: resolving what an identifier refers to,
--  whether a subtree reads or writes a given declaration, and locating the
--  enclosing subprogram of a node. Shared by Adalang_Analyzer.Checks
--  (No_Recursion) and Adalang_Analyzer.Checks.Control_Flow (Dead_Store,
--  Overwritten_Assignment, Function_Side_Effect). Private to the Checks
--  subsystem: nothing outside it should need these.
private package Adalang_Analyzer.Checks.Data_Flow is

   function Referenced_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl;
   --  The declaration an identifier resolves to via Libadalang's semantic
   --  analysis, or No_Basic_Decl for anything else or when resolution
   --  fails (e.g. on source with unresolved references).

   function Reads_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class;
      Decl : Libadalang.Analysis.Basic_Decl) return Boolean;
   --  True when Node contains a read of Decl, as opposed to only a write.
   --  A plain assignment's simple identifier destination doesn't count as
   --  a read; everything else that mentions Decl does. Drives
   --  Overwritten_Assignment's "was the earlier value read first" check.

   function Assigned_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl;
   --  The declaration written by an assignment statement whose destination
   --  is a plain identifier, or No_Basic_Decl for anything else (Node
   --  isn't an assignment, or its destination is a more complex form like
   --  an array/record component).

   function Has_Read_After
     (Node       : Libadalang.Analysis.Ada_Node'Class;
      Decl       : Libadalang.Analysis.Basic_Decl;
      Assignment : Libadalang.Analysis.Assign_Stmt) return Boolean;
   --  True when some read of Decl occurs at or after Assignment's source
   --  position within Node's subtree, in source (textual) order. This is
   --  the Dead_Store check: an assignment whose value is never read again
   --  in the subprogram is very likely dead code.

   function Enclosing_Subprogram
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Subp_Body;
   --  Walks up from Node to the nearest enclosing subprogram body, or
   --  No_Subp_Body if Node isn't inside one.

   function Is_Direct_Recursive_Call
     (Call       : Libadalang.Analysis.Call_Expr;
      Subprogram : Libadalang.Analysis.Subp_Body) return Boolean;
   --  True when Call's callee resolves to Subprogram itself, i.e. Call is a
   --  direct recursive call. Backs No_Recursion. Scoped to calls written
   --  with an explicit call syntax (Call_Expr); a parameterless procedure
   --  or function call written as a bare name is not recognized, keeping
   --  detection conservative rather than risking a false positive from
   --  misclassifying an ordinary name reference as a call.

end Adalang_Analyzer.Checks.Data_Flow;
