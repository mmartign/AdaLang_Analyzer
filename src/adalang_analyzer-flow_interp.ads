--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Libadalang.Analysis;

--  Flow-sensitive constant propagation (best effort): a second, stateful
--  walk over one subprogram body, run alongside the ordinary node-local
--  checks in Adalang_Analyzer.Checks, that lets Division_By_Zero,
--  Constant_Condition, and assertion checking see values learned from an
--  earlier assignment, not
--  just literals. Built on the Adalang_Analyzer.Flow_Domain state and the
--  Adalang_Analyzer.Flow_Eval evaluator. Everything below
--  Interpret_Subprogram_Flow (the statement/if/case/loop interpreter,
--  havocking, declaration seeding, ...) is a private implementation
--  detail of this one entry point.
package Adalang_Analyzer.Flow_Interp is

   procedure Interpret_Subprogram_Flow
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body);
   --  Runs the flow-sensitive pass over Subprogram's body when a
   --  flow-sensitive or contract-aware rule is enabled: seeds a
   --  Flow_State from its declarations' initializers, then walks its
   --  statements, reporting through Adalang_Analyzer.Report. A no-op when
   --  neither check is enabled, or when the body has exception handlers
   --  (a raise partway through would jump to the handler with only a
   --  prefix of the assignments applied, which this straight-line model
   --  doesn't account for). SPARK Pre contracts narrow the entry state,
   --  Post contracts are scanned in the exit state, and calls invalidate
   --  writable state named by their Global contracts. Resolved calls map
   --  actual values to formals for known precondition failures and transfer
   --  simple postcondition facts back to writable actuals.

end Adalang_Analyzer.Flow_Interp;
