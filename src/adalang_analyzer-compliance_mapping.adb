--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;

package body Adalang_Analyzer.Compliance_Mapping is

   use type Rules.Rule_List;

   function Standard_Name (Standard : Standard_Kind) return String is
   begin
      case Standard is
         when DO_178C =>
            return "DO-178C";
         when ISO_26262 =>
            return "ISO 26262";
      end case;
   end Standard_Name;

   function Lookup_Standard
     (Name : String; Found : out Boolean) return Standard_Kind
   is
      Lower : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      if Lower = "do178c" then
         Found := True;
         return DO_178C;
      elsif Lower = "iso26262" then
         Found := True;
         return ISO_26262;
      end if;

      Found := False;
      return DO_178C;
   end Lookup_Standard;

   --  Every element below is a Rules.Rule_Kind that Adalang_Analyzer.CLI's
   --  Enable_DO_178C_Preset actually enables under some level, drawn from
   --  Rules.DO_178C_Core_Rules, Rules.DO_178C_Level_C_Rules, or
   --  Rules.DO_178C_Level_AB_Rules. An objective grouping is a different cut
   --  of the same rules than the level grouping, not a separate claim of
   --  DO-178C relevance.

   Traceability_Rules : aliased constant Rules.Rule_List :=
     (Rules.Missing_Requirement_Trace, Rules.Malformed_Requirement_Trace);

   Deviation_Control_Rules : aliased constant Rules.Rule_List :=
     (1 => Rules.Suppression_Without_Rationale);

   --  Rules.DO_178C_Core_Rules in full, plus the data-flow subset of
   --  Rules.DO_178C_Level_C_Rules (that list's two trace rules are already
   --  covered above, under Traceability).
   Accuracy_And_Consistency_Rules : aliased constant Rules.Rule_List :=
     Rules.DO_178C_Core_Rules &
     (Rules.Dead_Store, Rules.Overwritten_Assignment,
      Rules.Uninitialized_Output, Rules.Global_Contract_Mismatch,
      Rules.Incomplete_Depends_Contract, Rules.Depends_Contract_Mismatch,
      Rules.Function_Side_Effect, Rules.No_Recursion,
      Rules.Non_Short_Circuit_Condition);

   Verifiability_Rules : aliased constant Rules.Rule_List :=
     (Rules.No_Recursion, Rules.No_Dispatching_Call,
      Rules.Potentially_Blocking_Operation);

   function DO_178C_Objectives return Objective_Array is
     ((Id          => To_Unbounded_String ("Traceability"),
       Description => To_Unbounded_String
         ("Source code is traceable to a low-level requirement."),
       Mapped_Rules => Traceability_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Requirement identifiers only, not a requirements database; " &
          "project-wide bidirectional traceability remains external.")),
      (Id          => To_Unbounded_String ("Standards conformance"),
       Description => To_Unbounded_String
         ("Source code conforms to the project's DO-178C Level A/B " &
          "coding restrictions."),
       Mapped_Rules => Rules.DO_178C_Level_AB_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Only exercised when a --do178c level enabling these " &
          "restrictions (A or B) was selected for this run.")),
      (Id          => To_Unbounded_String ("Accuracy and consistency"),
       Description => To_Unbounded_String
         ("Source code is free of the classes of run-time and data-flow " &
          "defect this analyzer can detect."),
       Mapped_Rules => Accuracy_And_Consistency_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Bounded and intraprocedural; see ASSURANCE_MODEL.md for what " &
          "a clean result does and does not establish.")),
      (Id          => To_Unbounded_String ("Verifiability"),
       Description => To_Unbounded_String
         ("Source code avoids constructs that impede review, analysis, " &
          "or proof."),
       Mapped_Rules => Verifiability_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Does not prove termination, WCET, or stack bounds.")),
      (Id          => To_Unbounded_String ("Deviation control"),
       Description => To_Unbounded_String
         ("Every inline analyzer suppression carries a reviewable " &
          "rationale."),
       Mapped_Rules => Deviation_Control_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Covers inline suppressions only; baseline-matched findings " &
          "carry no rationale (see the suppression trail below).")));

   function DO_178C_Unsupported return Unsupported_Array is
     ((Name => To_Unbounded_String ("Structural coverage"),
       Note => To_Unbounded_String
         ("Not measured. Use a target-aware coverage workflow such as " &
          "GNATcoverage; the recorded coverage objective (MC/DC, " &
          "decision, or statement) follows the selected --do178c level.")),
      (Name => To_Unbounded_String ("Requirements-based testing"),
       Note => To_Unbounded_String
         ("Not performed. AdaLang neither generates nor executes tests.")),
      (Name => To_Unbounded_String ("Object code verification"),
       Note => To_Unbounded_String
         ("Not performed. Source-level analysis only; compiler output is " &
          "not examined.")),
      (Name => To_Unbounded_String ("Tool qualification"),
       Note => To_Unbounded_String
         ("Not supplied. Projects taking certification credit from " &
          "analyzer results must separately assess tool qualification " &
          "under DO-330.")));

   --  Every element below is a Rules.Rule_Kind that Adalang_Analyzer.CLI's
   --  Enable_Automotive_Preset actually enables, drawn from
   --  Rules.Automotive_Rules. These ten thematic categories are AdaLang's
   --  own grouping of that list, extending
   --  AUTOMOTIVE_ADA_COMPLIANCE_MATRIX.md's existing "Coverage summary"
   --  prose into a strict one-rule-one-category partition. They cite no
   --  ISO 26262 Part, clause, or table number.

   Restricted_Control_Flow_Rules : aliased constant Rules.Rule_List :=
     (Rules.No_Goto, Rules.No_Abort, Rules.No_Raise,
      Rules.No_Access_To_Subp_Def, Rules.No_Recursion,
      Rules.Non_Short_Circuit_Condition, Rules.No_Tasking,
      Rules.No_Rendezvous, Rules.No_Select, Rules.No_Requeue,
      Rules.No_Asynchronous_Transfer, Rules.No_Dispatching_Call,
      Rules.No_Classwide_Type);

   Storage_And_Aliasing_Rules : aliased constant Rules.Rule_List :=
     (Rules.No_Unchecked_Conversion, Rules.No_Dynamic_Allocation,
      Rules.Restricted_Access_Type, Rules.No_Explicit_Dereference,
      Rules.No_Unchecked_Deallocation, Rules.Aliasing_Between_Parameters,
      Rules.No_Controlled_Type);

   Iso_Initialization_And_Data_Flow_Rules : aliased constant Rules.Rule_List :=
     (Rules.Complete_Initialization, Rules.Uninitialized_Read,
      Rules.Uninitialized_Output, Rules.Dead_Store,
      Rules.Overwritten_Assignment, Rules.Shadowed_Declaration,
      Rules.Function_Side_Effect);

   Scalar_Run_Time_Error_Rules : aliased constant Rules.Rule_List :=
     (Rules.Floating_Equality, Rules.Division_By_Zero, Rules.Reversed_Range,
      Rules.Self_Assignment, Rules.Contradictory_Condition,
      Rules.Known_Precondition_Failure, Rules.Known_Postcondition_Failure,
      Rules.Known_Assertion_Failure, Rules.Known_Range_Check_Failure,
      Rules.Known_Index_Check_Failure, Rules.Known_Overflow_Failure,
      Rules.Known_Discriminant_Check_Failure);

   Control_Flow_Correctness_Rules : aliased constant Rules.Rule_List :=
     (Rules.Infinite_Loop, Rules.Constant_Condition, Rules.Unreachable_Code,
      Rules.Unreachable_Branch, Rules.Unreachable_Case_Alternative,
      Rules.Overlapping_Case_Ranges, Rules.Missing_Loop_Variant);

   Exception_Concurrency_Elaboration_Rules : aliased constant Rules.Rule_List
     := (Rules.Exception_Swallowed, Rules.Exception_Propagation,
         Rules.Potentially_Blocking_Operation,
         Rules.Library_Level_Initialization);

   Iso_SPARK_Contract_Rules : aliased constant Rules.Rule_List :=
     (Rules.SPARK_Mode, Rules.Missing_Global_Contract,
      Rules.Global_Contract_Mismatch, Rules.Missing_Depends_Contract,
      Rules.Incomplete_Depends_Contract, Rules.Depends_Contract_Mismatch);

   Maintainability_Rules : aliased constant Rules.Rule_List :=
     (Rules.Magic_Number, Rules.Cyclomatic_Complexity, Rules.Deep_Nesting,
      Rules.Naming_Convention, Rules.Generic_Instantiation_Limit,
      Rules.Dependency_Limit, Rules.Circular_Package_Dependency,
      Rules.Missing_Overriding_Indicator, Rules.Redundant_Type_Conversion,
      Rules.No_Compiler_Extensions);

   Target_Sensitive_Rules : aliased constant Rules.Rule_List :=
     (Rules.Address_Clause, Rules.Volatile_Atomic_Consistency,
      Rules.Representation_Clause_Policy);

   Iso_Deviation_Control_Rules : aliased constant Rules.Rule_List :=
     (Rules.Suppression_Without_Rationale,
      Rules.No_Runtime_Check_Suppression);

   function ISO_26262_Objectives return Objective_Array is
     ((Id          => To_Unbounded_String ("Restricted control flow"),
       Description => To_Unbounded_String
         ("Source code stays within a restricted, deterministic control-" &
          "flow subset (no goto, recursion, tasking, or dispatch)."),
       Mapped_Rules => Restricted_Control_Flow_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Only exercised when --automotive (or an equivalent explicit " &
          "check selection) was selected for this run.")),
      (Id          => To_Unbounded_String ("Storage and aliasing discipline"),
       Description => To_Unbounded_String
         ("Source code avoids dynamic allocation, unchecked conversion, " &
          "and ambiguous aliasing."),
       Mapped_Rules => Storage_And_Aliasing_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Detects the listed Ada constructs; general points-to and " &
          "lifetime analysis is not provided.")),
      (Id          => To_Unbounded_String ("Initialization and data flow"),
       Description => To_Unbounded_String
         ("Objects are explicitly initialized and assigned values are " &
          "read before being overwritten or going out of scope."),
       Mapped_Rules => Iso_Initialization_And_Data_Flow_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Intraprocedural; aliasing, calls, and unsupported constructs " &
          "can reduce precision.")),
      (Id          => To_Unbounded_String ("Scalar run-time-error classes"),
       Description => To_Unbounded_String
         ("Source code is free of the classes of scalar run-time error " &
          "this analyzer can detect (division, range, overflow, " &
          "precondition/postcondition failure)."),
       Mapped_Rules => Scalar_Run_Time_Error_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Reports only statically decidable instances in the supported " &
          "scalar model; it is not an exhaustive run-time-error proof.")),
      (Id          => To_Unbounded_String ("Control-flow correctness"),
       Description => To_Unbounded_String
         ("Source code contains no dead, unreachable, or contradictory " &
          "control-flow constructs."),
       Mapped_Rules => Control_Flow_Correctness_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Covers statically evident cases; general reachability and " &
          "termination proof is not provided.")),
      (Id          => To_Unbounded_String
         ("Exception, concurrency, and elaboration boundaries"),
       Description => To_Unbounded_String
         ("Exceptions are not silently discarded, blocking operations " &
          "are contained, and library-level elaboration does no work."),
       Mapped_Rules => Exception_Concurrency_Elaboration_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Uses conservative summaries; scheduling and WCET evidence " &
          "remain external.")),
      (Id          => To_Unbounded_String
         ("SPARK contracts and information flow"),
       Description => To_Unbounded_String
         ("Where the SPARK subset is used, Global and Depends contracts " &
          "are present and consistent with implementation behavior."),
       Mapped_Rules => Iso_SPARK_Contract_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Applies to code already using SPARK aspects; it does not by " &
          "itself bring code into the SPARK subset.")),
      (Id          => To_Unbounded_String
         ("Maintainability and reviewability bounds"),
       Description => To_Unbounded_String
         ("Source code stays within configured complexity, coupling, " &
          "and naming bounds, and avoids compiler-specific extensions."),
       Mapped_Rules => Maintainability_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Thresholds are local project policy; a passing result is not " &
          "itself safety evidence.")),
      (Id          => To_Unbounded_String
         ("Target-sensitive constructs require review"),
       Description => To_Unbounded_String
         ("Explicit addresses and representation clauses are flagged " &
          "for mandatory target-specific review."),
       Mapped_Rules => Target_Sensitive_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Intentionally a review finding, not a target ABI, memory " &
          "map, or hardware-protocol verification.")),
      (Id          => To_Unbounded_String ("Deviation control"),
       Description => To_Unbounded_String
         ("Every inline analyzer suppression and run-time-check " &
          "suppression carries a reviewable rationale."),
       Mapped_Rules => Iso_Deviation_Control_Rules'Access,
       Manual_Note  => To_Unbounded_String
         ("Covers inline suppressions only; baseline-matched findings " &
          "carry no rationale (see the suppression trail below).")));

   function ISO_26262_Unsupported return Unsupported_Array is
     ((Name => To_Unbounded_String ("Directive-by-directive ISO 26262 " &
                                     "mapping"),
       Note => To_Unbounded_String
         ("No normative mapping to the licensed ISO 26262 text exists; " &
          "the categories above are AdaLang's own paraphrase. A project " &
          "still needs competent reviewers to classify every applicable " &
          "guideline against its licensed copy of the standard.")),
      (Name => To_Unbounded_String
         ("Complete run-time-error and SPARK verification-level proof"),
       Note => To_Unbounded_String
         ("Only supported known-failure classes and bounded obligations " &
          "are checked. Reaching a specific SPARK verification level " &
          "(Bronze through Platinum) requires GNATprove.")),
      (Name => To_Unbounded_String ("Structural coverage and dynamic " &
                                     "testing"),
       Note => To_Unbounded_String
         ("Not measured or performed. Supply unit/integration tests, " &
          "requirements-based tests, and structural coverage where " &
          "required.")),
      (Name => To_Unbounded_String ("Tool confidence and qualification"),
       Note => To_Unbounded_String
         ("No ISO 26262-8 tool confidence level (TCL) assessment or " &
          "qualification artifact is supplied.")));

end Adalang_Analyzer.Compliance_Mapping;
