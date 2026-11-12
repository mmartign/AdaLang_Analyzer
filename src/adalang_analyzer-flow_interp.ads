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

with Adalang_Analyzer.Project_Files;

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
   --  writable state named by complete body summaries or Global contracts.
   --  Complete summaries also preserve unaffected bindings and recognize
   --  simple out-formal initialization on every normal return. Resolved calls
   --  map actual values to formals for known precondition failures and
   --  transfer simple postcondition facts back to writable actuals.

   procedure Verify_Unit
     (Unit : Libadalang.Analysis.Analysis_Unit);
   --  Runs the bounded CFG worklist verifier for every subprogram body in
   --  Unit. A no-op unless Config.Verification_Mode is enabled. This pass is
   --  intentionally run after ordinary AST checks so it can refine their
   --  Unproved obligation records to guarded final outcomes.

   function Imported_Generics
     (Ctx   : Libadalang.Analysis.Analysis_Context;
      Files : Adalang_Analyzer.Project_Files.File_Name_Vectors.Vector)
      return Adalang_Analyzer.Project_Files.File_Name_Vectors.Vector;
   --  The files (declaration and body) of the generic units of imported
   --  projects that SPARK code of Files instantiates, directly or through
   --  another of them, unless the generic unit says SPARK_Mode Off. The
   --  proof obligations of their instances are part of the run, as they
   --  are for GNATprove, but nothing in them is reported. Empty unless
   --  verifying.

   procedure Verify_Instances
     (Ctx   : Libadalang.Analysis.Analysis_Context;
      Files : Adalang_Analyzer.Project_Files.File_Name_Vectors.Vector);
   --  Run once Verify_Unit has run for every unit of Files. Analyses each
   --  generic unit once more for each instance of it in those units, its
   --  formal objects having the values of the actuals of the instance (see
   --  Flow_Eval.Bind_Formal_Object) and its formal subprograms the
   --  subprograms given to them, and takes an obligation of the unit that
   --  the first analysis left unproved as proved when it is proved for every
   --  instance. A generic unit that is also instantiated inside a generic
   --  unit, or nowhere, is left as it is. A no-op unless
   --  Config.Verification_Mode is enabled.

end Adalang_Analyzer.Flow_Interp;
