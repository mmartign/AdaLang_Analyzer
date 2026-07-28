--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded;

with Libadalang.Analysis;

--  Data model and per-run registry for verification obligations. Obligations
--  are deliberately separate from rule findings: a rule reports an observed
--  condition, while an obligation records the outcome of asking whether one
--  specific run-time or contract failure is absent.
--
--  This package does not itself perform analysis. Producers must supply an
--  explicit result status and the evidence supporting it; no default can
--  silently mean "proved." Text and JSON reporters expose the registry.
package Adalang_Analyzer.Proof_Obligations is

   use Ada.Strings.Unbounded;

   type Obligation_Kind is
     (Division_By_Zero_Check,
      Integer_Overflow_Check,
      Range_Check,
      Index_Check,
      Discriminant_Check,
      Initialization_Check,
      Assertion_Check,
      Precondition_Check,
      Postcondition_Check,
      Loop_Invariant_Initialization,
      Loop_Invariant_Preservation,
      Loop_Variant_Check);

   type Obligation_Status is
     (Proved_Safe,
      Definite_Error,
      Unproved,
      Unreachable,
      Unsupported);

   --  Method records how a result was obtained, not how strong it is.
   --  Result strength comes from Status together with the documented
   --  supported subset, assumptions, and evidence.
   type Analysis_Method is
     (No_Analysis,
      Static_Evaluation,
      Flow_Analysis,
      Abstract_Interpretation,
      Contract_Transfer,
      External_Prover);

   type Source_Position is record
      Filename : Unbounded_String;
      Line     : Natural := 0;
      Column   : Natural := 0;
   end record;

   No_Source_Position : constant Source_Position :=
     (Filename => Null_Unbounded_String, Line => 0, Column => 0);

   type Obligation is record
      --  Stable_Id is supplied by the producer because only it knows which
      --  source operation and configuration facts distinguish the obligation.
      --  The registry rejects empty and duplicate identifiers.
      Stable_Id : Unbounded_String;
      Kind      : Obligation_Kind;
      Location  : Source_Position := No_Source_Position;
      Status    : Obligation_Status;
      Method    : Analysis_Method;

      Operation          : Unbounded_String;
      Assumptions        : Unbounded_String;
      Abstract_State     : Unbounded_String;
      Explanation        : Unbounded_String;
      Imprecision_Source : Unbounded_String;
      Configuration_Id   : Unbounded_String;
   end record;

   function Create
     (Stable_Id          : String;
      Kind               : Obligation_Kind;
      Status             : Obligation_Status;
      Method             : Analysis_Method;
      Filename           : String := "";
      Line               : Natural := 0;
      Column             : Natural := 0;
      Operation          : String := "";
      Assumptions        : String := "";
      Abstract_State     : String := "";
      Explanation        : String := "";
      Imprecision_Source : String := "";
      Configuration_Id   : String := "") return Obligation;
   --  Constructs an obligation and rejects an empty Stable_Id.

   function Kind_Name (Kind : Obligation_Kind) return String;
   function Status_Name (Status : Obligation_Status) return String;
   function Method_Name (Method : Analysis_Method) return String;
   function Scope_Description return String;
   --  Stable lower-case, hyphenated names intended for structured output.

   function Stable_Id_For
     (Unit      : Libadalang.Analysis.Analysis_Unit;
      Node      : Libadalang.Analysis.Ada_Node'Class;
      Kind      : Obligation_Kind;
      Operation : String := "") return String;
   --  Derives a deterministic proof/v1 identifier from the normalized source
   --  path, source span, obligation kind, and operation text. It is stable
   --  for unchanged source but does not yet promise stability across line
   --  movement or expression rewriting.

   procedure Register_At
     (Unit               : Libadalang.Analysis.Analysis_Unit;
      Node               : Libadalang.Analysis.Ada_Node'Class;
      Kind               : Obligation_Kind;
      Status             : Obligation_Status;
      Method             : Analysis_Method;
      Operation          : String := "";
      Assumptions        : String := "";
      Abstract_State     : String := "";
      Explanation        : String := "";
      Imprecision_Source : String := "";
      Configuration_Id   : String := "");
   --  Creates and registers an obligation anchored at Node. Repeated
   --  registration of the same status is idempotent. When analysis passes
   --  overlap, the registry preserves the strongest sound outcome:
   --  reachable results supersede Unreachable, Definite_Error supersedes
   --  Unsupported, and Unsupported or Unreachable supersede Proved_Safe.

   procedure Reset;
   --  Removes all obligations from the per-run registry.

   procedure Register (Item : Obligation);
   --  Adds Item. Raises Constraint_Error when Stable_Id is empty or already
   --  registered, preventing ambiguous updates and report identities.

   function Count return Natural;

   function Count (Status : Obligation_Status) return Natural;

   function Find (Stable_Id : String) return Natural;
   --  The Positive registry index for Stable_Id, or 0 when it is absent.

   function Element (Index : Positive) return Obligation;
   --  Raises Constraint_Error when Index is not present.

   procedure Update_Result
     (Stable_Id          : String;
      Status             : Obligation_Status;
      Method             : Analysis_Method;
      Abstract_State     : String := "";
      Explanation        : String := "";
      Imprecision_Source : String := "");
   --  Replaces only result fields, preserving identity, kind, source context,
   --  operation, assumptions, and configuration. Raises Constraint_Error
   --  when Stable_Id is absent.

end Adalang_Analyzer.Proof_Obligations;
