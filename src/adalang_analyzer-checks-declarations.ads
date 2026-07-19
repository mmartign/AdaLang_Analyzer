--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Per-subprogram and per-declaration checks: unused parameters/variables,
--  complexity/nesting/parameter-count metrics, multiple returns, and
--  shadowed declarations. Private to the Checks subsystem.
private package Adalang_Analyzer.Checks.Declarations is

   procedure Begin_Traversal;
   --  Reset the lexical-scope cache before walking a compilation unit.

   procedure Enter_Node (Node : Libadalang.Analysis.Ada_Node'Class);
   procedure Leave_Node (Node : Libadalang.Analysis.Ada_Node'Class);
   --  Push/pop the scopes recognized by Shadowed_Declaration.

   procedure Register_Declaration
     (Node : Libadalang.Analysis.Ada_Node'Class);
   --  Add object and parameter names to the current lexical scope. Object
   --  declarations are registered after they have been checked, so a lookup
   --  only observes enclosing scopes rather than sibling declarations.

   procedure Analyze_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body);
   --  Runs the per-subprogram checks: Unused_Parameter and Unused_Variable
   --  (no reference in either the local declarations or the statements),
   --  Cyclomatic_Complexity (base 1 plus every decision point in the
   --  body), Too_Many_Parameters, Deep_Nesting, No_Multiple_Return, and
   --  (via Adalang_Analyzer.Flow_Interp) the flow-sensitive strengthening
   --  of Division_By_Zero and Constant_Condition.

   procedure Analyze_Object_Declaration
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Decl : Libadalang.Analysis.Object_Decl);
   --  Runs Shadowed_Declaration for each name introduced by Decl.

end Adalang_Analyzer.Checks.Declarations;
