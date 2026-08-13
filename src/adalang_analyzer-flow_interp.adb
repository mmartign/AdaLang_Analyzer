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

with Ada.Containers.Vectors;
with Ada.Exceptions;

with Libadalang.Common;
with Langkit_Support.Text;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Control_Flow_Graph;
with Adalang_Analyzer.Flow_Domain; use Adalang_Analyzer.Flow_Domain;
with Adalang_Analyzer.Flow_Eval;   use Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;
with Adalang_Analyzer.Subprogram_Summaries;
with Adalang_Analyzer.Text_Utils;
with Adalang_Analyzer.VC_Prover;

package body Adalang_Analyzer.Flow_Interp is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Analysis.Basic_Decl;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;
   use type Rules.Rule_Kind;

   package Proof renames Adalang_Analyzer.Proof_Obligations;
   package VC renames Adalang_Analyzer.VC_Prover;
   use type Proof.Analysis_Method;
   use type VC.VC_Result;

   procedure Record_Outcome
     (Unit           : Libadalang.Analysis.Analysis_Unit;
      Node           : Libadalang.Analysis.Ada_Node'Class;
      Kind           : Proof.Obligation_Kind;
      Status         : Proof.Obligation_Status;
      Method         : Proof.Analysis_Method;
      Explanation    : String;
      Abstract_State : String := "";
      Imprecision    : String := "";
      Reason_Code    : String := "";
      Blocking_Expression : String := "";
      Inline_Path    : String := "";
      Final          : Boolean := False) is
   begin
      Proof.Register_At
        (Unit             => Unit,
         Node             => Node,
         Kind             => Kind,
         Status           => Status,
         Method           => Method,
         Abstract_State   => Abstract_State,
         Explanation      => Explanation,
         Imprecision_Source => Imprecision,
         Reason_Code      => Reason_Code,
         Blocking_Expression => Blocking_Expression,
         Inline_Path      => Inline_Path,
         Configuration_Id => Config.Assurance_Profile_Name,
         Final            => Final);
   end Record_Outcome;

   procedure Record_Definite_Error
     (Unit           : Libadalang.Analysis.Analysis_Unit;
      Node           : Libadalang.Analysis.Ada_Node'Class;
      Kind           : Proof.Obligation_Kind;
      Method         : Proof.Analysis_Method;
      Explanation    : String;
      Abstract_State : String := "";
      Final          : Boolean := False) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Definite_Error, Method, Explanation,
         Abstract_State, Final => Final);
   end Record_Definite_Error;

   procedure Record_Unproved
     (Unit           : Libadalang.Analysis.Analysis_Unit;
      Node           : Libadalang.Analysis.Ada_Node'Class;
      Kind           : Proof.Obligation_Kind;
      Method         : Proof.Analysis_Method;
      Explanation    : String;
      Abstract_State : String := "";
      Imprecision    : String := "";
      Reason_Code    : String := "";
      Blocking_Expression : String := "";
      Inline_Path    : String := "";
      Final          : Boolean := False) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Unproved, Method, Explanation,
         Abstract_State, Imprecision, Reason_Code, Blocking_Expression,
         Inline_Path, Final => Final);
   end Record_Unproved;

   procedure Record_VC_Unproved
     (Unit                  : Libadalang.Analysis.Analysis_Unit;
      Node                  : Libadalang.Analysis.Ada_Node'Class;
      Kind                  : Proof.Obligation_Kind;
      Method                : Proof.Analysis_Method;
      Explanation           : String;
      Default_Imprecision   : String;
      Outcome               : VC.VC_Outcome;
      Final                 : Boolean := False) is
   begin
      Record_Unproved
        (Unit, Node, Kind, Method, Explanation,
         Imprecision =>
           (if Outcome.Result = VC.VC_Unavailable
            then "CVC5/Z3 prover portfolio is unavailable"
            elsif Outcome.Result = VC.VC_Unsupported
            then VC.Unsupported_Description (Outcome)
            else Default_Imprecision),
         Reason_Code =>
           (if Outcome.Result = VC.VC_Unsupported
            then VC.Unsupported_Reason_Code (Outcome) else ""),
         Blocking_Expression =>
           (if Outcome.Result = VC.VC_Unsupported
            then VC.Blocking_Expression (Outcome) else ""),
         Inline_Path =>
           (if Outcome.Result = VC.VC_Unsupported
            then VC.Inline_Path (Outcome) else ""),
         Final => Final);
   end Record_VC_Unproved;

   procedure Record_Proved_Safe
     (Unit           : Libadalang.Analysis.Analysis_Unit;
      Node           : Libadalang.Analysis.Ada_Node'Class;
      Kind           : Proof.Obligation_Kind;
      Method         : Proof.Analysis_Method;
      Explanation    : String;
      Abstract_State : String := "";
      Final          : Boolean := False) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Proved_Safe, Method, Explanation,
         Abstract_State, Final => Final);
   end Record_Proved_Safe;

   procedure Record_Unreachable
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Node        : Libadalang.Analysis.Ada_Node'Class;
      Kind        : Proof.Obligation_Kind;
      Explanation : String) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Unreachable, Proof.Flow_Analysis,
         Explanation);
   end Record_Unreachable;

   procedure Record_Unsupported
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Node        : Libadalang.Analysis.Ada_Node'Class;
      Kind        : Proof.Obligation_Kind;
      Explanation : String) is
   begin
      Record_Outcome
        (Unit, Node, Kind, Proof.Unsupported, Proof.No_Analysis,
         Explanation, Imprecision => "outside bounded verification subset");
   end Record_Unsupported;

   --  Fetches an aspect from any declaration/body part. Missing or
   --  unresolved contracts are represented by a null expression.
   function Contract_Expression
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Libadalang.Analysis.Expr
   is
      Result : Libadalang.Analysis.Expr;
   begin
      Result := Decl.P_Get_Aspect_Spec_Expr
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Name)));
      if Libadalang.Analysis.Is_Null (Result)
        and then Decl.Kind = Libadalang.Common.Ada_Subp_Body
      then
         declare
            Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
              Decl.As_Subp_Body.P_Decl_Part
                (Imprecise_Fallback => True);
         begin
            if not Libadalang.Analysis.Is_Null (Decl_Part) then
               Result := Decl_Part.P_Get_Aspect_Spec_Expr
                 (Langkit_Support.Text.To_Unbounded_Text
                    (Langkit_Support.Text.To_Text (Name)));
            end if;
         end;
      end if;
      return Result;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Contract_Expression;

   function Has_Aspect
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Boolean
   is
      Aspect : Libadalang.Analysis.Aspect;
   begin
      Aspect := Decl.P_Get_Aspect
        (Langkit_Support.Text.To_Unbounded_Text
           (Langkit_Support.Text.To_Text (Name)));
      if Libadalang.Analysis.Exists (Aspect) then
         return True;
      elsif Decl.Kind = Libadalang.Common.Ada_Subp_Body then
         declare
            Decl_Part : constant Libadalang.Analysis.Basic_Decl :=
              Decl.As_Subp_Body.P_Decl_Part
                (Imprecise_Fallback => True);
         begin
            return not Libadalang.Analysis.Is_Null (Decl_Part)
              and then Has_Aspect (Decl_Part, Name);
         end;
      end if;
      return False;
   exception
      when others =>
         return False;
   end Has_Aspect;

   --  The defining name an identifier resolves to, or No_Ada_Node for
   --  anything else. The Flow_State key type; kept distinct from a
   --  Basic_Decl resolution, which cannot tell apart two names introduced
   --  by one multi-name declaration.
   function Flow_Referenced_Name
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Identifier
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Flow_Referenced_Name;

   --  Determine the initialization state of an object declaration that has
   --  no explicit default expression. A renaming denotes an existing object,
   --  so a simple renaming inherits that object's state. For a newly declared
   --  object, only a resolved scalar type justifies the strong conclusion
   --  that a subsequent read is definitely uninitialized. Other types may
   --  have language-defined or type-defined initialization; keep those
   --  unknown unless a more precise model establishes their state.
   function Implicit_Initialization
     (Decl  : Libadalang.Analysis.Object_Decl;
      State : Flow_State) return Abstract_Bool
   is
      Clause : constant Libadalang.Analysis.Renaming_Clause :=
        Decl.F_Renaming_Clause;
   begin
      if not Libadalang.Analysis.Is_Null (Clause) then
         declare
            Renamed : constant Libadalang.Analysis.Ada_Node :=
              Flow_Referenced_Name (Clause.F_Renamed_Object);
         begin
            if Libadalang.Analysis.Is_Null (Renamed) then
               return Bool_Unknown;
            end if;
            return Flow_Initialization (State, Renamed);
         end;
      end if;

      --  An address clause overlays storage whose validity this local flow
      --  model cannot infer. In particular, a scalar view may denote bytes
      --  that were initialized through another object, so it is not sound to
      --  call the view definitely uninitialized.
      if Has_Aspect (Decl, "Address") then
         return Bool_Unknown;
      end if;

      declare
         Type_Expr : constant Libadalang.Analysis.Type_Expr :=
           Decl.F_Type_Expr;
      begin
         if Libadalang.Analysis.Is_Null (Type_Expr) then
            return Bool_Unknown;
         end if;

         declare
            Base : constant Libadalang.Analysis.Base_Type_Decl :=
              Type_Expr.P_Designated_Type_Decl;
         begin
            if not Libadalang.Analysis.Is_Null (Base)
              and then Base.P_Is_Scalar_Type
            then
               return Bool_False;
            end if;
         end;
      end;

      return Bool_Unknown;
   exception
      when others =>
         return Bool_Unknown;
   end Implicit_Initialization;

   --  On entry, an out parameter is not uniformly equivalent to a fresh
   --  scalar object. Scalar out parameters have no value; composite and
   --  private types can have default-initialized parts or other semantics
   --  that this bounded model does not resolve. Preserve the strong error
   --  result only for a known scalar type.
   function Output_Parameter_Initialization
     (Param : Libadalang.Analysis.Param_Spec) return Abstract_Bool
   is
      Type_Expr : constant Libadalang.Analysis.Type_Expr := Param.F_Type_Expr;
   begin
      if Libadalang.Analysis.Is_Null (Type_Expr) then
         return Bool_Unknown;
      end if;

      declare
         Base : constant Libadalang.Analysis.Base_Type_Decl :=
           Type_Expr.P_Designated_Type_Decl;
      begin
         if not Libadalang.Analysis.Is_Null (Base)
           and then Base.P_Is_Scalar_Type
         then
            return Bool_False;
         end if;
      end;

      return Bool_Unknown;
   exception
      when others =>
         return Bool_Unknown;
   end Output_Parameter_Initialization;

   --  True when evaluating an identifier requires its stored value. Bounds,
   --  representation, address, and access attributes inspect an object's
   --  subtype or identity rather than reading that value. Likewise, the base
   --  name of an assignment target is written, although index expressions in
   --  that target are still reads and therefore are not excluded here.
   function Initialization_Read_Required
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Node);

      function Is_Nonvalue_Attribute
        (Prefix : Libadalang.Analysis.Ada_Node) return Boolean
      is
         Parent : constant Libadalang.Analysis.Ada_Node := Prefix.Parent;
      begin
         if Parent.Kind /= Libadalang.Common.Ada_Attribute_Ref
           or else Libadalang.Analysis.Ada_Node
             (Parent.As_Attribute_Ref.F_Prefix) /= Prefix
         then
            return False;
         end if;

         declare
            Attribute_Name : constant String :=
              Text_Utils.Normalize_Rule_Name
                (Ada_Text.Node_Text (Parent.As_Attribute_Ref.F_Attribute));
         begin
            return Attribute_Name in
              "access" | "address" | "alignment" | "component-size"
                | "first" | "last" | "length" | "object-size" | "range"
                | "size" | "unchecked-access" | "unrestricted-access"
                | "value-size";
         end;
      exception
         when others =>
            return False;
      end Is_Nonvalue_Attribute;
   begin
      if Libadalang.Analysis.Is_Null (Current)
        or else Current.Kind /= Libadalang.Common.Ada_Identifier
      then
         return True;
      end if;

      --  A pragma argument naming an entity ("Status" in "pragma
      --  Unreferenced (Status);") is never read at runtime: it merely
      --  names the declaration without inspecting its value, the same
      --  reasoning Checks.Data_Flow's Uninitialized_Read walk already
      --  applies to this exact node shape. Without this guard, the
      --  climbing loop below falls through its assignment-target/prefix
      --  cases to "return True", misreading the pragma argument as a
      --  definite read before the object's real first assignment.
      --  Observed in the wild (gnatcoll-core's GNATCOLL.OS.FS.Close and
      --  GNATCOLL.Plugins.Unload): "Status : int; pragma Unreferenced
      --  (Status); begin Status := C_Close (FD); end;" flagged as a
      --  definite initialization error at the pragma, two statements
      --  before the assignment that actually initializes Status.
      if Current.Parent.Kind = Libadalang.Common.Ada_Pragma_Argument_Assoc
        and then not Libadalang.Analysis.Is_Null (Current.Parent.Parent)
        and then not Libadalang.Analysis.Is_Null
          (Current.Parent.Parent.Parent)
        and then Current.Parent.Parent.Parent.Kind =
          Libadalang.Common.Ada_Pragma_Node
      then
         declare
            Pragma_Name : constant String :=
              Text_Utils.Normalize_Rule_Name
                (Ada_Text.Node_Text
                   (Current.Parent.Parent.Parent.As_Pragma_Node.F_Id));
         begin
            if Pragma_Name = "unreferenced"
              or else Pragma_Name = "unmodified"
              or else Pragma_Name = "warnings"
            then
               return False;
            end if;
         end;
      end if;

      loop
         if Is_Nonvalue_Attribute (Current) then
            return False;
         end if;

         declare
            Parent : constant Libadalang.Analysis.Ada_Node := Current.Parent;
         begin
            if Libadalang.Analysis.Is_Null (Parent) then
               return True;
            elsif Parent.Kind = Libadalang.Common.Ada_Assign_Stmt
              and then Libadalang.Analysis.Ada_Node
                (Parent.As_Assign_Stmt.F_Dest) = Current
            then
               return False;
            elsif
              (Parent.Kind = Libadalang.Common.Ada_Dotted_Name
               and then Libadalang.Analysis.Ada_Node
                 (Parent.As_Dotted_Name.F_Prefix) = Current)
              or else
                --  The suffix climbs exactly like the prefix: naming a
                --  Dotted_Name's suffix is no more a read of its value
                --  than naming the prefix is, and judgment defers to the
                --  Dotted_Name's own outer context either way. Harmless
                --  for an ordinary "R.Field" (Field resolves to a
                --  Component_Decl, never Tracked below, so this arm
                --  never changes the outcome), but required for
                --  "Subp_Name.Param := ...;" inside "procedure Subp_Name
                --  (Param : out ...)" (RM 8.3 unit-name qualification,
                --  the same shape FP-011 fixed for
                --  SPARK_Readiness.Same_Parameter): without this arm,
                --  Param -- the suffix -- had no climbable case at all
                --  and fell straight to "return True" below, misreading
                --  its own qualified write as a read of an
                --  uninitialized out parameter (FP-046).
                (Parent.Kind = Libadalang.Common.Ada_Dotted_Name
                 and then Libadalang.Analysis.Ada_Node
                   (Parent.As_Dotted_Name.F_Suffix) = Current)
              or else
                (Parent.Kind = Libadalang.Common.Ada_Call_Expr
                 and then Libadalang.Analysis.Ada_Node
                   (Parent.As_Call_Expr.F_Name) = Current)
              or else
                (Parent.Kind = Libadalang.Common.Ada_Explicit_Deref
                 and then Libadalang.Analysis.Ada_Node
                   (Parent.As_Explicit_Deref.F_Prefix) = Current)
            then
               Current := Parent;
            else
               return True;
            end if;
         end;
      end loop;
   exception
      when others =>
         return True;
   end Initialization_Read_Required;

   --  The nearest enclosing Subp_Body containing Node, i.e. the
   --  subprogram whose own defining name a nested statement can use to
   --  prefix-qualify one of its own formal parameters (Ada's general
   --  unit-name qualification, RM 8.3), typically to reach a parameter
   --  that a same-named component of an enclosing protected or task
   --  object would otherwise shadow for simple-name visibility.
   --  No_Basic_Decl if Node isn't nested in one. Entry_Body is
   --  deliberately not recognized here, unlike SPARK_Readiness's own
   --  Enclosing_Subprogram_Or_Entry: Interpret_Subprogram_Flow (the only
   --  caller reaching this, transitively, through Flow_Assigned_Name)
   --  only ever descends into Subp_Body, so an entry can never be Node's
   --  innermost enclosing construct here.
   function Enclosing_Subp_Body_Decl
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Basic_Decl
   is
      Current : Libadalang.Analysis.Ada_Node := Libadalang.Analysis.Ada_Node
        (Node);
   begin
      loop
         if Libadalang.Analysis.Is_Null (Current) then
            return Libadalang.Analysis.No_Basic_Decl;
         elsif Current.Kind = Libadalang.Common.Ada_Subp_Body then
            return Current.As_Basic_Decl;
         end if;
         Current := Current.Parent;
      end loop;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Enclosing_Subp_Body_Decl;

   --  The Defining_Name of Subprogram's own formal parameter named
   --  Suffix_Name, or No_Ada_Node if it has none by that name. This is
   --  the very same Defining_Name node Seed_Parameters uses as the
   --  parameter's Flow_State key, so returning it here lets a write
   --  through an own-name-qualified reference update the same binding a
   --  plain reference to the parameter would.
   function Matching_Formal_Name
     (Subprogram  : Libadalang.Analysis.Basic_Decl;
      Suffix_Name : String) return Libadalang.Analysis.Ada_Node
   is
   begin
      for Param of Subprogram.As_Subp_Body.F_Subp_Spec.P_Params loop
         for Id of Param.F_Ids loop
            if Text_Utils.Normalize_Rule_Name (Ada_Text.Node_Text (Id)) =
              Suffix_Name
            then
               return Libadalang.Analysis.Ada_Node (Id);
            end if;
         end loop;
      end loop;
      return Libadalang.Analysis.No_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Matching_Formal_Name;

   --  The defining name written by an assignment whose destination is a
   --  plain identifier, or No_Ada_Node for anything else (a more complex
   --  destination such as an array or record component) -- except for
   --  "Subp_Name.Param := ...;" inside "procedure Subp_Name (Param : out
   --  ...)", where Subp_Name is the enclosing subprogram's own name used
   --  to qualify Param (RM 8.3), typically to disambiguate it from a
   --  same-named component of an enclosing protected/task object that
   --  would otherwise shadow Param for simple-name visibility.
   --  SPARK_Readiness.Same_Parameter already recognizes this shape for
   --  the --recommended/Uninitialized_Output path (FP-011); this mirrors
   --  it for --verify's own, separate initialization tracking, which had
   --  never received the equivalent fix and so still reported a false
   --  Definite_Error on writes of this shape (FP-046).
   function Flow_Assigned_Name
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Assign_Stmt
      then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      declare
         Dest : constant Libadalang.Analysis.Name :=
           Node.As_Assign_Stmt.F_Dest;
      begin
         if Dest.Kind = Libadalang.Common.Ada_Identifier then
            return Flow_Referenced_Name (Dest);
         end if;

         if Dest.Kind = Libadalang.Common.Ada_Dotted_Name
           and then Dest.As_Dotted_Name.F_Suffix.Kind =
             Libadalang.Common.Ada_Identifier
         then
            declare
               Prefix_Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Dest.As_Dotted_Name.F_Prefix.P_Referenced_Decl
                   (Imprecise_Fallback => True);
               Enclosing   : constant Libadalang.Analysis.Basic_Decl :=
                 Enclosing_Subp_Body_Decl (Node);
            begin
               if not Libadalang.Analysis.Is_Null (Enclosing)
                 and then Prefix_Decl = Enclosing
               then
                  return Matching_Formal_Name
                    (Enclosing,
                     Text_Utils.Normalize_Rule_Name
                       (Ada_Text.Node_Text
                          (Dest.As_Dotted_Name.F_Suffix)));
               end if;
            end;
         end if;
      end;

      return Libadalang.Analysis.No_Ada_Node;
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Flow_Assigned_Name;

   function Normalized_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      return Text_Utils.Normalize_Rule_Name (Ada_Text.Node_Text (Node));
   end Normalized_Text;

   function Flow_Object_Key
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      if Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind /= Libadalang.Common.Ada_Defining_Name
      then
         return "";
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Node.As_Defining_Name.P_Basic_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Decl) then
            return "";
         end if;
         return Langkit_Support.Text.To_UTF8
           (Decl.P_Unique_Identifying_Name) & ":" & Normalized_Text (Node);
      end;
   exception
      when others =>
         return "";
   end Flow_Object_Key;

   procedure Havoc_Object_Key
     (State : in out Flow_State;
      Key   : String)
   is
   begin
      if Key = "" then
         return;
      end if;
      for Index in 1 .. Binding_Count (State) loop
         declare
            Binding : constant Flow_Binding := Binding_At (State, Index);
         begin
            if Flow_Object_Key (Binding.Decl) = Key then
               Flow_Havoc (State, Binding.Decl);
            end if;
         end;
      end loop;
   end Havoc_Object_Key;

   function Call_Declaration
     (Call : Libadalang.Analysis.Name'Class)
      return Libadalang.Analysis.Basic_Decl is
   begin
      if Call.Kind = Libadalang.Common.Ada_Call_Expr then
         return Call.As_Call_Expr.F_Name.P_Referenced_Decl;
      else
         return Call.P_Referenced_Decl;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Basic_Decl;
   end Call_Declaration;

   type SPARK_Mode_State is record
      Has_Mode : Boolean := False;
      Is_Off   : Boolean := False;
   end record;

   function Own_SPARK_Mode
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return SPARK_Mode_State
   is
      Aspect : constant Libadalang.Analysis.Aspect :=
        Decl.P_Get_Aspect
          (Langkit_Support.Text.To_Unbounded_Text
             (Langkit_Support.Text.To_Text ("SPARK_Mode")));
   begin
      if not Libadalang.Analysis.Exists (Aspect) then
         return (Has_Mode => False, Is_Off => False);
      end if;
      return
        (Has_Mode => True,
         Is_Off   =>
           not Libadalang.Analysis.Is_Null
             (Libadalang.Analysis.Value (Aspect))
           and then Normalized_Text (Libadalang.Analysis.Value (Aspect)) =
             "off");
   exception
      when others =>
         return (Has_Mode => False, Is_Off => False);
   end Own_SPARK_Mode;

   function Effective_SPARK_Enabled
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Mode     : SPARK_Mode_State;
      Ancestor : Libadalang.Analysis.Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Decl) then
         return True;
      end if;

      Mode := Own_SPARK_Mode (Decl);
      if Mode.Has_Mode then
         return not Mode.Is_Off;
      end if;

      --  SPARK_Mode was not set directly on Decl: per the SPARK RM it is
      --  inherited from the nearest enclosing package/subprogram/task/
      --  protected body or spec. Libadalang's own aspect lookup only
      --  follows type derivation for inheritance, not lexical scoping,
      --  so the enclosing bodies/specs are walked by hand here.
      Ancestor := Libadalang.Analysis.Ada_Node (Decl).Parent;
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         case Ancestor.Kind is
            when Libadalang.Common.Ada_Package_Body
               | Libadalang.Common.Ada_Package_Decl
               | Libadalang.Common.Ada_Generic_Package_Decl
               | Libadalang.Common.Ada_Subp_Body
               | Libadalang.Common.Ada_Task_Body
               | Libadalang.Common.Ada_Protected_Body
            =>
               Mode := Own_SPARK_Mode (Ancestor.As_Basic_Decl);
               if Mode.Has_Mode then
                  return not Mode.Is_Off;
               end if;
            when others =>
               null;
         end case;
         Ancestor := Ancestor.Parent;
      end loop;

      return True;
   exception
      when others =>
         return True;
   end Effective_SPARK_Enabled;

   function Formal_Mode
     (Param : Libadalang.Analysis.Defining_Name'Class)
      return Libadalang.Common.Ada_Node_Kind_Type
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Param);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return Current.As_Param_Spec.F_Mode;
         end if;
         Current := Current.Parent;
      end loop;

      return Libadalang.Common.Ada_Mode_Default;
   exception
      when others =>
         return Libadalang.Common.Ada_Mode_Default;
   end Formal_Mode;

   function Formal_Is_Writable
     (Param : Libadalang.Analysis.Defining_Name'Class) return Boolean is
   begin
      return Formal_Mode (Param) in Libadalang.Common.Ada_Mode_Out
        | Libadalang.Common.Ada_Mode_In_Out;
   end Formal_Is_Writable;

   procedure Seed_Formal_Values
     (Call            : Libadalang.Analysis.Name'Class;
      Caller_State    : Flow_State;
      Include_Outputs : Boolean;
      Contract_State  : in out Flow_State)
   is
   begin
      for Pair of Call.P_Call_Params loop
         if Include_Outputs
           or else not Formal_Is_Writable
             (Libadalang.Analysis.Param (Pair))
         then
            declare
               Key : constant Libadalang.Analysis.Ada_Node :=
                 Libadalang.Analysis.Ada_Node
                   (Libadalang.Analysis.Param (Pair));
            begin
               Flow_Set
                 (Contract_State, Key,
                  Integer_Value
                    (Libadalang.Analysis.Actual (Pair), Caller_State));
               Flow_Bool_Set
                 (Contract_State, Key,
                  Boolean_Value
                    (Libadalang.Analysis.Actual (Pair), Caller_State));
               Flow_Range_Set
                 (Contract_State, Key,
                  Range_Value
                    (Libadalang.Analysis.Actual (Pair), Caller_State));
            end;
         end if;
      end loop;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping formal-value seeding: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Seed_Formal_Values;

   function Contains_VC_Arithmetic
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean;

   procedure Check_Call_Precondition
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Call    : Libadalang.Analysis.Name'Class;
      State   : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final   : Boolean := False)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      if Config.Rule_States (Rules.Known_Precondition_Failure) /=
           Config.Enabled
        or else Libadalang.Analysis.Is_Null (Decl)
        or else not Effective_SPARK_Enabled (Decl)
      then
         return;
      end if;

      declare
         Pre : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Decl, "Pre");
         Contract_State : Flow_State := Empty_Flow_State;
         Contract_Symbols : VC.Symbolic_State := Symbols;
      begin
         if Libadalang.Analysis.Is_Null (Pre) then
            return;
         end if;

         Seed_Formal_Values
           (Call, State, Include_Outputs => True,
            Contract_State => Contract_State);
         for Pair of Call.P_Call_Params loop
            Contract_Symbols :=
              VC.Assign
                (Contract_Symbols,
                 Libadalang.Analysis.Ada_Node
                   (Libadalang.Analysis.Param (Pair)),
                 Libadalang.Analysis.Actual (Pair), State);
         end loop;

         declare
            Value : constant Abstract_Bool :=
              Boolean_Value (Pre, Contract_State);
            VC_Outcome : constant VC.VC_Outcome :=
              (if Config.Verification_Mode and then Value = Bool_Unknown
               then VC.Decide
                 (Pre, Contract_State, Contract_Symbols)
               else VC.Unknown_Outcome);
            VC_Result : constant VC.VC_Result := VC_Outcome.Result;
         begin
            if Value = Bool_False
              or else
                (VC_Result = VC.VC_Refuted
                 and then not Contains_VC_Arithmetic (Pre))
            then
               Record_Definite_Error
                 (Unit, Call, Proof.Precondition_Check,
                  (if VC_Result = VC.VC_Refuted
                   then Proof.External_Prover else Proof.Contract_Transfer),
                  "actual arguments make the precondition false",
                  (if VC_Result = VC.VC_Refuted
                   then VC.Evidence else "precondition => false"),
                  Final => Final);
               Report.Report_Rule_Violation
                 (Unit, Call, Rules.Known_Precondition_Failure,
                  "actual arguments make the precondition false",
                  Explanation =>
                    "The actual arguments were substituted for the formal " &
                    "parameters and the precondition evaluated to False.",
                  Evidence =>
                    (if VC_Result = VC.VC_Refuted
                     then VC.Evidence else "precondition => false"));
            elsif Config.Verification_Mode
              and then
                (Value = Bool_True or else VC_Result = VC.VC_Proved)
            then
               --  proof-path: precondition-decision
               Record_Proved_Safe
                 (Unit, Call, Proof.Precondition_Check,
                  (if VC_Result = VC.VC_Proved
                   then Proof.External_Prover else Proof.Contract_Transfer),
                  "actual arguments satisfy the precondition",
                  (if VC_Result = VC.VC_Proved
                   then VC.Evidence else "precondition => true"),
                  Final => Final);
            else
               Record_VC_Unproved
                 (Unit, Call, Proof.Precondition_Check,
                  Proof.Contract_Transfer,
                  "precondition failure is not established, but absence is " &
                    "not proved",
                  "current contract transfer does not certify safety",
                  VC_Outcome,
                  Final => Final);
            end if;
         end;
      end;
   end Check_Call_Precondition;

   --  Havocs every identifier anywhere under Node. Used for contract outputs
   --  and as the conservative fallback when formal/actual resolution fails.
   procedure Havoc_Identifiers_In
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier then
         Flow_Havoc (State, Flow_Referenced_Name (Node));
      end if;

      for I in 1 .. Node.Children_Count loop
         Havoc_Identifiers_In (Node.Child (I), State);
      end loop;
   end Havoc_Identifiers_In;

   --  Invalidates outputs named by a called subprogram's SPARK Global
   --  contract. Input and Proof_In associations are read-only and therefore
   --  preserve their abstract values. A malformed or unrecognized aggregate
   --  falls back to invalidating every identifier it contains.
   --
   --  An unresolved callee, or a resolved one with no Global contract at
   --  all, gives no basis for naming which outside state it may write:
   --  ordinary (non-SPARK-annotated) Ada falls in this case for almost
   --  every call. Trusting prior knowledge to survive such a call is
   --  unsound (a value known before the call could have been changed by
   --  it, including through an up-level reference the caller never passes
   --  as a parameter), so this discards every tracked binding instead of
   --  leaving them untouched.
   procedure Havoc_Global_Effects
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      if Adalang_Analyzer.Subprogram_Summaries.Callee_State_Effects_Known
           (Call)
      then
         for Index in 1 ..
           Adalang_Analyzer.Subprogram_Summaries.Callee_Global_Write_Count
             (Call)
         loop
            Havoc_Object_Key
              (State,
               Adalang_Analyzer.Subprogram_Summaries.Callee_Global_Write
                 (Call, Index));
         end loop;
         return;
      end if;

      if Libadalang.Analysis.Is_Null (Decl) then
         Flow_Havoc_All (State);
         return;
      end if;

      declare
         Global : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Decl, "Global");
      begin
         if Libadalang.Analysis.Is_Null (Global) then
            Flow_Havoc_All (State);
            return;
         elsif Global.Kind not in Libadalang.Common.Ada_Base_Aggregate
         then
            --  The shorthand form denotes inputs only.
            return;
         end if;

         for Item of Global.As_Base_Aggregate.F_Assocs loop
            if Item.Kind = Libadalang.Common.Ada_Aggregate_Assoc then
               declare
                  Assoc : constant Libadalang.Analysis.Aggregate_Assoc :=
                    Item.As_Aggregate_Assoc;
                  Mode  : constant String :=
                    (if Assoc.F_Designators.Children_Count = 0 then ""
                     else Normalized_Text (Assoc.F_Designators.Child (1)));
               begin
                  if Mode = "output" or else Mode = "in-out" then
                     Havoc_Identifiers_In (Assoc.F_R_Expr, State);
                  elsif Mode /= "input" and then Mode /= "proof-in" then
                     Havoc_Identifiers_In (Global, State);
                     return;
                  end if;
               end;
            else
               Havoc_Identifiers_In (Global, State);
               return;
            end if;
         end loop;
      end;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping Global-effect interpretation: " &
            Ada.Exceptions.Exception_Message (Exc));
         Flow_Havoc_All (State);
   end Havoc_Global_Effects;

   procedure Havoc_Call_Actuals
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
   begin
      for Pair of Call.P_Call_Params loop
         if Formal_Is_Writable (Libadalang.Analysis.Param (Pair))
           and then
             (not Adalang_Analyzer.Subprogram_Summaries
                    .Callee_State_Effects_Known (Call)
              or else Adalang_Analyzer.Subprogram_Summaries
                .Callee_Formal_May_Write
                  (Call, Libadalang.Analysis.Param (Pair)))
         then
            Havoc_Identifiers_In
              (Libadalang.Analysis.Actual (Pair), State);
         end if;

         if Adalang_Analyzer.Subprogram_Summaries
              .Callee_Formal_Definitely_Writes
                (Call, Libadalang.Analysis.Param (Pair))
           and then Libadalang.Analysis.Actual (Pair).Kind =
             Libadalang.Common.Ada_Identifier
         then
            Flow_Set_Initialized
              (State,
               Flow_Referenced_Name (Libadalang.Analysis.Actual (Pair)),
               Bool_True);
         end if;
      end loop;
   exception
      when others =>
         Havoc_Identifiers_In (Call, State);
   end Havoc_Call_Actuals;

   function Call_Transfer_Supported
     (Call : Libadalang.Analysis.Name'Class) return Boolean
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);
   begin
      if Libadalang.Analysis.Is_Null (Decl)
        or else not Effective_SPARK_Enabled (Decl)
        or else not Has_Aspect (Decl, "Global")
      then
         return False;
      end if;

      for Left of Call.P_Call_Params loop
         if Formal_Is_Writable (Libadalang.Analysis.Param (Left))
           and then Libadalang.Analysis.Actual (Left).Kind /=
             Libadalang.Common.Ada_Identifier
         then
            return False;
         end if;

         for Right of Call.P_Call_Params loop
            if (Formal_Is_Writable (Libadalang.Analysis.Param (Left))
                or else
                Formal_Is_Writable (Libadalang.Analysis.Param (Right)))
              and then Libadalang.Analysis.Actual (Left).Kind =
                Libadalang.Common.Ada_Identifier
              and then Libadalang.Analysis.Actual (Right).Kind =
                Libadalang.Common.Ada_Identifier
              and then Libadalang.Analysis.Ada_Node
                (Libadalang.Analysis.Actual (Left)) /=
                Libadalang.Analysis.Ada_Node
                  (Libadalang.Analysis.Actual (Right))
              and then Flow_Referenced_Name
                (Libadalang.Analysis.Actual (Left)) =
                Flow_Referenced_Name (Libadalang.Analysis.Actual (Right))
            then
               return False;
            end if;
         end loop;
      end loop;
      return True;
   exception
      when others =>
         return False;
   end Call_Transfer_Supported;

   procedure Apply_Call_Postcondition
     (Call  : Libadalang.Analysis.Name'Class;
      State : in out Flow_State)
   is
      Decl : constant Libadalang.Analysis.Basic_Decl :=
        Call_Declaration (Call);

      procedure Apply_Simple_Facts
        (Expr : Libadalang.Analysis.Ada_Node'Class)
      is
      begin
         if Libadalang.Analysis.Is_Null (Expr)
           or else Expr.Kind not in Libadalang.Common.Ada_Bin_Op_Range
         then
            return;
         end if;

         declare
            Op : constant Libadalang.Analysis.Bin_Op := Expr.As_Bin_Op;
         begin
            if Op.F_Op in Libadalang.Common.Ada_Op_And
                | Libadalang.Common.Ada_Op_And_Then
            then
               Apply_Simple_Facts (Op.F_Left);
               Apply_Simple_Facts (Op.F_Right);
               return;
            elsif Op.F_Op /= Libadalang.Common.Ada_Op_Eq then
               return;
            end if;

            declare
               Formal_Expr : constant Libadalang.Analysis.Expr :=
                 (if Op.F_Left.Kind = Libadalang.Common.Ada_Identifier
                  then Op.F_Left
                  elsif Op.F_Right.Kind = Libadalang.Common.Ada_Identifier
                  then Op.F_Right
                  else Libadalang.Analysis.No_Expr);
               Fact_Expr : constant Libadalang.Analysis.Expr :=
                 (if Libadalang.Analysis.Is_Null (Formal_Expr)
                  then Libadalang.Analysis.No_Expr
                  elsif Libadalang.Analysis.Ada_Node (Formal_Expr) =
                    Libadalang.Analysis.Ada_Node (Op.F_Left)
                  then Op.F_Right
                  else Op.F_Left);
               Fact_Value : constant Abstract_Int :=
                 Integer_Value (Fact_Expr, State);
               Fact_Bool : constant Abstract_Bool :=
                 Boolean_Value (Fact_Expr, State);
            begin
               if Libadalang.Analysis.Is_Null (Formal_Expr) then
                  return;
               end if;

               for Pair of Call.P_Call_Params loop
                  if Normalized_Text (Libadalang.Analysis.Param (Pair)) =
                    Normalized_Text (Formal_Expr)
                    and then Formal_Is_Writable
                      (Libadalang.Analysis.Param (Pair))
                    and then Libadalang.Analysis.Actual (Pair).Kind =
                      Libadalang.Common.Ada_Identifier
                  then
                     declare
                        Key : constant Libadalang.Analysis.Ada_Node :=
                          Flow_Referenced_Name
                            (Libadalang.Analysis.Actual (Pair));
                     begin
                        if Fact_Value.Known then
                           Flow_Set (State, Key, Fact_Value);
                           Flow_Range_Set
                             (State, Key, Range_From_Int (Fact_Value));
                        end if;
                        if Fact_Bool /= Bool_Unknown then
                           Flow_Bool_Set (State, Key, Fact_Bool);
                        end if;
                        Flow_Set_Initialized (State, Key, Bool_True);
                     end;
                  end if;
               end loop;
            end;
         end;
      end Apply_Simple_Facts;
   begin
      if Libadalang.Analysis.Is_Null (Decl)
        or else not Effective_SPARK_Enabled (Decl)
        or else
          (Config.Verification_Mode
           and then not Call_Transfer_Supported (Call))
      then
         if Config.Verification_Mode then
            Log_Verbose_Once
              ("not applying unsupported call postcondition transfer at " &
               Ada_Text.Node_Text (Call));
         end if;
         return;
      end if;

      declare
         Post : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Decl, "Post");
         Contract_State : Flow_State := Empty_Flow_State;
         True_State, False_State : Flow_State;
      begin
         if Libadalang.Analysis.Is_Null (Post) then
            return;
         end if;

         Seed_Formal_Values
           (Call, State, Include_Outputs => False,
            Contract_State => Contract_State);
         Narrow_By_Condition
           (Post, Contract_State, True_State, False_State);

         if Boolean_Value (Post, Contract_State) = Bool_False then
            return;
         end if;

         for Pair of Call.P_Call_Params loop
            if Formal_Is_Writable (Libadalang.Analysis.Param (Pair))
              and then Libadalang.Analysis.Actual (Pair).Kind =
                Libadalang.Common.Ada_Identifier
            then
               declare
                  Formal_Key : constant Libadalang.Analysis.Ada_Node :=
                    Libadalang.Analysis.Ada_Node
                      (Libadalang.Analysis.Param (Pair));
                  Actual_Key : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Referenced_Name
                      (Libadalang.Analysis.Actual (Pair));
                  Value : Abstract_Int :=
                    Flow_Lookup (True_State, Formal_Key);
                  Bounds : constant Abstract_Range :=
                    Flow_Range_Lookup (True_State, Formal_Key);
               begin
                  if not Value.Known
                    and then Bounds.Has_Low
                    and then Bounds.Has_High
                    and then Bounds.Low = Bounds.High
                  then
                     Value := Known_Int (Bounds.Low);
                  end if;

                  Flow_Set (State, Actual_Key, Value);
                  Flow_Bool_Set
                    (State, Actual_Key,
                     Flow_Bool_Lookup (True_State, Formal_Key));
                  Flow_Range_Set (State, Actual_Key, Bounds);
               end;
            end if;
         end loop;
         Apply_Simple_Facts (Post);
      end;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping postcondition interpretation: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Apply_Call_Postcondition;

   --  Invalidates whatever Node's own evaluation could change: writable
   --  actual parameters and Global outputs of calls found within it, and
   --  every variable directly assigned to when Node is a statement list
   --  containing assignments (the pre-loop-body havoc case). Does not
   --  descend into a nested subprogram body, which is analyzed separately.
   procedure Havoc_Effects_In
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Assign_Stmt =>
            Flow_Havoc (State, Flow_Assigned_Name (Node));

         when Libadalang.Common.Ada_Call_Expr =>
            if Node.As_Call_Expr.P_Kind = Libadalang.Common.Call then
               Havoc_Global_Effects (Node.As_Call_Expr.F_Name, State);
               Havoc_Call_Actuals (Node.As_Call_Expr.F_Name, State);
            else
               for Index in 1 .. Node.Children_Count loop
                  Havoc_Effects_In (Node.Child (Index), State);
               end loop;
            end if;
            return;

         when Libadalang.Common.Ada_Subp_Body =>
            return;

         when others =>
            null;  --  adalang-analyzer: ignore Null_Statement
      end case;

      for I in 1 .. Node.Children_Count loop
         Havoc_Effects_In (Node.Child (I), State);
      end loop;
   end Havoc_Effects_In;

   --  Type_Range and Array_Index_Range moved to Adalang_Analyzer.Flow_Eval
   --  (still visible here unqualified via this unit's own "use
   --  Adalang_Analyzer.Flow_Eval") so Adalang_Analyzer.VC_Prover, which sits
   --  below this unit and cannot import it, can resolve subtype-mark and
   --  array-attribute bounds too -- see VC_Prover's Ada_Membership_Expr and
   --  Ada_Attribute_Ref support.

   function Definitely_Outside_Range
     (Value        : Libadalang.Analysis.Expr'Class;
      Target_Range : Abstract_Range;
      State        : Flow_State) return Boolean
   is
      Value_Bounds : constant Abstract_Range := Range_Value (Value, State);
   begin
      return
        (Value_Bounds.Has_High
         and then Target_Range.Has_Low
         and then Value_Bounds.High < Target_Range.Low)
        or else
        (Value_Bounds.Has_Low
         and then Target_Range.Has_High
         and then Value_Bounds.Low > Target_Range.High);
   end Definitely_Outside_Range;

   function Definitely_Inside_Range
     (Value  : Libadalang.Analysis.Ada_Node'Class;
      Bounds : Abstract_Range;
      State  : Flow_State) return Boolean
   is
      Value_Bounds : constant Abstract_Range := Range_Value (Value, State);
   begin
      return Bounds.Has_Low
        and then Bounds.Has_High
        and then Value_Bounds.Has_Low
        and then Value_Bounds.Has_High
        and then Value_Bounds.Low >= Bounds.Low
        and then Value_Bounds.High <= Bounds.High;
   end Definitely_Inside_Range;

   function Definitely_Outside_Type
     (Value : Libadalang.Analysis.Expr'Class;
      Typ   : Libadalang.Analysis.Base_Type_Decl;
      State : Flow_State) return Boolean
   is
      Type_Bounds  : constant Abstract_Range := Type_Range (Typ, State);
   begin
      return Definitely_Outside_Range (Value, Type_Bounds, State);
   exception
      when others =>
         return False;
   end Definitely_Outside_Type;

   function Definitely_Inside_Type
     (Value : Libadalang.Analysis.Ada_Node'Class;
      Typ   : Libadalang.Analysis.Base_Type_Decl;
      State : Flow_State) return Boolean
   is
      Type_Bounds : constant Abstract_Range := Type_Range (Typ, State);
   begin
      if Value.Kind = Libadalang.Common.Ada_Call_Expr
        and then Value.As_Call_Expr.P_Kind =
          Libadalang.Common.Type_Conversion
      then
         declare
            Converted_Type : constant Libadalang.Analysis.Basic_Decl :=
              Value.As_Call_Expr.F_Name.P_Referenced_Decl;
         begin
            if not Libadalang.Analysis.Is_Null (Converted_Type)
              and then Converted_Type.Kind in
                Libadalang.Common.Ada_Base_Type_Decl
              and then Libadalang.Analysis.Ada_Node
                (Converted_Type.As_Base_Type_Decl) =
                Libadalang.Analysis.Ada_Node (Typ)
            then
               return True;
            end if;
         end;
      end if;
      return Definitely_Inside_Range (Value, Type_Bounds, State);
   exception
      when others =>
         return False;
   end Definitely_Inside_Type;

   function Overflow_Base_Range
     (Typ   : Libadalang.Analysis.Base_Type_Decl'Class;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Abstract_Range
   is
      --  A single P_Base_Type hop only reaches the immediate parent, whose
      --  own visible constraint can itself be a narrowed first subtype
      --  (e.g. a "new Natural" parent still carries Natural's 0-based
      --  constraint, not its own unconstrained base range). Walk to the
      --  derivation root instead, so a multiply-derived type (RecordFlux's
      --  Index -> Length -> Natural pattern, for instance) resolves to its
      --  true machine base range. Only do this when a real parent exists:
      --  Is_Null also covers non-derived types and Libadalang's synthetic
      --  universal-integer root (named-number initializers such as a bare
      --  "2**14"), neither of which has a real base range to widen to --
      --  the latter's own visible "range" is a meaningless placeholder.
      Immediate_Base : constant Libadalang.Analysis.Base_Type_Decl :=
        Typ.P_Base_Type (Node);
   begin
      if Libadalang.Analysis.Is_Null (Immediate_Base) then
         return Unknown_Range;
      end if;
      return Type_Range (Typ.P_Root_Type (Node), State);
   end Overflow_Base_Range;

   function Arithmetic_Proved_Safe
     (Node  : Libadalang.Analysis.Expr'Class;
      State : Flow_State) return Boolean
   is
      Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
        Node.P_Expression_Type;
   begin
      if Libadalang.Analysis.Is_Null (Expr_Type)
        or else not Expr_Type.P_Is_Int_Type
      then
         return False;
      end if;

      declare
         Bounds : Abstract_Range :=
           Overflow_Base_Range (Expr_Type, Node, State);
         Name   : constant String := Langkit_Support.Text.To_UTF8
           (Expr_Type.P_Canonical_Fully_Qualified_Name);
      begin
         if not Bounds.Has_Low
           and then not Bounds.Has_High
           and then Name = "standard.integer"
         then
            Bounds := Type_Range (Expr_Type, State);
         end if;
         return Definitely_Inside_Range (Node, Bounds, State);
      end;
   exception
      when others =>
         return False;
   end Arithmetic_Proved_Safe;

   function Known_Arithmetic_Overflow
     (Node  : Libadalang.Analysis.Expr'Class;
      State : Flow_State) return Boolean
   is
   begin
      if Node.Kind not in Libadalang.Common.Ada_Bin_Op_Range
        or else Node.As_Bin_Op.F_Op not in
          Libadalang.Common.Ada_Op_Plus
            | Libadalang.Common.Ada_Op_Minus
            | Libadalang.Common.Ada_Op_Mult
            | Libadalang.Common.Ada_Op_Div
            | Libadalang.Common.Ada_Op_Pow
      then
         return False;
      end if;

      declare
         Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Node.P_Expression_Type;
      begin
         if Libadalang.Analysis.Is_Null (Expr_Type)
           or else not Expr_Type.P_Is_Int_Type
         then
            return False;
         end if;

         declare
            Bounds : Abstract_Range :=
              Overflow_Base_Range (Expr_Type, Node, State);
            Name   : constant String := Langkit_Support.Text.To_UTF8
              (Expr_Type.P_Canonical_Fully_Qualified_Name);
         begin
            --  Standard.Integer's base subtype is synthetic and its bound
            --  expressions are not always reducible by the evaluator. Its
            --  visible declaration has the same bounds, so it is a sound
            --  fallback. Do not apply this fallback to derived first
            --  subtypes: their visible constraint can be narrower than the
            --  operation's base range.
            if not Bounds.Has_Low
              and then not Bounds.Has_High
              and then Name = "standard.integer"
            then
               Bounds := Type_Range (Expr_Type, State);
            end if;
            return Definitely_Outside_Range (Node, Bounds, State);
         end;
      end;
   exception
      when others =>
         return False;
   end Known_Arithmetic_Overflow;

   procedure Check_Value_Range
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Value   : Libadalang.Analysis.Expr'Class;
      Typ     : Libadalang.Analysis.Base_Type_Decl;
      State   : Flow_State;
      Rule    : Rules.Rule_Kind;
      Message : String;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final   : Boolean := False) is
   begin
      if Config.Rule_States (Rule) /= Config.Enabled then
         return;
      end if;

      --  A definitely overflowing expression raises before the subsequent
      --  subtype check. Do not create a second obligation for an operation
      --  that is not reached on the represented execution.
      if Rule = Rules.Known_Range_Check_Failure
        and then Config.Rule_States (Rules.Known_Overflow_Failure) =
          Config.Enabled
        and then Known_Arithmetic_Overflow (Value, State)
      then
         return;
      elsif Libadalang.Analysis.Is_Null (Typ) then
         if Config.Verification_Mode then
            Record_Unsupported
              (Unit, Value, Proof.Range_Check,
               "target subtype could not be resolved");
         else
            Record_Unproved
              (Unit, Value, Proof.Range_Check, Proof.No_Analysis,
               "target subtype could not be resolved",
               Imprecision => "semantic type resolution failed");
         end if;
      elsif Definitely_Outside_Type (Value, Typ, State) then
         Record_Definite_Error
           (Unit, Value, Proof.Range_Check, Proof.Abstract_Interpretation,
            Message, "value range is outside the target subtype range",
            Final => Final);
         Report.Report_Rule_Violation
           (Unit, Value, Rule, Message,
            Explanation =>
              "Abstract interpretation found that every represented value " &
              "is outside the target subtype range.",
            Evidence => "value range is outside the target subtype range");
      elsif Config.Verification_Mode then
         if Definitely_Inside_Type (Value, Typ, State) then
            --  proof-path: range-abstract
            Record_Proved_Safe
              (Unit, Value, Proof.Range_Check, Proof.Abstract_Interpretation,
               "value range is contained in the target subtype range",
               "value bounds are within target bounds", Final => Final);
         else
            declare
               Outcome : constant VC.VC_Outcome :=
                 VC.Decide_Bounds
                   (Value, Type_Range (Typ, State), State, Symbols);
            begin
               case Outcome.Result is
                  when VC.VC_Proved =>
                     --  proof-path: range-external
                     Record_Proved_Safe
                       (Unit, Value, Proof.Range_Check,
                        Proof.External_Prover,
                        "scalar verification condition proves the value is " &
                          "inside the target subtype range",
                        VC.Evidence, Final => Final);
                  when VC.VC_Refuted =>
                     Record_Definite_Error
                       (Unit, Value, Proof.Range_Check,
                        Proof.External_Prover, Message, VC.Evidence,
                        Final => Final);
                     Report.Report_Rule_Violation
                       (Unit, Value, Rule, Message,
                        Explanation =>
                          "The scalar verification condition establishes " &
                          "that the value cannot satisfy the target subtype " &
                          "bounds.",
                        Evidence => VC.Evidence);
                  when others =>
                     Record_VC_Unproved
                       (Unit, Value, Proof.Range_Check,
                        Proof.Abstract_Interpretation,
                        "range-check failure is not established, but " &
                          "absence is not proved",
                        "the current non-relational range domain is " &
                          "inconclusive",
                        Outcome, Final => Final);
               end case;
            end;
         end if;
      else
         Record_Unproved
           (Unit, Value, Proof.Range_Check, Proof.Abstract_Interpretation,
            "range-check failure is not established, but absence is not " &
              "proved",
            Imprecision =>
              "the current non-relational range domain is inconclusive",
            Final => Final);
      end if;
   end Check_Value_Range;

   function Assoc_Expression
     (List : Libadalang.Analysis.Ada_Node'Class;
      Index : Positive) return Libadalang.Analysis.Expr is
   begin
      if Libadalang.Analysis.Is_Null (List) then
         return Libadalang.Analysis.No_Expr;
      end if;

      --  Libadalang represents a single positional suffix directly as an
      --  expression, and uses an association list for multiple or named
      --  actuals/indices.
      if List.Kind in Libadalang.Common.Ada_Expr then
         return
           (if Index = 1 then List.As_Expr
            else Libadalang.Analysis.No_Expr);
      elsif List.Children_Count < Index then
         return Libadalang.Analysis.No_Expr;
      end if;
      if List.Child (Index).Kind = Libadalang.Common.Ada_Param_Assoc then
         return List.Child (Index).As_Param_Assoc.F_R_Expr;
      elsif List.Child (Index).Kind in Libadalang.Common.Ada_Base_Assoc then
         return List.Child (Index).As_Base_Assoc.P_Assoc_Expr;
      else
         return Libadalang.Analysis.No_Expr;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Assoc_Expression;

   --  Checked separately from Check_Conversion_Or_Index so Verify_Subprogram's
   --  Finalize_Node can replay the same determination against a CFG node's
   --  own fully-converged State, marked Final (see FP-035, following
   --  FP-031/FP-034's Ada_Identifier/Range_Check fixes).
   procedure Check_Index_Range
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Index_Value : Libadalang.Analysis.Expr'Class;
      Bounds      : Abstract_Range;
      State       : Flow_State;
      Symbols     : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final       : Boolean := False)
   is
   begin
      if Definitely_Outside_Range (Index_Value, Bounds, State) then
         Record_Definite_Error
           (Unit, Index_Value, Proof.Index_Check, Proof.Abstract_Interpretation,
            "index is outside the array index subtype",
            "index range is outside the array bounds", Final => Final);
         Report.Report_Rule_Violation
           (Unit, Index_Value, Rules.Known_Index_Check_Failure,
            "index is outside the array index subtype",
            Explanation =>
              "Abstract interpretation found that every represented " &
              "index value is outside the array bounds.",
            Evidence => "index range is outside the array bounds");
      elsif Config.Verification_Mode then
         if Definitely_Inside_Range (Index_Value, Bounds, State) then
            --  proof-path: index-abstract
            Record_Proved_Safe
              (Unit, Index_Value, Proof.Index_Check,
               Proof.Abstract_Interpretation,
               "index range is contained in the array index bounds",
               "index bounds are within array bounds", Final => Final);
         else
            declare
               Outcome : constant VC.VC_Outcome :=
                 VC.Decide_Bounds (Index_Value, Bounds, State, Symbols);
            begin
               case Outcome.Result is
                  when VC.VC_Proved =>
                     --  proof-path: index-external
                     Record_Proved_Safe
                       (Unit, Index_Value, Proof.Index_Check,
                        Proof.External_Prover,
                        "scalar verification condition proves the index is " &
                          "inside the array bounds",
                        VC.Evidence, Final => Final);
                  when VC.VC_Refuted =>
                     Record_Definite_Error
                       (Unit, Index_Value, Proof.Index_Check,
                        Proof.External_Prover,
                        "index is outside the array index subtype",
                        VC.Evidence, Final => Final);
                     Report.Report_Rule_Violation
                       (Unit, Index_Value,
                        Rules.Known_Index_Check_Failure,
                        "index is outside the array index subtype",
                        Explanation =>
                          "The scalar verification condition establishes " &
                          "that the index cannot satisfy the array bounds.",
                        Evidence => VC.Evidence);
                  when others =>
                     Record_VC_Unproved
                       (Unit, Index_Value, Proof.Index_Check,
                        Proof.Abstract_Interpretation,
                        "index-check failure is not established, but " &
                          "absence is not proved",
                        "index and bound ranges remain inconclusive",
                        Outcome, Final => Final);
               end case;
            end;
         end if;
      else
         Record_Unproved
           (Unit, Index_Value, Proof.Index_Check, Proof.Abstract_Interpretation,
            "index-check failure is not established, but absence is not " &
              "proved",
            Imprecision => "index and bound ranges remain inconclusive",
            Final => Final);
      end if;
   end Check_Index_Range;

   procedure Check_Conversion_Or_Index
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Call  : Libadalang.Analysis.Call_Expr;
      State : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State)
   is
   begin
      case Call.P_Kind is
         when Libadalang.Common.Type_Conversion =>
            declare
               Decl  : constant Libadalang.Analysis.Basic_Decl :=
                 Call.F_Name.P_Referenced_Decl;
               Value : constant Libadalang.Analysis.Expr :=
                 Assoc_Expression (Call.F_Suffix, 1);
            begin
               if not Libadalang.Analysis.Is_Null (Decl)
                 and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
                 and then not Libadalang.Analysis.Is_Null (Value)
               then
                  Check_Value_Range
                    (Unit, Value, Decl.As_Base_Type_Decl, State,
                     Rules.Known_Range_Check_Failure,
                     "value is outside the target subtype range", Symbols);

                  if Config.Rule_States (Rules.Redundant_Type_Conversion) =
                       Config.Enabled
                  then
                     declare
                        Value_Type : constant
                          Libadalang.Analysis.Base_Type_Decl :=
                            Value.P_Expression_Type;
                     begin
                        if not Libadalang.Analysis.Is_Null (Value_Type)
                          and then Libadalang.Analysis.Ada_Node (Value_Type) =
                            Libadalang.Analysis.Ada_Node
                              (Decl.As_Base_Type_Decl)
                        then
                           Report.Report_Rule_Violation
                             (Unit, Call, Rules.Redundant_Type_Conversion,
                              "conversion has no effect because the " &
                                "operand already has this type");
                        end if;
                     end;
                  end if;
               end if;
            end;

         when Libadalang.Common.Array_Index =>
            declare
               Array_Type : constant Libadalang.Analysis.Base_Type_Decl :=
                 Call.F_Name.P_Expression_Type;
            begin
               if not Libadalang.Analysis.Is_Null (Array_Type)
                 and then Array_Type.P_Is_Array_Type
               then
                  declare
                     Dimensions : constant Positive :=
                       (if Call.F_Suffix.Kind in Libadalang.Common.Ada_Expr
                        then 1 else Call.F_Suffix.Children_Count);
                  begin
                     for Dim in 1 .. Dimensions loop
                        declare
                           Index_Value : constant Libadalang.Analysis.Expr :=
                             Assoc_Expression (Call.F_Suffix, Dim);
                           Bounds : constant Abstract_Range :=
                             Array_Index_Range (Array_Type, Dim, State);
                        begin
                           if Config.Rule_States
                                (Rules.Known_Index_Check_Failure) =
                                  Config.Enabled
                             and then not Libadalang.Analysis.Is_Null
                               (Index_Value)
                           then
                              Check_Index_Range
                                (Unit, Index_Value, Bounds, State, Symbols);
                           end if;
                        end;
                     end loop;
                  end;
               end if;
            end;

         when others =>
            null;
      end case;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("skipping conversion/index check: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Check_Conversion_Or_Index;

   --  Checked separately from Scan_Expression_For_Flow_Bugs so
   --  Verify_Subprogram's Finalize_Node can replay the same determination
   --  against a CFG node's own fully-converged State, marked Final (see
   --  FP-036, following FP-031/FP-034/FP-035's earlier fixes).
   procedure Check_Division_By_Zero
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Expr  : Libadalang.Analysis.Bin_Op;
      State : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final : Boolean := False)
   is
      Right       : constant Abstract_Int :=
        Integer_Value (Expr.F_Right, State);
      Right_Range : constant Abstract_Range :=
        Range_Value (Expr.F_Right, State);
   begin
      if Expr.F_Op not in Libadalang.Common.Ada_Op_Div
          | Libadalang.Common.Ada_Op_Mod
          | Libadalang.Common.Ada_Op_Rem
      then
         return;
      end if;

      if Right.Known and then Right.Value = 0 then
         Record_Definite_Error
           (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
            Proof.Abstract_Interpretation,
            "right operand is zero in the incoming abstract state",
            "right operand => 0", Final => Final);
         if not Is_Static_Zero (Expr.F_Right) then
            Report.Report_Rule_Violation
              (Unit, Expr.F_Right, Rules.Division_By_Zero,
               "right operand is zero here based on an earlier assignment",
               Explanation =>
                 "Flow analysis propagated the assigned value to this " &
                 "operation without an intervening write.",
               Evidence => "right operand => 0");
         end if;
      elsif Config.Verification_Mode then
         if (Right_Range.Has_High and then Right_Range.High < 0)
           or else (Right_Range.Has_Low and then Right_Range.Low > 0)
         then
            --  proof-path: division-abstract
            Record_Proved_Safe
              (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
               Proof.Abstract_Interpretation,
               "right operand range excludes zero",
               "right operand is strictly negative or positive",
               Final => Final);
         else
            declare
               Outcome : constant VC.VC_Outcome :=
                 VC.Decide_Nonzero (Expr.F_Right, State, Symbols);
            begin
               case Outcome.Result is
                  when VC.VC_Proved =>
                     --  proof-path: division-external
                     Record_Proved_Safe
                       (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
                        Proof.External_Prover,
                        "scalar verification condition proves the divisor " &
                          "is nonzero",
                        VC.Evidence, Final => Final);
                  when VC.VC_Refuted =>
                     Record_Definite_Error
                       (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
                        Proof.External_Prover,
                        "right operand is zero in every represented state",
                        VC.Evidence, Final => Final);
                     Report.Report_Rule_Violation
                       (Unit, Expr.F_Right, Rules.Division_By_Zero,
                        "right operand is zero here",
                        Explanation =>
                          "The scalar verification condition establishes " &
                          "that the divisor is zero.",
                        Evidence => VC.Evidence);
                  when others =>
                     Record_VC_Unproved
                       (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
                        Proof.Abstract_Interpretation,
                        "zero has not been excluded from the divisor",
                        "the divisor range is unknown or contains zero",
                        Outcome, Final => Final);
               end case;
            end;
         end if;
      else
         Record_Unproved
           (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
            Proof.Abstract_Interpretation,
            "zero has not been excluded from the divisor",
            Imprecision => "the divisor range is unknown or contains zero",
            Final => Final);
      end if;
   end Check_Division_By_Zero;

   --  As Check_Division_By_Zero, for Integer_Overflow_Check.
   procedure Check_Integer_Overflow
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Bin_Op;
      State : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final : Boolean := False)
   is
   begin
      if Node.F_Op not in
        Libadalang.Common.Ada_Op_Plus
          | Libadalang.Common.Ada_Op_Minus
          | Libadalang.Common.Ada_Op_Mult
          | Libadalang.Common.Ada_Op_Div
          | Libadalang.Common.Ada_Op_Pow
      then
         return;
      end if;

      declare
         Expr_Type : constant Libadalang.Analysis.Base_Type_Decl :=
           Node.As_Expr.P_Expression_Type;
      begin
         if not Libadalang.Analysis.Is_Null (Expr_Type)
           and then Expr_Type.P_Is_Int_Type
         then
            if Known_Arithmetic_Overflow (Node.As_Expr, State) then
               Record_Definite_Error
                 (Unit, Node, Proof.Integer_Overflow_Check,
                  Proof.Abstract_Interpretation,
                  "arithmetic result is outside its base type range",
                  "result range is outside the operation's base type",
                  Final => Final);
               Report.Report_Rule_Violation
                 (Unit, Node, Rules.Known_Overflow_Failure,
                  "arithmetic result is outside its base type range",
                  Explanation =>
                    "Abstract interpretation found that every represented " &
                    "result is outside the operation's base type.",
                  Evidence =>
                    "result range is outside the operation's base type");
            elsif Config.Verification_Mode then
               if Arithmetic_Proved_Safe (Node.As_Expr, State) then
                  --  proof-path: overflow-abstract
                  Record_Proved_Safe
                    (Unit, Node, Proof.Integer_Overflow_Check,
                     Proof.Abstract_Interpretation,
                     "arithmetic result range is inside its base type",
                     "result bounds are within base-type bounds",
                     Final => Final);
               else
                  declare
                     Bounds : Abstract_Range :=
                       Overflow_Base_Range (Expr_Type, Node, State);
                     Name : constant String := Langkit_Support.Text.To_UTF8
                       (Expr_Type.P_Canonical_Fully_Qualified_Name);
                  begin
                     if not Bounds.Has_Low
                       and then not Bounds.Has_High
                       and then Name = "standard.integer"
                     then
                        Bounds := Type_Range (Expr_Type, State);
                     end if;

                     declare
                        Outcome : constant VC.VC_Outcome :=
                          VC.Decide_Bounds
                            (Node.As_Expr, Bounds, State, Symbols);
                     begin
                        case Outcome.Result is
                           when VC.VC_Proved =>
                              --  proof-path: overflow-external
                              Record_Proved_Safe
                                (Unit, Node, Proof.Integer_Overflow_Check,
                                 Proof.External_Prover,
                                 "scalar verification condition proves the " &
                                   "arithmetic result fits its base type",
                                 VC.Evidence, Final => Final);
                           when VC.VC_Refuted =>
                              Record_Definite_Error
                                (Unit, Node, Proof.Integer_Overflow_Check,
                                 Proof.External_Prover,
                                 "arithmetic result is outside its base " &
                                   "type range",
                                 VC.Evidence, Final => Final);
                              Report.Report_Rule_Violation
                                (Unit, Node,
                                 Rules.Known_Overflow_Failure,
                                 "arithmetic result is outside its base " &
                                   "type range",
                                 Explanation =>
                                   "The scalar verification condition " &
                                   "establishes that the arithmetic result " &
                                   "cannot fit in its base type.",
                                 Evidence => VC.Evidence);
                           when others =>
                              Record_VC_Unproved
                                (Unit, Node,
                                 Proof.Integer_Overflow_Check,
                                 Proof.Abstract_Interpretation,
                                 "overflow is not established, but absence " &
                                   "is not proved",
                                 "the current range domain does not certify " &
                                   "the result",
                                 Outcome, Final => Final);
                        end case;
                     end;
                  end;
               end if;
            else
               Record_Unproved
                 (Unit, Node, Proof.Integer_Overflow_Check,
                  Proof.Abstract_Interpretation,
                  "overflow is not established, but absence is not proved",
                  Imprecision =>
                    "the current range domain does not certify the result",
                  Final => Final);
            end if;
         end if;
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Known_Overflow_Failure",
               Operation  => "evaluate arithmetic result bounds",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end;
   end Check_Integer_Overflow;

   --  Reports Division_By_Zero for every "/", "mod", or "rem" under Node
   --  whose right operand is only known to be zero once State's earlier
   --  assignments are taken into account (a plain literal zero is already
   --  caught by the node-local checks, so this only adds cases those
   --  would miss).
   procedure Scan_Expression_For_Flow_Bugs
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Config.Verification_Mode
        and then Node.Kind = Libadalang.Common.Ada_Identifier
        and then Initialization_Read_Required (Node)
      then
         declare
            Key     : constant Libadalang.Analysis.Ada_Node :=
              Flow_Referenced_Name (Node);
            Current : Libadalang.Analysis.Ada_Node := Key;
            Tracked : Boolean := False;
         begin
            while not Libadalang.Analysis.Is_Null (Current) loop
               if Current.Kind in Libadalang.Common.Ada_Object_Decl_Range
                 or else Current.Kind in
                   Libadalang.Common.Ada_Param_Spec_Range
               then
                  Tracked := True;
                  exit;
               elsif Current.Kind in Libadalang.Common.Ada_Basic_Decl then
                  exit;
               end if;
               Current := Current.Parent;
            end loop;

            if Tracked then
               case Flow_Initialization (State, Key) is
                  when Bool_True =>
                     --  proof-path: initialization-live
                     Record_Proved_Safe
                       (Unit, Node, Proof.Initialization_Check,
                        Proof.Flow_Analysis,
                        "object is initialized on every incoming path",
                        "initialization => true");
                  when Bool_False =>
                     Record_Definite_Error
                       (Unit, Node, Proof.Initialization_Check,
                        Proof.Flow_Analysis,
                        "object is uninitialized on every incoming path",
                        "initialization => false");
                  when Bool_Unknown =>
                     Record_Unproved
                       (Unit, Node, Proof.Initialization_Check,
                        Proof.Flow_Analysis,
                        "object initialization is not established",
                        Imprecision =>
                          "incoming paths disagree or object is external");
               end case;
            end if;
         exception
            when E : others =>
               Report_Recoverable_Failure_Once
                 (Rule       => "Initialization_Check",
                  Operation  => "classify identifier initialization",
                  Source     => Ada_Text.Safe_Filename (Unit),
                  Occurrence => E);
         end;
      end if;

      if Config.Rule_States (Rules.Division_By_Zero) = Config.Enabled
        and then Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
      then
         Check_Division_By_Zero
           (Unit, Node.As_Bin_Op, State, Symbols);
      end if;

      if Config.Rule_States (Rules.Known_Overflow_Failure) = Config.Enabled
        and then Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
      then
         Check_Integer_Overflow
           (Unit, Node.As_Bin_Op, State, Symbols);
      end if;

      if Node.Kind = Libadalang.Common.Ada_Call_Expr then
         declare
            Call : constant Libadalang.Analysis.Call_Expr :=
              Node.As_Call_Expr;
         begin
            Check_Conversion_Or_Index (Unit, Call, State, Symbols);
            Check_Call_Precondition
              (Unit, Call.F_Name, State, Symbols);

            --  An out-only actual is a destination, not a read. Walking the
            --  raw call subtree would classify an uninitialized outer out
            --  parameter as read when it is forwarded directly to another
            --  out parameter. Use the resolved formal/actual mapping for
            --  ordinary calls; in-out and input actuals still get scanned.
            if Call.P_Kind = Libadalang.Common.Call then
               begin
                  Scan_Expression_For_Flow_Bugs
                    (Unit, Call.F_Name, State, Symbols);
                  for Pair of Call.F_Name.P_Call_Params loop
                     if Formal_Mode (Libadalang.Analysis.Param (Pair)) /=
                       Libadalang.Common.Ada_Mode_Out
                       or else Libadalang.Analysis.Actual (Pair).Kind /=
                         Libadalang.Common.Ada_Identifier
                     then
                        Scan_Expression_For_Flow_Bugs
                          (Unit, Libadalang.Analysis.Actual (Pair), State,
                           Symbols);
                     end if;
                  end loop;
                  return;
               exception
                  when others =>
                     --  If semantic parameter resolution is unavailable,
                     --  retain the conservative raw-tree scan below.
                     null;
               end;
            end if;
         end;
      end if;

      for I in 1 .. Node.Children_Count loop
         Scan_Expression_For_Flow_Bugs
           (Unit, Node.Child (I), State, Symbols);
      end loop;
   end Scan_Expression_For_Flow_Bugs;

   --  Reports Constant_Condition for Cond when State's earlier assignments
   --  resolve it to a known value that plain literal evaluation (no state)
   --  could not -- the literal-only case is already handled at the call
   --  site that also reports Non_Short_Circuit_Condition.
   procedure Check_Flow_Condition
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Cond  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State)
   is
   begin
      if Config.Rule_States (Rules.Constant_Condition) /= Config.Enabled
        or else Libadalang.Analysis.Is_Null (Cond)
        or else Boolean_Value (Cond) /= Bool_Unknown
      then
         return;
      end if;

      declare
         Flow_Value : constant Abstract_Bool := Boolean_Value (Cond, State);
      begin
         if Flow_Value /= Bool_Unknown then
            Report.Report_Rule_Violation
              (Unit, Cond, Rules.Constant_Condition,
               "condition is always " & Bool_Name (Flow_Value) &
                 " based on an earlier assignment");
         end if;
      end;
   end Check_Flow_Condition;

   --  The condition carried by a proof-related pragma. Check uses its
   --  second argument (the first is the check kind); assertion pragmas and
   --  Assume use their first argument.
   function Pragma_Condition
     (Pragma_Node : Libadalang.Analysis.Pragma_Node)
      return Libadalang.Analysis.Expr
   is
      Name  : constant String := Normalized_Text (Pragma_Node.F_Id);
      Index : Positive := 1;
   begin
      if Name = "check" then
         Index := 2;
      elsif Name /= "assert"
        and then Name /= "assert-and-cut"
        and then Name /= "loop-invariant"
        and then Name /= "assume"
      then
         return Libadalang.Analysis.No_Expr;
      end if;

      if Pragma_Node.F_Args.Children_Count < Index then
         return Libadalang.Analysis.No_Expr;
      end if;

      return Pragma_Node.F_Args.Child (Index).As_Pragma_Argument_Assoc.P_Assoc_Expr;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Pragma_Condition;

   function Verification_Pragma_Condition
     (Pragma_Node : Libadalang.Analysis.Pragma_Node)
      return Libadalang.Analysis.Expr
   is
   begin
      if Normalized_Text (Pragma_Node.F_Id) /= "loop-variant" then
         return Pragma_Condition (Pragma_Node);
      elsif Pragma_Node.F_Args.Children_Count = 0 then
         return Libadalang.Analysis.No_Expr;
      else
         return
           Pragma_Node.F_Args.Child (1)
             .As_Pragma_Argument_Assoc.P_Assoc_Expr;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Verification_Pragma_Condition;

   function Contains_VC_Arithmetic
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      elsif Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
        and then Node.As_Bin_Op.F_Op in
          Libadalang.Common.Ada_Op_Plus
            | Libadalang.Common.Ada_Op_Minus
            | Libadalang.Common.Ada_Op_Mult
            | Libadalang.Common.Ada_Op_Div
      then
         --  "/" joins "+"/"-"/"*" here for the same reason: its SMT
         --  translation is unbounded-integer arithmetic, so a refutation
         --  could be an artifact of ignoring machine-width overflow (e.g.
         --  Integer'First / -1) rather than a genuine Ada assertion
         --  failure. "mod"/"rem" are deliberately excluded: their result
         --  magnitude never exceeds the (already provably nonzero, see
         --  Divisor_Provably_Nonzero in vc_prover.adb) divisor, so they
         --  carry no such overflow risk and a refutation on them alone is
         --  trustworthy.
         return True;
      elsif Node.Kind = Libadalang.Common.Ada_Un_Op
        and then Node.As_Un_Op.F_Op in
          Libadalang.Common.Ada_Op_Minus | Libadalang.Common.Ada_Op_Abs
      then
         return True;
      end if;

      for Index in 1 .. Node.Children_Count loop
         if Contains_VC_Arithmetic (Node.Child (Index)) then
            return True;
         end if;
      end loop;
      return False;
   end Contains_VC_Arithmetic;

   --  Checked separately from Interpret_Proof_Pragma so Verify_Subprogram's
   --  Finalize_Node can replay the same determination against a CFG node's
   --  own fully-converged State, marked Final (see FP-032, following
   --  FP-031/FP-034's Ada_Identifier/Range_Check fixes).
   procedure Check_Proof_Pragma_Assertion
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      Cond    : Libadalang.Analysis.Expr;
      State   : Flow_State;
      Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Final   : Boolean := False)
   is
   begin
      if Config.Rule_States (Rules.Known_Assertion_Failure) /=
        Config.Enabled
      then
         return;
      end if;

      declare
         Value     : constant Abstract_Bool := Boolean_Value (Cond, State);
         VC_Outcome : constant VC.VC_Outcome :=
           (if Config.Verification_Mode and then Value = Bool_Unknown
            then VC.Decide (Cond, State, Symbols) else VC.Unknown_Outcome);
         VC_Result : constant VC.VC_Result := VC_Outcome.Result;
      begin
         if Value = Bool_False
           or else
             (VC_Result = VC.VC_Refuted
              and then not Contains_VC_Arithmetic (Cond))
         then
            Record_Definite_Error
              (Unit, Cond, Proof.Assertion_Check,
               (if VC_Result = VC.VC_Refuted
                then Proof.External_Prover
                else Proof.Abstract_Interpretation),
               "assertion condition is false based on the incoming state",
               (if VC_Result = VC.VC_Refuted
                then VC.Evidence
                else "assertion condition => false"),
               Final => Final);
            if Boolean_Value (Cond) = Bool_Unknown then
               Report.Report_Rule_Violation
                 (Unit, Cond, Rules.Known_Assertion_Failure,
                  "assertion condition is false here based on earlier " &
                    "state",
                  Explanation =>
                    "The incoming flow state makes the assertion " &
                    "condition False.",
                  Evidence =>
                    (if VC_Result = VC.VC_Refuted
                     then VC.Evidence
                     else "assertion condition => false"));
            end if;
         elsif Config.Verification_Mode
           and then
             (Value = Bool_True or else VC_Result = VC.VC_Proved)
         then
            --  proof-path: assertion-decision
            Record_Proved_Safe
              (Unit, Cond, Proof.Assertion_Check,
               (if VC_Result = VC.VC_Proved
                then Proof.External_Prover
                else Proof.Abstract_Interpretation),
               (if VC_Result = VC.VC_Proved
                then "scalar verification condition proved by the " &
                  "external prover portfolio"
                else "assertion condition is true in the incoming state"),
               (if VC_Result = VC.VC_Proved
                then VC.Evidence
                else "assertion condition => true"),
               Final => Final);
         else
            Record_VC_Unproved
              (Unit, Cond, Proof.Assertion_Check,
               Proof.Abstract_Interpretation,
               "assertion failure is not established, but the assertion " &
                 "is not proved",
               "abstract interpretation and the scalar VC portfolio did " &
                 "not certify it",
               VC_Outcome,
               Final => Final);
         end if;
      end;
   end Check_Proof_Pragma_Assertion;

   function Interpret_Proof_Pragma
     (Unit        : Libadalang.Analysis.Analysis_Unit;
      Pragma_Node : Libadalang.Analysis.Pragma_Node;
      State       : Flow_State;
      Symbols     : VC.Symbolic_State := VC.Empty_Symbolic_State)
      return Flow_State
   is
      Name   : constant String := Normalized_Text (Pragma_Node.F_Id);
      Cond   : constant Libadalang.Analysis.Expr :=
        Pragma_Condition (Pragma_Node);
      Result : Flow_State := State;
   begin
      if Libadalang.Analysis.Is_Null (Cond) then
         return Result;
      end if;

      Scan_Expression_For_Flow_Bugs (Unit, Cond, State, Symbols);

      if Name /= "assume" then
         Check_Proof_Pragma_Assertion (Unit, Cond, State, Symbols);
      end if;

      --  Execution continues only when an assertion succeeds. Assume has
      --  the same state-narrowing effect without generating an obligation.
      declare
         True_State, False_State : Flow_State;
      begin
         Narrow_By_Condition (Cond, State, True_State, False_State);
         Result := True_State;
      end;
      return Result;
   end Interpret_Proof_Pragma;

   --  Seeds State from every "Name : T := Default;" in Decls, when Default
   --  statically evaluates (possibly using State itself, so an earlier
   --  constant can feed a later one's initializer).
   procedure Seed_Declarations
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Decls : Libadalang.Analysis.Declarative_Part;
      State : in out Flow_State)
   is
   begin
      if Libadalang.Analysis.Is_Null (Decls) then
         return;
      end if;

      for I in 1 .. Decls.F_Decls.Children_Count loop
         declare
            Item : constant Libadalang.Analysis.Ada_Node :=
              Decls.F_Decls.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Item)
              and then Item.Kind = Libadalang.Common.Ada_Object_Decl
            then
               declare
                  Decl    : constant Libadalang.Analysis.Object_Decl :=
                    Item.As_Object_Decl;
                  Default : constant Libadalang.Analysis.Expr :=
                    Decl.F_Default_Expr;
               begin
                  if not Libadalang.Analysis.Is_Null (Default) then
                     Scan_Expression_For_Flow_Bugs (Unit, Default, State);
                     Check_Value_Range
                       (Unit, Default,
                        Decl.F_Type_Expr.P_Designated_Type_Decl,
                        State, Rules.Known_Range_Check_Failure,
                        "initial value is outside the object's subtype range");

                     declare
                        Value      : constant Abstract_Int :=
                          Integer_Value (Default, State);
                        Bool_Value : constant Abstract_Bool :=
                          Boolean_Value (Default, State);
                     begin
                        for Id of Decl.F_Ids loop
                           Flow_Set_Initialized
                             (State, Libadalang.Analysis.Ada_Node (Id),
                              Bool_True);
                           if Value.Known then
                              Flow_Set
                                (State,
                                 Libadalang.Analysis.Ada_Node (Id), Value);
                           end if;

                           if Bool_Value /= Bool_Unknown then
                              Flow_Bool_Set
                                (State,
                                 Libadalang.Analysis.Ada_Node (Id),
                                 Bool_Value);
                           end if;
                        end loop;
                     end;
                  else
                     declare
                        Initialized : constant Abstract_Bool :=
                          Implicit_Initialization (Decl, State);
                     begin
                        for Id of Decl.F_Ids loop
                           Flow_Set_Initialized
                             (State, Libadalang.Analysis.Ada_Node (Id),
                              Initialized);
                        end loop;
                     end;
                  end if;
               end;
            end if;
         end;
      end loop;
   end Seed_Declarations;

   --  The outcome of interpreting a statement or statement list: the
   --  resulting Flow_State, and whether control can fall through to
   --  whatever follows (False once a return, raise, or unconditional exit
   --  has been seen).
   type Flow_Result is record
      State      : Flow_State;
      Terminated : Boolean;
   end record;

   --  Combines two branches reaching the same merge point. A branch that
   --  terminates contributes nothing to the merged state; if both do, the
   --  merge point itself is unreachable, which is reported by other checks,
   --  not this one -- Empty_Flow_State here is just an inert placeholder.
   function Join_Results (Left, Right : Flow_Result) return Flow_Result is
   begin
      if Left.Terminated and then Right.Terminated then
         return (State => Empty_Flow_State, Terminated => True);
      elsif Left.Terminated then
         return (State => Right.State, Terminated => False);
      elsif Right.Terminated then
         return (State => Left.State, Terminated => False);
      else
         return
           (State => Flow_Join (Left.State, Right.State),
            Terminated => False);
      end if;
   end Join_Results;

   --  Forward declaration: Interpret_Else_Chain, Interpret_If, and
   --  Interpret_Loop all call back into Interpret_Statements, which is
   --  defined after Interpret_Statement further below.
   function Interpret_Statements
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      List  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result;

   --  Interprets Stmt.F_Alternatives (I .. end) and Stmt.F_Else_Part as one
   --  chain of conditions, since each elsif is semantically nested inside
   --  the previous condition's negation. State already carries every prior
   --  condition's false-narrowing (from Interpret_If or an earlier level of
   --  this same chain), so a later elsif's own narrowing compounds on top.
   function Interpret_Else_Chain
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.If_Stmt;
      Index : Positive;
      State : Flow_State) return Flow_Result
   is
      Alternatives : constant Libadalang.Analysis.Elsif_Stmt_Part_List :=
        Stmt.F_Alternatives;
   begin
      if Index > Alternatives.Children_Count then
         if Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
            return (State => State, Terminated => False);
         else
            return
              Interpret_Statements (Unit, Stmt.F_Else_Part.F_Stmts, State);
         end if;
      end if;

      declare
         Alt  : constant Libadalang.Analysis.Elsif_Stmt_Part :=
           Alternatives.Child (Index).As_Elsif_Stmt_Part;
         Cond : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
      begin
         Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
         Check_Flow_Condition (Unit, Cond, State);

         declare
            Cond_Value              : constant Abstract_Bool :=
              Boolean_Value (Cond, State);
            True_State, False_State : Flow_State;
         begin
            Narrow_By_Condition (Cond, State, True_State, False_State);

            if Cond_Value = Bool_True then
               return Interpret_Statements (Unit, Alt.F_Stmts, True_State);
            elsif Cond_Value = Bool_False then
               return
                 Interpret_Else_Chain (Unit, Stmt, Index + 1, False_State);
            else
               return Join_Results
                 (Interpret_Statements (Unit, Alt.F_Stmts, True_State),
                  Interpret_Else_Chain (Unit, Stmt, Index + 1, False_State));
            end if;
         end;
      end;
   end Interpret_Else_Chain;

   --  Interprets an if statement: picks the live branch when the condition
   --  resolves (via State) to a known value, otherwise interprets both
   --  branches from copies of the entering State (narrowed, where the
   --  condition has a recognizable shape, by Narrow_By_Condition) and joins
   --  the results.
   function Interpret_If
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.If_Stmt;
      State : Flow_State) return Flow_Result
   is
      Cond : constant Libadalang.Analysis.Expr := Stmt.F_Cond_Expr;
   begin
      Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
      Check_Flow_Condition (Unit, Cond, State);

      declare
         Cond_Value               : constant Abstract_Bool :=
           Boolean_Value (Cond, State);
         True_State, False_State  : Flow_State;
      begin
         Narrow_By_Condition (Cond, State, True_State, False_State);

         if Cond_Value = Bool_True then
            return Interpret_Statements (Unit, Stmt.F_Then_Stmts, True_State);
         elsif Cond_Value = Bool_False then
            return Interpret_Else_Chain (Unit, Stmt, 1, False_State);
         end if;

         return Join_Results
           (Interpret_Statements (Unit, Stmt.F_Then_Stmts, True_State),
            Interpret_Else_Chain (Unit, Stmt, 1, False_State));
      end;
   end Interpret_If;

   --  The Abstract_Range implied by a for-loop's iteration expression: the
   --  independently-known low/high bounds of a "Low .. High" range (the
   --  common shape for a numeric for loop). Anything else this pass
   --  doesn't specifically model (a subtype mark, a container iterator,
   --  an attribute reference, ...) yields Unknown_Range, which simply
   --  forgoes seeding the loop variable's range.
   function For_Loop_Range
     (Iter_Expr : Libadalang.Analysis.Ada_Node'Class;
      State     : Flow_State) return Abstract_Range
   is
   begin
      if Libadalang.Analysis.Is_Null (Iter_Expr)
        or else Iter_Expr.Kind /= Libadalang.Common.Ada_Bin_Op
        or else Iter_Expr.As_Bin_Op.F_Op /=
          Libadalang.Common.Ada_Op_Double_Dot
      then
         return Unknown_Range;
      end if;

      declare
         Low    : constant Abstract_Int :=
           Integer_Value (Iter_Expr.As_Bin_Op.F_Left, State);
         High   : constant Abstract_Int :=
           Integer_Value (Iter_Expr.As_Bin_Op.F_Right, State);
         Result : Abstract_Range;
      begin
         if Low.Known then
            Result.Has_Low := True;
            Result.Low := Low.Value;
         end if;

         if High.Known then
            Result.Has_High := True;
            Result.High := High.Value;
         end if;

         return Result;
      end;
   end For_Loop_Range;

   --  Interprets a loop: every variable assigned anywhere in the body (and
   --  every actual parameter of any call within it) is havoced before the
   --  body is interpreted once, since a later iteration could reach any
   --  point in the body with that variable already reassigned -- without
   --  this, a variable's pre-loop value would wrongly look like it still
   --  held after a reassignment later in the same loop body. The state
   --  after the loop is the join of "never entered" and "ran the body",
   --  since a while/for loop may execute zero times. A while loop's body is
   --  additionally entered from the condition's true-narrowing (still
   --  havoced afterward for anything the body itself reassigns), and a for
   --  loop's own control variable is seeded with its statically known
   --  range, when it has one.
   function Interpret_Loop
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
      Body_Stmts : constant Libadalang.Analysis.Stmt_List :=
        Stmt.As_Base_Loop_Stmt.F_Stmts;
      Havoced    : Flow_State := State;
   begin
      if Stmt.Kind = Libadalang.Common.Ada_While_Loop_Stmt then
         declare
            Spec : constant Libadalang.Analysis.Loop_Spec :=
              Stmt.As_While_Loop_Stmt.F_Spec;
         begin
            if not Libadalang.Analysis.Is_Null (Spec) then
               declare
                  Cond                     : constant Libadalang.Analysis.Expr
                    := Spec.As_While_Loop_Spec.F_Expr;
                  True_State, False_State  : Flow_State;
               begin
                  Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
                  Check_Flow_Condition (Unit, Cond, State);
                  Narrow_By_Condition (Cond, State, True_State, False_State);
                  Havoced := True_State;
               end;
            end if;
         end;
      end if;

      Havoc_Effects_In (Body_Stmts, Havoced);

      if Stmt.Kind = Libadalang.Common.Ada_For_Loop_Stmt then
         declare
            Spec : constant Libadalang.Analysis.For_Loop_Spec :=
              Stmt.As_For_Loop_Stmt.F_Spec.As_For_Loop_Spec;
         begin
            if Spec.F_Loop_Type.Kind = Libadalang.Common.Ada_Iter_Type_In then
               Flow_Range_Set
                 (Havoced,
                  Libadalang.Analysis.Ada_Node (Spec.F_Var_Decl.F_Id),
                  For_Loop_Range (Spec.F_Iter_Expr, State));
            end if;
         end;
      end if;

      declare
         Body_Result : constant Flow_Result :=
           Interpret_Statements (Unit, Body_Stmts, Havoced);
      begin
         return
           (State => Flow_Join (State, Body_Result.State),
            Terminated => False);
      end;
   end Interpret_Loop;

   --  Whether Selector (already confirmed Known) is covered by one of Alt's
   --  choices: Match when it provably is, No_Match when every choice
   --  resolved and none covers it, and Unknown when some choice couldn't be
   --  resolved (e.g. a named constant outside this pass's tracked state)
   --  and therefore might cover it. "when others" always matches, since
   --  Ada requires it to be the final, exclusive alternative.
   type Case_Match_Result is (Match, No_Match, Unknown_Match);

   function Case_Alternative_Match_Result
     (Alt      : Libadalang.Analysis.Case_Stmt_Alternative;
      Selector : Abstract_Int;
      State    : Flow_State) return Case_Match_Result
   is
      Saw_Unresolved_Choice : Boolean := False;
   begin
      for Choice of Alt.F_Choices loop
         if Choice.Kind = Libadalang.Common.Ada_Others_Designator then
            return Match;
         end if;

         declare
            Range_Value : constant Static_Interval :=
              Choice_Interval (Choice, State);
         begin
            if Range_Value.Known then
               if Selector.Value >= Range_Value.Low
                 and then Selector.Value <= Range_Value.High
               then
                  return Match;
               end if;
            else
               Saw_Unresolved_Choice := True;
            end if;
         end;
      end loop;

      if Saw_Unresolved_Choice then
         return Unknown_Match;
      else
         return No_Match;
      end if;
   end Case_Alternative_Match_Result;

   --  Interprets a case statement. When the selector's value is known from
   --  State, and every alternative up to and including the one that
   --  provably matches has fully resolvable choices, only that one
   --  alternative is interpreted (mirroring how Interpret_If picks a single
   --  branch). An alternative whose choices this pass can't fully resolve
   --  might itself be the true match, so encountering one before a proven
   --  match abandons the single-branch fast path entirely rather than risk
   --  skipping past the alternative that actually applies; the unresolved
   --  case then falls back, the same as an unknown selector, to
   --  interpreting every alternative from a copy of the entering State and
   --  joining the results, the same way an if statement's branches are
   --  joined.
   function Interpret_Case
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Case_Stmt;
      State : Flow_State) return Flow_Result
   is
      Alternatives : constant Libadalang.Analysis.Case_Stmt_Alternative_List :=
        Stmt.F_Alternatives;
      Selector     : constant Abstract_Int :=
        Integer_Value (Stmt.F_Expr, State);
   begin
      Scan_Expression_For_Flow_Bugs (Unit, Stmt.F_Expr, State);

      if Selector.Known then
         for I in 1 .. Alternatives.Children_Count loop
            declare
               Alt : constant Libadalang.Analysis.Case_Stmt_Alternative :=
                 Alternatives.Child (I).As_Case_Stmt_Alternative;
            begin
               case Case_Alternative_Match_Result (Alt, Selector, State) is
                  when Match =>
                     return Interpret_Statements (Unit, Alt.F_Stmts, State);
                  when No_Match =>
                     null;  --  adalang-analyzer: ignore Null_Statement
                  when Unknown_Match =>
                     exit;
               end case;
            end;
         end loop;
      end if;

      declare
         Result : Flow_Result := (State => State, Terminated => False);
         First  : Boolean := True;
      begin
         for I in 1 .. Alternatives.Children_Count loop
            declare
               Alt    : constant Libadalang.Analysis.Case_Stmt_Alternative :=
                 Alternatives.Child (I).As_Case_Stmt_Alternative;
               Branch : constant Flow_Result :=
                 Interpret_Statements (Unit, Alt.F_Stmts, State);
            begin
               if First then
                  Result := Branch;
                  First := False;
               else
                  Result := Join_Results (Result, Branch);
               end if;
            end;
         end loop;

         return Result;
      end;
   end Interpret_Case;

   --  Interprets a declare block: seeds its own local declarations'
   --  initializers into a copy of the entering State, then interprets its
   --  statements the same way a subprogram body's are (see
   --  Interpret_Subprogram_Flow). Skipped, the same conservative way, when
   --  the block has its own exception handlers.
   function Interpret_Decl_Block
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Block : Libadalang.Analysis.Decl_Block;
      State : Flow_State) return Flow_Result
   is
      Handled : constant Libadalang.Analysis.Handled_Stmts := Block.F_Stmts;
   begin
      if Libadalang.Analysis.Is_Null (Handled)
        or else Handled.F_Exceptions.Children_Count > 0
      then
         return (State => Empty_Flow_State, Terminated => False);
      end if;

      declare
         Seeded : Flow_State := State;
      begin
         Seed_Declarations (Unit, Block.F_Decls, Seeded);
         return Interpret_Statements (Unit, Handled.F_Stmts, Seeded);
      end;
   end Interpret_Decl_Block;

   --  Interprets one statement, threading State to the next. Anything not
   --  explicitly modeled here (select, accept, goto/label targets, ...)
   --  clears all tracked bindings rather than risk carrying a stale one
   --  across a construct this pass doesn't understand; Terminates_Statement
   --  still recognizes return/raise/goto/unconditional-exit so reachability
   --  past them is handled uniformly.
   function Interpret_Statement
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      Stmt  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
   begin
      case Stmt.Kind is
         when Libadalang.Common.Ada_Assign_Stmt =>
            declare
               Assign : constant Libadalang.Analysis.Assign_Stmt :=
                 Stmt.As_Assign_Stmt;
               Next   : Flow_State := State;
            begin
               Scan_Expression_For_Flow_Bugs (Unit, Assign.F_Expr, State);
               Check_Value_Range
                 (Unit, Assign.F_Expr,
                  Assign.F_Dest.P_Expression_Type,
                  State, Rules.Known_Range_Check_Failure,
                  "assigned value is outside the target subtype range");
               Havoc_Effects_In (Assign.F_Dest, Next);
               Havoc_Effects_In (Assign.F_Expr, Next);

               declare
                  Target     : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Assigned_Name (Stmt);
                  Value      : constant Abstract_Int :=
                    Integer_Value (Assign.F_Expr, State);
                  Bool_Value : constant Abstract_Bool :=
                    Boolean_Value (Assign.F_Expr, State);
                  Bounds     : constant Abstract_Range :=
                    Range_Value (Assign.F_Expr, State);
               begin
                  Flow_Set (Next, Target, Value);
                  Flow_Bool_Set (Next, Target, Bool_Value);
                  Flow_Range_Set (Next, Target, Bounds);
                  Flow_Set_Initialized (Next, Target, Bool_True);
               end;

               return (State => Next, Terminated => False);
            end;

         when Libadalang.Common.Ada_Call_Stmt =>
            declare
               Next : Flow_State := State;
               Call : constant Libadalang.Analysis.Name :=
                 Stmt.As_Call_Stmt.F_Call;
            begin
               Check_Call_Precondition (Unit, Call, State);
               Havoc_Global_Effects (Call, Next);
               Havoc_Call_Actuals (Call, Next);
               Apply_Call_Postcondition (Call, Next);
               return (State => Next, Terminated => False);
            end;

         when Libadalang.Common.Ada_If_Stmt =>
            return Interpret_If (Unit, Stmt.As_If_Stmt, State);

         when Libadalang.Common.Ada_Case_Stmt =>
            return Interpret_Case (Unit, Stmt.As_Case_Stmt, State);

         when Libadalang.Common.Ada_Decl_Block =>
            return Interpret_Decl_Block (Unit, Stmt.As_Decl_Block, State);

         when Libadalang.Common.Ada_While_Loop_Stmt
            | Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            return Interpret_Loop (Unit, Stmt, State);

         when Libadalang.Common.Ada_Pragma_Node =>
            return
              (State => Interpret_Proof_Pragma
                 (Unit, Stmt.As_Pragma_Node, State),
               Terminated => False);

         when Libadalang.Common.Ada_Null_Stmt
            | Libadalang.Common.Ada_Label =>
            return (State => State, Terminated => False);

         when Libadalang.Common.Ada_Exit_Stmt =>
            declare
               Cond : constant Libadalang.Analysis.Expr :=
                 Stmt.As_Exit_Stmt.F_Cond_Expr;
            begin
               if Libadalang.Analysis.Is_Null (Cond) then
                  return (State => State, Terminated => True);
               end if;

               Scan_Expression_For_Flow_Bugs (Unit, Cond, State);
               Check_Flow_Condition (Unit, Cond, State);
               return (State => State, Terminated => False);
            end;

         when others =>
            if Ada_Text.Terminates_Statement (Stmt) then
               return (State => State, Terminated => True);
            else
               return (State => Empty_Flow_State, Terminated => False);
            end if;
      end case;
   end Interpret_Statement;

   function Interpret_Statements
     (Unit  : Libadalang.Analysis.Analysis_Unit;
      List  : Libadalang.Analysis.Ada_Node'Class;
      State : Flow_State) return Flow_Result
   is
      Current : Flow_State := State;
   begin
      if Libadalang.Analysis.Is_Null (List) then
         return (State => Current, Terminated => False);
      end if;

      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Stmt) then
               declare
                  Step : constant Flow_Result :=
                    Interpret_Statement (Unit, Stmt, Current);
               begin
                  Current := Step.State;
                  if Step.Terminated then
                     return (State => Current, Terminated => True);
                  end if;
               end;
            end if;
         end;
      end loop;

      return (State => Current, Terminated => False);
   end Interpret_Statements;

   procedure Interpret_Subprogram_Flow
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      Handled : constant Libadalang.Analysis.Handled_Stmts :=
        Subprogram.F_Stmts;
   begin
      if Config.Verification_Mode
        or else
        (Config.Rule_States (Rules.Division_By_Zero) /= Config.Enabled
          and then Config.Rule_States (Rules.Constant_Condition) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Precondition_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Postcondition_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Assertion_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Range_Check_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Index_Check_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Known_Overflow_Failure) /=
            Config.Enabled
          and then Config.Rule_States (Rules.Redundant_Type_Conversion) /=
            Config.Enabled)
        or else Libadalang.Analysis.Is_Null (Handled)
        or else Handled.F_Exceptions.Children_Count > 0
      then
         return;
      end if;

      declare
         State  : Flow_State := Empty_Flow_State;
         Result : Flow_Result;
         Pre    : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Subprogram, "Pre");
         Post   : constant Libadalang.Analysis.Expr :=
           Contract_Expression (Subprogram, "Post");
      begin
         Seed_Declarations (Unit, Subprogram.F_Decls, State);

         if not Libadalang.Analysis.Is_Null (Pre) then
            declare
               True_State, False_State : Flow_State;
            begin
               Scan_Expression_For_Flow_Bugs (Unit, Pre, State);
               Narrow_By_Condition (Pre, State, True_State, False_State);
               State := True_State;
            end;
         end if;

         Result := Interpret_Statements (Unit, Handled.F_Stmts, State);

         if not Libadalang.Analysis.Is_Null (Post) then
            Scan_Expression_For_Flow_Bugs (Unit, Post, Result.State);

            if Config.Rule_States (Rules.Known_Postcondition_Failure) =
                 Config.Enabled
              and then Effective_SPARK_Enabled (Subprogram)
            then
               if Boolean_Value (Post, Result.State) = Bool_False then
                  Record_Definite_Error
                    (Unit, Post, Proof.Postcondition_Check,
                     Proof.Contract_Transfer,
                     "subprogram body makes the postcondition false",
                     "postcondition => false");
                  Report.Report_Rule_Violation
                    (Unit, Post, Rules.Known_Postcondition_Failure,
                     "subprogram body makes the postcondition false",
                     Explanation =>
                       "The joined state at normal subprogram exits makes " &
                       "the postcondition False.",
                     Evidence => "postcondition => false");
               elsif Config.Verification_Mode
                 and then Boolean_Value (Post, Result.State) = Bool_True
               then
                  --  proof-path: postcondition-legacy
                  Record_Proved_Safe
                    (Unit, Post, Proof.Postcondition_Check,
                     Proof.Contract_Transfer,
                     "joined normal-exit state satisfies the postcondition",
                     "postcondition => true");
               else
                  Record_Unproved
                    (Unit, Post, Proof.Postcondition_Check,
                     Proof.Contract_Transfer,
                     "postcondition failure is not established, but the " &
                       "postcondition is not proved",
                     Imprecision =>
                       "joined exit state does not certify the contract");
               end if;
            end if;
         end if;
      end;
   end Interpret_Subprogram_Flow;

   procedure Verify_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Subp_Body)
   is
      package CFG renames Adalang_Analyzer.Control_Flow_Graph;
      use type CFG.Edge_Kind;
      use type CFG.Node_Kind;

      Graph : constant CFG.Graph := CFG.Build (Subprogram);

      type State_Array is array (Positive range <>) of Flow_State;
      type Symbolic_State_Array is
        array (Positive range <>) of VC.Symbolic_State;
      type Boolean_Array is array (Positive range <>) of Boolean;
      type Natural_Array is array (Positive range <>) of Natural;

      type Loop_VC_Status is (Not_Seen, VC_Discharged, VC_Not_Discharged);

      type Loop_Invariant_Info is record
         Pragma_Node         : Libadalang.Analysis.Ada_Node :=
           Libadalang.Analysis.No_Ada_Node;
         Condition           : Libadalang.Analysis.Expr :=
           Libadalang.Analysis.No_Expr;
         Header              : CFG.Node_Id := CFG.No_Node;
         Leading             : Boolean := False;
         Initialization      : Loop_VC_Status := Not_Seen;
         Preservation        : Loop_VC_Status := Not_Seen;
         Initialization_By   : Proof.Analysis_Method :=
           Proof.Abstract_Interpretation;
         Preservation_By     : Proof.Analysis_Method :=
           Proof.Abstract_Interpretation;
         Initialization_Outcome : VC.VC_Outcome := VC.Unknown_Outcome;
         Preservation_Outcome   : VC.VC_Outcome := VC.Unknown_Outcome;
      end record;

      package Loop_Invariant_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Loop_Invariant_Info);

      type Loop_Variant_Info is record
         Pragma_Node : Libadalang.Analysis.Ada_Node :=
           Libadalang.Analysis.No_Ada_Node;
         Expression  : Libadalang.Analysis.Expr :=
           Libadalang.Analysis.No_Expr;
         Header      : CFG.Node_Id := CFG.No_Node;
         Leading     : Boolean := False;
         Direction   : VC.Loop_Variant_Direction := VC.Decreases;
         Direction_Supported : Boolean := False;
         Progress    : Loop_VC_Status := Not_Seen;
         Progress_By : Proof.Analysis_Method := Proof.External_Prover;
         Progress_Outcome : VC.VC_Outcome := VC.Unknown_Outcome;
      end record;

      package Loop_Variant_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Loop_Variant_Info);

      States : State_Array (1 .. CFG.Node_Count (Graph)) :=
        (others => Empty_Flow_State);
      Symbolic_States : Symbolic_State_Array (States'Range) :=
        (others => VC.Empty_Symbolic_State);
      Reachable : Boolean_Array (States'Range) := (others => False);
      Updates   : Natural_Array (States'Range) := (others => 0);
      Loop_Invariants : Loop_Invariant_Vectors.Vector;
      Loop_Variants   : Loop_Variant_Vectors.Vector;
      Summary_Mode : Boolean := False;

      package Work_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => CFG.Node_Id);
      Work : Work_Vectors.Vector;
      Head : Positive := 1;

      --  True when Node (a quantified expression) is reachable from its
      --  nearest enclosing Pre/Post aspect or Assert/Assert_And_Cut/
      --  Loop_Invariant pragma without first passing through an ordinary
      --  statement -- the only positions a quantified expression is ever
      --  evaluated directly (Boolean_Value/VC.Decide), bypassing the
      --  general CFG-based flow-tracking machinery that genuinely cannot
      --  model a quantifier's effect on program state. Used only to
      --  narrow Contains_Unsupported_Semantics's own blacklist entry for
      --  Ada_Quantified_Expr below; a quantified expression used as an
      --  ordinary value elsewhere (an if-condition, an assignment RHS)
      --  must keep disqualifying the whole subprogram, so this is an
      --  explicit allowlist, not a blanket relaxation.
      function In_Assertion_Position
        (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
         Current : Libadalang.Analysis.Ada_Node := Node.Parent;
      begin
         while not Libadalang.Analysis.Is_Null (Current) loop
            if Current.Kind = Libadalang.Common.Ada_Aspect_Assoc
              and then Normalized_Text (Current.As_Aspect_Assoc.F_Id) in
                "pre" | "post"
            then
               return True;
            elsif Current.Kind = Libadalang.Common.Ada_Pragma_Node
              and then Normalized_Text (Current.As_Pragma_Node.F_Id) in
                "assert" | "assert_and_cut" | "loop_invariant"
            then
               return True;
            elsif Current.Kind in Libadalang.Common.Ada_Stmt then
               return False;
            end if;
            Current := Current.Parent;
         end loop;
         return False;
      exception
         when others =>
            return False;
      end In_Assertion_Position;

      function Contains_Unsupported_Semantics
        (Node : Libadalang.Analysis.Ada_Node'Class;
         Root : Boolean := True) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return False;
         elsif not Root
           and then Node.Kind = Libadalang.Common.Ada_Subp_Body
         then
            return False;
         elsif
           (Node.Kind in
              Libadalang.Common.Ada_Allocator
                | Libadalang.Common.Ada_Explicit_Deref
                | Libadalang.Common.Ada_Real_Literal
                | Libadalang.Common.Ada_Floating_Point_Def
                | Libadalang.Common.Ada_Delta_Aggregate
                | Libadalang.Common.Ada_Generic_Subp_Instantiation
                | Libadalang.Common.Ada_Access_Def)
           or else
             (Node.Kind = Libadalang.Common.Ada_Quantified_Expr
              and then not In_Assertion_Position (Node))
         then
            return True;
         elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
            begin
               if Node.As_Call_Expr.F_Name.P_Is_Dispatching_Call then
                  return True;
               end if;
            exception
               when others =>
                  return True;
            end;
         end if;

         for Index in 1 .. Node.Children_Count loop
            if Contains_Unsupported_Semantics
                 (Node.Child (Index), Root => False)
            then
               return True;
            end if;
         end loop;
         return False;
      end Contains_Unsupported_Semantics;

      Boundary_Supported : constant Boolean :=
        CFG.Is_Complete (Graph)
        and then CFG.Is_Well_Formed (Graph)
        and then not Contains_Unsupported_Semantics (Subprogram);

      procedure Seed_Parameters (State : in out Flow_State) is
      begin
         for Param of Subprogram.F_Subp_Spec.P_Params loop
            declare
               Is_Output_Only : constant Boolean :=
                 Param.F_Mode.Kind in Libadalang.Common.Ada_Mode_Out;
               Typ : constant Libadalang.Analysis.Base_Type_Decl :=
                 Param.F_Type_Expr.P_Designated_Type_Decl;
               Bounds : constant Abstract_Range :=
                 (if Libadalang.Analysis.Is_Null (Typ)
                  then Unknown_Range
                  else Type_Range (Typ, State));
            begin
               for Id of Param.F_Ids loop
                  declare
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node (Id);
                  begin
                     Flow_Set_Initialized
                       (State, Key,
                        (if Is_Output_Only
                         then Output_Parameter_Initialization (Param)
                         else Bool_True));
                     if not Is_Output_Only then
                        Flow_Range_Set (State, Key, Bounds);
                     end if;
                  end;
               end loop;
            end;
         end loop;
      exception
         when others =>
            Flow_Havoc_All (State);
      end Seed_Parameters;

      procedure Transfer_Declaration
        (Node  : Libadalang.Analysis.Ada_Node;
         State : in out Flow_State)
      is
      begin
         if Node.Kind /= Libadalang.Common.Ada_Object_Decl then
            return;
         end if;

         declare
            Decl    : constant Libadalang.Analysis.Object_Decl :=
              Node.As_Object_Decl;
            Default : constant Libadalang.Analysis.Expr :=
              Decl.F_Default_Expr;
         begin
            if Libadalang.Analysis.Is_Null (Default) then
               declare
                  Initialized : constant Abstract_Bool :=
                    Implicit_Initialization (Decl, State);
               begin
                  for Id of Decl.F_Ids loop
                     Flow_Set_Initialized
                       (State, Libadalang.Analysis.Ada_Node (Id), Initialized);
                  end loop;
               end;
               return;
            end if;

            Scan_Expression_For_Flow_Bugs (Unit, Default, State);
            Check_Value_Range
              (Unit, Default, Decl.F_Type_Expr.P_Designated_Type_Decl,
               State, Rules.Known_Range_Check_Failure,
               "initial value is outside the object's subtype range");

            declare
               Value : constant Abstract_Int :=
                 Integer_Value (Default, State);
               Bool_Value : constant Abstract_Bool :=
                 Boolean_Value (Default, State);
               Bounds : constant Abstract_Range :=
                 Range_Value (Default, State);
            begin
               for Id of Decl.F_Ids loop
                  declare
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node (Id);
                  begin
                     Flow_Set (State, Key, Value);
                     Flow_Bool_Set (State, Key, Bool_Value);
                     Flow_Range_Set (State, Key, Bounds);
                     Flow_Set_Initialized (State, Key, Bool_True);
                  end;
               end loop;
            end;
         end;
      exception
         when others =>
            Flow_Havoc_All (State);
      end Transfer_Declaration;

      function Source_Node
        (Id : CFG.Node_Id) return Libadalang.Analysis.Ada_Node is
        (CFG.Node_At (Graph, Id).Source);

      function Enclosing_Loop
        (Node : Libadalang.Analysis.Ada_Node'Class)
         return Libadalang.Analysis.Ada_Node
      is
         Current : Libadalang.Analysis.Ada_Node :=
           Libadalang.Analysis.Ada_Node (Node);
      begin
         while not Libadalang.Analysis.Is_Null (Current) loop
            if Current.Kind in
              Libadalang.Common.Ada_While_Loop_Stmt
                | Libadalang.Common.Ada_For_Loop_Stmt
                | Libadalang.Common.Ada_Loop_Stmt
            then
               return Current;
            end if;
            Current := Current.Parent;
         end loop;
         return Libadalang.Analysis.No_Ada_Node;
      exception
         when others =>
            return Libadalang.Analysis.No_Ada_Node;
      end Enclosing_Loop;

      function Header_For
        (Loop_Node : Libadalang.Analysis.Ada_Node) return CFG.Node_Id
      is
      begin
         for Id in 1 .. CFG.Node_Count (Graph) loop
            if CFG.Node_At (Graph, Id).Kind = CFG.Loop_Header_Node
              and then Source_Node (Id) = Loop_Node
            then
               return Id;
            end if;
         end loop;
         return CFG.No_Node;
      end Header_For;

      --  True when every loop-body statement up to and including
      --  Pragma_Node is itself a "loop-invariant" or "loop-variant"
      --  pragma. Ada/SPARK attaches no meaning to the relative order of
      --  the two: a Loop_Invariant preceded only by a Loop_Variant (or
      --  vice versa) is just as much at the loop-head cut point as one
      --  preceded only by other invariants, so both pragma kinds share
      --  this one leading-position check.
      function Is_Leading_Loop_Proof_Pragma
        (Loop_Node   : Libadalang.Analysis.Ada_Node;
         Pragma_Node : Libadalang.Analysis.Ada_Node) return Boolean
      is
         Stmts : constant Libadalang.Analysis.Stmt_List :=
           Loop_Node.As_Base_Loop_Stmt.F_Stmts;
      begin
         for Index in 1 .. Stmts.Children_Count loop
            declare
               Item : constant Libadalang.Analysis.Ada_Node :=
                 Stmts.Child (Index);
            begin
               if Item = Pragma_Node then
                  return True;
               elsif Item.Kind /= Libadalang.Common.Ada_Pragma_Node
                 or else Normalized_Text (Item.As_Pragma_Node.F_Id) not in
                   "loop-invariant" | "loop-variant"
               then
                  return False;
               end if;
            end;
         end loop;
         return False;
      exception
         when others =>
            return False;
      end Is_Leading_Loop_Proof_Pragma;

      procedure Collect_Loop_Invariants
        (Node : Libadalang.Analysis.Ada_Node'Class)
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         end if;

         if Node.Kind = Libadalang.Common.Ada_Pragma_Node
           and then Normalized_Text (Node.As_Pragma_Node.F_Id) =
             "loop-invariant"
         then
            declare
               Pragma_Node : constant Libadalang.Analysis.Pragma_Node :=
                 Node.As_Pragma_Node;
               Condition   : constant Libadalang.Analysis.Expr :=
                 Pragma_Condition (Pragma_Node);
               Loop_Node   : constant Libadalang.Analysis.Ada_Node :=
                 Enclosing_Loop (Node);
               Header      : constant CFG.Node_Id :=
                 Header_For (Loop_Node);
            begin
               if not Libadalang.Analysis.Is_Null (Condition) then
                  Loop_Invariants.Append
                    ((Pragma_Node       =>
                        Libadalang.Analysis.Ada_Node (Pragma_Node),
                      Condition         => Condition,
                      Header            => Header,
                      Leading           =>
                        Header /= CFG.No_Node
                        and then Is_Leading_Loop_Proof_Pragma
                          (Loop_Node,
                           Libadalang.Analysis.Ada_Node (Pragma_Node)),
                      others            => <>));
               end if;
            end;
         elsif Node.Kind = Libadalang.Common.Ada_Pragma_Node
           and then Normalized_Text (Node.As_Pragma_Node.F_Id) =
             "loop-variant"
         then
            declare
               Pragma_Node : constant Libadalang.Analysis.Pragma_Node :=
                 Node.As_Pragma_Node;
               Expression  : constant Libadalang.Analysis.Expr :=
                 Verification_Pragma_Condition (Pragma_Node);
               Loop_Node   : constant Libadalang.Analysis.Ada_Node :=
                 Enclosing_Loop (Node);
               Header      : constant CFG.Node_Id := Header_For (Loop_Node);
               Count       : constant Natural :=
                 Pragma_Node.F_Args.Children_Count;
               Direction   : VC.Loop_Variant_Direction := VC.Decreases;
               Direction_Supported : Boolean := False;
            begin
               if Count = 1 then
                  declare
                     Assoc : constant
                       Libadalang.Analysis.Pragma_Argument_Assoc :=
                         Pragma_Node.F_Args.Child (1)
                           .As_Pragma_Argument_Assoc;
                     Name : constant String := Normalized_Text (Assoc.F_Name);
                  begin
                     if Name = "decreases" then
                        Direction := VC.Decreases;
                        Direction_Supported := True;
                     elsif Name = "increases" then
                        Direction := VC.Increases;
                        Direction_Supported := True;
                     end if;
                  end;
               end if;

               if not Libadalang.Analysis.Is_Null (Expression) then
                  Loop_Variants.Append
                    ((Pragma_Node =>
                        Libadalang.Analysis.Ada_Node (Pragma_Node),
                      Expression => Expression,
                      Header => Header,
                      Leading =>
                        Header /= CFG.No_Node
                        and then Is_Leading_Loop_Proof_Pragma
                          (Loop_Node,
                           Libadalang.Analysis.Ada_Node (Pragma_Node)),
                      Direction => Direction,
                      Direction_Supported => Direction_Supported,
                      others => <>));
               end if;
            end;
         end if;

         for Index in 1 .. Node.Children_Count loop
            if Node.Kind /= Libadalang.Common.Ada_Subp_Body
              or else Libadalang.Analysis.Ada_Node (Node) =
                Libadalang.Analysis.Ada_Node (Subprogram)
            then
               Collect_Loop_Invariants (Node.Child (Index));
            end if;
         end loop;
      end Collect_Loop_Invariants;

      function Invariants_Trusted (Header : CFG.Node_Id) return Boolean is
         Found : Boolean := False;
      begin
         for Item of Loop_Invariants loop
            if Item.Header = Header and then Item.Leading then
               Found := True;
               if Item.Initialization /= VC_Discharged
                 or else Item.Preservation = VC_Not_Discharged
               then
                  return False;
               end if;
            end if;
         end loop;
         return Found;
      end Invariants_Trusted;

      procedure Remember_Inconclusive
        (Stored    : in out VC.VC_Outcome;
         Candidate : VC.VC_Outcome)
      is
      begin
         --  Preserve an explicit unsupported boundary in preference to a
         --  later generic unknown result: it carries the actionable reason
         --  for why this multi-path loop VC could not be discharged.
         if Candidate.Result = VC.VC_Unsupported
           or else Stored.Result /= VC.VC_Unsupported
         then
            Stored := Candidate;
         end if;
      end Remember_Inconclusive;

      procedure Check_Loop_VCs
        (Header  : CFG.Node_Id;
         State   : Flow_State;
         Symbols : VC.Symbolic_State;
         Is_Back : Boolean)
      is
      begin
         for Index in 1 .. Natural (Loop_Invariants.Length) loop
            declare
               Item : Loop_Invariant_Info :=
                 Loop_Invariants.Element (Index);
            begin
               if Item.Header = Header and then Item.Leading then
                  declare
                     Value  : constant Abstract_Bool :=
                       Boolean_Value (Item.Condition, State);
                     Outcome : constant VC.VC_Outcome :=
                       (if Value = Bool_Unknown
                        then VC.Decide (Item.Condition, State, Symbols)
                        else VC.Unknown_Outcome);
                     Result : constant VC.VC_Result := Outcome.Result;
                     Proved : constant Boolean :=
                       Value = Bool_True or else Result = VC.VC_Proved;
                     Method : constant Proof.Analysis_Method :=
                       (if Result = VC.VC_Proved
                        then Proof.External_Prover
                        else Proof.Abstract_Interpretation);
                  begin
                     if Is_Back then
                        if not Proved then
                           Item.Preservation := VC_Not_Discharged;
                           Remember_Inconclusive
                             (Item.Preservation_Outcome, Outcome);
                        elsif Item.Preservation /= VC_Not_Discharged then
                           Item.Preservation := VC_Discharged;
                           Item.Preservation_By := Method;
                        end if;
                     else
                        if not Proved then
                           Item.Initialization := VC_Not_Discharged;
                           Remember_Inconclusive
                             (Item.Initialization_Outcome, Outcome);
                        elsif Item.Initialization /= VC_Not_Discharged then
                           Item.Initialization := VC_Discharged;
                           Item.Initialization_By := Method;
                        end if;
                     end if;
                     Loop_Invariants.Replace_Element (Index, Item);
                  end;
               end if;
            end;
         end loop;
      end Check_Loop_VCs;

      procedure Apply_Loop_Invariants
        (Header  : CFG.Node_Id;
         State   : in out Flow_State;
         Symbols : in out VC.Symbolic_State)
      is
      begin
         if not Invariants_Trusted (Header) then
            return;
         end if;

         for Item of Loop_Invariants loop
            if Item.Header = Header and then Item.Leading then
               declare
                  True_State, False_State : Flow_State;
               begin
                  Narrow_By_Condition
                    (Item.Condition, State, True_State, False_State);
                  State := True_State;
                  Symbols :=
                    VC.Assume
                      (Symbols, Item.Condition, Truth => True, Flow => State);
               end;
            end if;
         end loop;
      end Apply_Loop_Invariants;

      function Invariants_Discharged
        (Header : CFG.Node_Id) return Boolean
      is
         Found : Boolean := False;
      begin
         for Item of Loop_Invariants loop
            if Item.Header = Header and then Item.Leading then
               Found := True;
               if Item.Initialization /= VC_Discharged
                 or else Item.Preservation /= VC_Discharged
               then
                  return False;
               end if;
            end if;
         end loop;
         return Found;
      end Invariants_Discharged;

      function Invariants_Usable_For_Variant
        (Header : CFG.Node_Id) return Boolean
      is
      begin
         for Item of Loop_Invariants loop
            if Item.Header = Header and then Item.Leading
              and then
                (Item.Initialization /= VC_Discharged
                 or else Item.Preservation /= VC_Discharged)
            then
               return False;
            end if;
         end loop;
         return True;
      end Invariants_Usable_For_Variant;

      procedure Havoc_Loop_Writes
        (Loop_Node : Libadalang.Analysis.Ada_Node;
         State     : in out Flow_State)
      is
         procedure Visit (Node : Libadalang.Analysis.Ada_Node'Class) is
         begin
            if Libadalang.Analysis.Is_Null (Node) then
               return;
            elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
               declare
                  Key : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Assigned_Name (Node);
                  Initialized : constant Abstract_Bool :=
                    Flow_Initialization (State, Key);
               begin
                  Flow_Havoc (State, Key);
                  Flow_Set_Initialized (State, Key, Initialized);
               end;
            elsif Libadalang.Analysis.Ada_Node (Node) /=
              Loop_Node
              and then Node.Kind in
                Libadalang.Common.Ada_While_Loop_Stmt
                  | Libadalang.Common.Ada_For_Loop_Stmt
                  | Libadalang.Common.Ada_Loop_Stmt
            then
               return;
            end if;

            for Index in 1 .. Node.Children_Count loop
               Visit (Node.Child (Index));
            end loop;
         end Visit;
      begin
         Visit (Loop_Node);
      end Havoc_Loop_Writes;

      procedure Apply_Invariant_Cutpoint
        (Target  : CFG.Node_Id;
         State   : in out Flow_State;
         Symbols : in out VC.Symbolic_State)
      is
      begin
         if CFG.Node_At (Graph, Target).Kind = CFG.Loop_Header_Node then
            Apply_Loop_Invariants (Target, State, Symbols);
            return;
         end if;

         for Item of Loop_Invariants loop
            if Item.Leading
              and then Source_Node (Target) = Item.Pragma_Node
            then
               Apply_Loop_Invariants (Item.Header, State, Symbols);
               return;
            end if;
         end loop;
      end Apply_Invariant_Cutpoint;

      procedure Enqueue (Id : CFG.Node_Id) is
      begin
         Work.Append (Id);
      end Enqueue;

      procedure Merge_Into
        (Target : CFG.Node_Id;
         State  : Flow_State;
         Symbols : VC.Symbolic_State;
         Incoming_Kind : CFG.Edge_Kind)
      is
         Incoming_State   : Flow_State := State;
         Incoming_Symbols : VC.Symbolic_State := Symbols;
         Joined           : Flow_State;
         Joined_Symbols   : VC.Symbolic_State;
      begin
         if CFG.Node_At (Graph, Target).Kind = CFG.Loop_Header_Node then
            if Summary_Mode
              and then Incoming_Kind = CFG.Loop_Back_Edge
              and then Invariants_Discharged (Target)
            then
               return;
            end if;

            if Incoming_Kind /= CFG.Loop_Back_Edge then
               Check_Loop_VCs
                 (Target, Incoming_State, Incoming_Symbols,
                  Is_Back => False);
            end if;

            if Summary_Mode and then Invariants_Discharged (Target) then
               Havoc_Loop_Writes (Source_Node (Target), Incoming_State);
               Incoming_Symbols := VC.Havoc;
            end if;
            Apply_Loop_Invariants
              (Target, Incoming_State, Incoming_Symbols);
         end if;
         Apply_Invariant_Cutpoint
           (Target, Incoming_State, Incoming_Symbols);

         if not Reachable (Target) then
            States (Target) := Incoming_State;
            Symbolic_States (Target) := Incoming_Symbols;
            Reachable (Target) := True;
            Updates (Target) := 1;
            Enqueue (Target);
            return;
         end if;

         Joined := Flow_Join (States (Target), Incoming_State);
         Joined_Symbols :=
           VC.Join
             (Symbolic_States (Target), Incoming_Symbols, Joined,
              Merge_Tag => Positive (Target));
         if CFG.Node_At (Graph, Target).Kind = CFG.Loop_Header_Node
           and then Updates (Target) >= 3
         then
            Joined := Flow_Widen (States (Target), Joined);
            Joined_Symbols := VC.Havoc;
         end if;
         Apply_Invariant_Cutpoint (Target, Joined, Joined_Symbols);

         if not Flow_Equal (States (Target), Joined)
           or else not VC.Equal (Symbolic_States (Target), Joined_Symbols)
         then
            Updates (Target) := Updates (Target) + 1;
            if Updates (Target) > 64 then
               Flow_Havoc_All (Joined);
               Joined_Symbols := VC.Havoc;
            end if;
            States (Target) := Joined;
            Symbolic_States (Target) := Joined_Symbols;
            Enqueue (Target);
         end if;
      end Merge_Into;

      function Boolean_Condition
        (Node : Libadalang.Analysis.Ada_Node)
         return Libadalang.Analysis.Expr
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return Libadalang.Analysis.No_Expr;
         elsif Node.Kind in Libadalang.Common.Ada_Expr then
            return Node.As_Expr;
         elsif Node.Kind = Libadalang.Common.Ada_Exit_Stmt then
            return Node.As_Exit_Stmt.F_Cond_Expr;
         elsif Node.Kind = Libadalang.Common.Ada_While_Loop_Stmt then
            return
              Node.As_While_Loop_Stmt.F_Spec.As_While_Loop_Spec.F_Expr;
         else
            return Libadalang.Analysis.No_Expr;
         end if;
      exception
         when others =>
            return Libadalang.Analysis.No_Expr;
      end Boolean_Condition;

      procedure Seed_For_Loop_Variable
        (Node  : Libadalang.Analysis.Ada_Node;
         State : in out Flow_State)
      is
      begin
         if Node.Kind = Libadalang.Common.Ada_For_Loop_Stmt then
            declare
               Spec : constant Libadalang.Analysis.For_Loop_Spec :=
                 Node.As_For_Loop_Stmt.F_Spec.As_For_Loop_Spec;
            begin
               if Spec.F_Loop_Type.Kind =
                 Libadalang.Common.Ada_Iter_Type_In
               then
                  declare
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Ada_Node (Spec.F_Var_Decl.F_Id);
                  begin
                     Flow_Range_Set
                       (State, Key,
                        For_Loop_Range (Spec.F_Iter_Expr, State));
                     Flow_Set_Initialized (State, Key, Bool_True);
                  end;
               end if;
            end;
         end if;
      exception
         when E : others =>
            Report_Recoverable_Failure_Once
              (Rule       => "Initialization_Check",
               Operation  => "seed for-loop variable state",
               Source     => Ada_Text.Safe_Filename (Unit),
               Occurrence => E);
      end Seed_For_Loop_Variable;

      procedure Process_Node (Id : CFG.Node_Id) is
         Node_Info : constant CFG.CFG_Node := CFG.Node_At (Graph, Id);
         Source    : constant Libadalang.Analysis.Ada_Node :=
           Node_Info.Source;
         Input     : constant Flow_State := States (Id);
         Input_Symbols : constant VC.Symbolic_State := Symbolic_States (Id);
         Output    : Flow_State := Input;
         Output_Symbols : VC.Symbolic_State := Input_Symbols;
      begin
         case Node_Info.Kind is
            when CFG.Declaration_Node =>
               Transfer_Declaration (Source, Output);
               if Source.Kind = Libadalang.Common.Ada_Object_Decl
                 and then not Libadalang.Analysis.Is_Null
                   (Source.As_Object_Decl.F_Default_Expr)
               then
                  for Name of Source.As_Object_Decl.F_Ids loop
                     Output_Symbols :=
                       VC.Assign
                         (Output_Symbols,
                          Libadalang.Analysis.Ada_Node (Name),
                          Source.As_Object_Decl.F_Default_Expr, Input);
                  end loop;
               end if;

            when CFG.Statement_Node =>
               if Source.Kind = Libadalang.Common.Ada_Assign_Stmt then
                  Output :=
                    Interpret_Statement (Unit, Source, Input).State;
                  declare
                     Dest : constant Libadalang.Analysis.Name :=
                       Source.As_Assign_Stmt.F_Dest;
                     Key : constant Libadalang.Analysis.Ada_Node :=
                       Flow_Assigned_Name (Source);
                  begin
                     if not Libadalang.Analysis.Is_Null (Key) then
                        Output_Symbols :=
                          VC.Assign
                            (Input_Symbols, Key,
                             Source.As_Assign_Stmt.F_Expr, Input);
                     else
                        Output_Symbols := VC.Havoc;
                     end if;
                     if Dest.Kind = Libadalang.Common.Ada_Call_Expr then
                        Check_Conversion_Or_Index
                          (Unit, Dest.As_Call_Expr, Input, Input_Symbols);
                     end if;
                  end;
               elsif Source.Kind = Libadalang.Common.Ada_Call_Stmt then
                  Check_Call_Precondition
                    (Unit, Source.As_Call_Stmt.F_Call, Input, Input_Symbols);
                  Scan_Expression_For_Flow_Bugs
                    (Unit, Source, Input, Input_Symbols);
                  Output :=
                    Interpret_Statement (Unit, Source, Input).State;
                  Output_Symbols := VC.Havoc;
               elsif Source.Kind = Libadalang.Common.Ada_Pragma_Node then
                  Output :=
                    Interpret_Proof_Pragma
                      (Unit, Source.As_Pragma_Node, Input, Input_Symbols);
                  declare
                     Cond : constant Libadalang.Analysis.Expr :=
                       Pragma_Condition (Source.As_Pragma_Node);
                  begin
                     if not Libadalang.Analysis.Is_Null (Cond) then
                        Output_Symbols :=
                          VC.Assume
                            (Input_Symbols, Cond, Truth => True, Flow => Input);
                     end if;
                  end;
               elsif Source.Kind in
                 Libadalang.Common.Ada_Return_Stmt
                   | Libadalang.Common.Ada_Raise_Stmt
               then
                  Scan_Expression_For_Flow_Bugs
                    (Unit, Source, Input, Input_Symbols);
               end if;

            when CFG.Condition_Node =>
               declare
                  Cond : constant Libadalang.Analysis.Expr :=
                    Boolean_Condition (Source);
               begin
                  if not Libadalang.Analysis.Is_Null (Cond) then
                     Scan_Expression_For_Flow_Bugs
                       (Unit, Cond, Input, Input_Symbols);
                     Check_Flow_Condition (Unit, Cond, Input);
                  elsif Source.Kind in Libadalang.Common.Ada_Expr then
                     Scan_Expression_For_Flow_Bugs
                       (Unit, Source, Input, Input_Symbols);
                  end if;
               end;

            when CFG.Loop_Header_Node =>
               declare
                  Cond : constant Libadalang.Analysis.Expr :=
                    Boolean_Condition (Source);
               begin
                  if not Libadalang.Analysis.Is_Null (Cond) then
                     Scan_Expression_For_Flow_Bugs
                       (Unit, Cond, Input, Input_Symbols);
                     Check_Flow_Condition (Unit, Cond, Input);
                  elsif Source.Kind = Libadalang.Common.Ada_For_Loop_Stmt then
                     Scan_Expression_For_Flow_Bugs
                       (Unit, Source.As_For_Loop_Stmt.F_Spec, Input,
                        Input_Symbols);
                  end if;
               end;

            when others =>
               null;
         end case;

         for Edge_Index in 1 .. CFG.Edge_Count (Graph) loop
            declare
               Edge : constant CFG.CFG_Edge :=
                 CFG.Edge_At (Graph, Edge_Index);
               Edge_State : Flow_State := Output;
               Edge_Symbols : VC.Symbolic_State := Output_Symbols;
               Propagate  : Boolean := True;
               Cond       : constant Libadalang.Analysis.Expr :=
                 Boolean_Condition (Source);
            begin
               if Edge.From /= Id then
                  goto Continue_Edge;
               end if;

               if Edge.Kind in CFG.Exceptional_Edge | CFG.Raise_Edge then
                  --  A run-time check may fail before or after part of an
                  --  operation's visible effects.  Joining the incoming and
                  --  normal-transfer states retains only facts valid in both
                  --  cases; in particular, a potentially mutating call
                  --  cannot leave stale caller facts in a handler.
                  Edge_State := Flow_Join (Input, Output);
                  Edge_Symbols := VC.Havoc;
               elsif not Libadalang.Analysis.Is_Null (Cond)
                 and then Edge.Kind in
                   CFG.True_Edge | CFG.False_Edge | CFG.Loop_Exit_Edge
               then
                  declare
                     Value : constant Abstract_Bool :=
                       Boolean_Value (Cond, Input);
                     True_State, False_State : Flow_State;
                     Takes_True : constant Boolean :=
                       Edge.Kind in CFG.True_Edge | CFG.Loop_Exit_Edge
                       and then
                         (Source.Kind = Libadalang.Common.Ada_Exit_Stmt
                          or else Edge.Kind = CFG.True_Edge);
                  begin
                     Narrow_By_Condition
                       (Cond, Input, True_State, False_State);
                     if Takes_True then
                        Edge_State := True_State;
                        Edge_Symbols :=
                          VC.Assume
                            (Input_Symbols, Cond, Truth => True, Flow => Input);
                        Propagate := Value /= Bool_False;
                     else
                        Edge_State := False_State;
                        Edge_Symbols :=
                          VC.Assume
                            (Input_Symbols, Cond, Truth => False, Flow => Input);
                        Propagate := Value /= Bool_True;
                     end if;
                  end;
               elsif Node_Info.Kind = CFG.Loop_Header_Node
                 and then Source.Kind = Libadalang.Common.Ada_For_Loop_Stmt
                 and then Edge.Kind = CFG.True_Edge
               then
                  Seed_For_Loop_Variable (Source, Edge_State);
                  Edge_Symbols := VC.Havoc;
               end if;

               if Propagate then
                  Merge_Into
                    (Edge.To, Edge_State, Edge_Symbols, Edge.Kind);
               end if;

               <<Continue_Edge>>
            end;
         end loop;
      end Process_Node;

      procedure Prove_Loop_Preservation_VCs is
         Checked : Boolean_Array (States'Range) := (others => False);

         procedure Mark_Preservation
           (Header  : CFG.Node_Id;
            State   : Flow_State;
            Symbols : VC.Symbolic_State;
            Path_Supported : Boolean)
         is
         begin
            for Index in 1 .. Natural (Loop_Invariants.Length) loop
               declare
                  Item : Loop_Invariant_Info :=
                    Loop_Invariants.Element (Index);
               begin
                  if Item.Header = Header and then Item.Leading then
                     if not Path_Supported then
                        Item.Preservation := VC_Not_Discharged;
                     else
                        declare
                           Value : constant Abstract_Bool :=
                             Boolean_Value (Item.Condition, State);
                           Outcome : constant VC.VC_Outcome :=
                             (if Value = Bool_Unknown
                              then VC.Decide
                                (Item.Condition, State, Symbols)
                              else VC.Unknown_Outcome);
                           Result : constant VC.VC_Result := Outcome.Result;
                        begin
                           if Value = Bool_True
                             or else Result = VC.VC_Proved
                           then
                              Item.Preservation := VC_Discharged;
                              Item.Preservation_By :=
                                (if Result = VC.VC_Proved
                                 then Proof.External_Prover
                                 else Proof.Abstract_Interpretation);
                           else
                              Item.Preservation := VC_Not_Discharged;
                              Remember_Inconclusive
                                (Item.Preservation_Outcome, Outcome);
                           end if;
                        end;
                     end if;
                     Loop_Invariants.Replace_Element (Index, Item);
                  end if;
               end;
            end loop;
         end Mark_Preservation;

         procedure Mark_Variant_Progress
           (Header         : CFG.Node_Id;
            Before_State   : Flow_State;
            Before_Symbols : VC.Symbolic_State;
            After_State    : Flow_State;
            After_Symbols  : VC.Symbolic_State;
            Path_Supported : Boolean)
         is
         begin
            for Index in 1 .. Natural (Loop_Variants.Length) loop
               declare
                  Item : Loop_Variant_Info :=
                    Loop_Variants.Element (Index);
               begin
                  if Item.Header = Header and then Item.Leading then
                     if not Path_Supported
                       or else not Item.Direction_Supported
                       or else not Invariants_Usable_For_Variant (Header)
                     then
                        Item.Progress := VC_Not_Discharged;
                     else
                        declare
                           Expr_Type : constant
                             Libadalang.Analysis.Base_Type_Decl :=
                               Item.Expression.P_Expression_Type;
                           Bounds : Abstract_Range := Unknown_Range;
                        begin
                           if not Libadalang.Analysis.Is_Null (Expr_Type)
                             and then Expr_Type.P_Is_Int_Type
                           then
                              Bounds := Overflow_Base_Range
                                (Expr_Type, Item.Expression, Before_State);
                              if not Bounds.Has_Low
                                and then not Bounds.Has_High
                              then
                                 Bounds := Type_Range
                                   (Expr_Type, Before_State);
                              end if;
                           end if;

                           Item.Progress_Outcome :=
                             VC.Decide_Variant_Progress
                               (Item.Expression, Item.Direction, Bounds,
                                Before_State, Before_Symbols,
                                After_State, After_Symbols);
                           if Item.Progress_Outcome.Result = VC.VC_Proved then
                              Item.Progress := VC_Discharged;
                              Item.Progress_By := Proof.External_Prover;
                           else
                              Item.Progress := VC_Not_Discharged;
                           end if;
                        end;
                     end if;
                     Loop_Variants.Replace_Element (Index, Item);
                  end if;
               exception
                  when others =>
                     Item.Progress := VC_Not_Discharged;
                     Loop_Variants.Replace_Element (Index, Item);
               end;
            end loop;
         end Mark_Variant_Progress;

         procedure Prove_Header (Header : CFG.Node_Id) is
            State     : Flow_State := States (Header);
            Symbols   : VC.Symbolic_State := VC.Havoc;
            Before_State   : Flow_State := Empty_Flow_State;
            Before_Symbols : VC.Symbolic_State := VC.Havoc;
            Steps     : Natural := 0;

            --  Single-steps the CFG from Start under the same restricted
            --  rules Prove_Header has always enforced (exactly one
            --  non-exceptional outgoing edge per node; assign/pragma/
            --  merge only). The one addition: at a Condition_Node with
            --  Allow_Branch, fork into both arms (each walked with
            --  Allow_Branch => False, so a second sequential or nested
            --  branch is rejected the same way an unsupported node kind
            --  always was) and, if both independently reach the loop's
            --  own back edge, join their final states with the same
            --  Flow_Join/VC.Join machinery Merge_Into already relies on
            --  at ordinary CFG merge points. Reached_Back is True exactly
            --  when the walk (directly, or via a successful fork-and-join)
            --  reached the loop back edge; every successful return sets
            --  it, so it never disagrees with the function result.
            function Advance
              (Start        : CFG.Node_Id;
               Allow_Branch : Boolean;
               State        : in out Flow_State;
               Symbols      : in out VC.Symbolic_State;
               Steps        : in out Natural;
               Reached_Back : out Boolean) return Boolean
            is
               Current : CFG.Node_Id := Start;
               First   : Boolean := True;
            begin
               Reached_Back := False;
               loop
                  if not (First and then Current = Header) then
                     declare
                        Node_Info : constant CFG.CFG_Node :=
                          CFG.Node_At (Graph, Current);
                        Source : constant Libadalang.Analysis.Ada_Node :=
                          Node_Info.Source;
                     begin
                        if Node_Info.Kind = CFG.Statement_Node
                          and then Source.Kind =
                            Libadalang.Common.Ada_Assign_Stmt
                        then
                           declare
                              Key  : constant Libadalang.Analysis.Ada_Node :=
                                Flow_Assigned_Name (Source);
                              Dest : constant Libadalang.Analysis.Name :=
                                Source.As_Assign_Stmt.F_Dest;
                           begin
                              --  An array-element/slice write or a
                              --  pointer-dereference write is never
                              --  symbolically tracked anywhere in this
                              --  engine (Symbol_For has no support for an
                              --  indexed or dereferenced read either), so
                              --  skipping the symbolic update below for
                              --  one of those two shapes leaves no stale
                              --  binding behind. A record-component
                              --  write (Ada_Dotted_Name) is different:
                              --  VC_Prover *does* plant a root for
                              --  Obj.Field reads, so skipping its update
                              --  here would let a later reference resolve
                              --  to the pre-write value -- keep bailing
                              --  for that shape, as for any other
                              --  unresolved destination.
                              if Libadalang.Analysis.Is_Null (Key)
                                and then Dest.Kind not in
                                  Libadalang.Common.Ada_Call_Expr
                                    | Libadalang.Common.Ada_Explicit_Deref
                              then
                                 return False;
                              end if;
                              if not Libadalang.Analysis.Is_Null (Key) then
                                 Symbols :=
                                   VC.Assign
                                     (Symbols, Key,
                                      Source.As_Assign_Stmt.F_Expr, State);
                              end if;
                              State :=
                                Interpret_Statement
                                  (Unit, Source, State).State;
                           end;
                        elsif Node_Info.Kind in
                          CFG.Statement_Node | CFG.Merge_Node
                        then
                           null;
                        elsif Node_Info.Kind = CFG.Condition_Node then
                           if not Allow_Branch then
                              return False;
                           end if;

                           declare
                              True_Target  : CFG.Node_Id := CFG.No_Node;
                              False_Target : CFG.Node_Id := CFG.No_Node;
                              Other        : Natural := 0;
                           begin
                              for Edge_Index in
                                1 .. CFG.Edge_Count (Graph)
                              loop
                                 declare
                                    Edge : constant CFG.CFG_Edge :=
                                      CFG.Edge_At (Graph, Edge_Index);
                                 begin
                                    if Edge.From = Current then
                                       case Edge.Kind is
                                          when CFG.True_Edge =>
                                             True_Target := Edge.To;
                                          when CFG.False_Edge =>
                                             False_Target := Edge.To;
                                          when CFG.Exceptional_Edge
                                             | CFG.Raise_Edge =>
                                             null;
                                          when others =>
                                             Other := Other + 1;
                                       end case;
                                    end if;
                                 end;
                              end loop;

                              if Other > 0
                                or else True_Target = CFG.No_Node
                                or else False_Target = CFG.No_Node
                              then
                                 return False;
                              end if;

                              declare
                                 True_State   : Flow_State := State;
                                 True_Symbols : VC.Symbolic_State := Symbols;
                                 True_Steps   : Natural := Steps;
                                 True_Back    : Boolean;
                                 True_OK      : constant Boolean :=
                                   Advance
                                     (True_Target, False, True_State,
                                      True_Symbols, True_Steps, True_Back);

                                 False_State   : Flow_State := State;
                                 False_Symbols : VC.Symbolic_State :=
                                   Symbols;
                                 False_Steps   : Natural := Steps;
                                 False_Back    : Boolean;
                                 False_OK      : constant Boolean :=
                                   Advance
                                     (False_Target, False, False_State,
                                      False_Symbols, False_Steps,
                                      False_Back);
                              begin
                                 if not True_OK or else not False_OK
                                   or else not True_Back
                                   or else not False_Back
                                 then
                                    return False;
                                 end if;

                                 State :=
                                   Flow_Join (True_State, False_State);
                                 Symbols :=
                                   VC.Join
                                     (True_Symbols, False_Symbols, State,
                                      Merge_Tag => Positive (Current));
                                 Reached_Back := True;
                                 return True;
                              end;
                           end;
                        else
                           return False;
                        end if;
                     end;
                  end if;
                  First := False;

                  Steps := Steps + 1;
                  if Steps > CFG.Node_Count (Graph) then
                     return False;
                  end if;

                  declare
                     Next       : CFG.Node_Id := CFG.No_Node;
                     Candidates : Natural := 0;
                  begin
                     for Edge_Index in 1 .. CFG.Edge_Count (Graph) loop
                        declare
                           Edge : constant CFG.CFG_Edge :=
                             CFG.Edge_At (Graph, Edge_Index);
                        begin
                           if Edge.From = Current
                             and then Edge.Kind not in
                               CFG.Exceptional_Edge
                                 | CFG.Raise_Edge
                                 | CFG.Loop_Exit_Edge
                           then
                              if Current = Header
                                and then Edge.Kind not in
                                  CFG.True_Edge | CFG.Normal_Edge
                              then
                                 null;
                              elsif Edge.Kind = CFG.Loop_Back_Edge
                                and then Edge.To = Header
                              then
                                 Reached_Back := True;
                                 return True;
                              else
                                 Candidates := Candidates + 1;
                                 Next := Edge.To;
                              end if;
                           end if;
                        end;
                     end loop;

                     if Candidates /= 1 or else Next = CFG.No_Node then
                        return False;
                     end if;
                     Current := Next;
                  end;
               end loop;
            end Advance;
         begin
            if not Reachable (Header) then
               return;
            end if;

            Havoc_Loop_Writes (Source_Node (Header), State);
            for Item of Loop_Invariants loop
               if Item.Header = Header and then Item.Leading then
                  declare
                     True_State, False_State : Flow_State;
                  begin
                     Narrow_By_Condition
                       (Item.Condition, State, True_State, False_State);
                     State := True_State;
                     Symbols :=
                       VC.Assume
                         (Symbols, Item.Condition, Truth => True,
                          Flow => State);
                  end;
               end if;
            end loop;

            declare
               Cond : constant Libadalang.Analysis.Expr :=
                 Boolean_Condition (Source_Node (Header));
            begin
               if not Libadalang.Analysis.Is_Null (Cond) then
                  declare
                     True_State, False_State : Flow_State;
                  begin
                     Narrow_By_Condition
                       (Cond, State, True_State, False_State);
                     State := True_State;
                     Symbols :=
                       VC.Assume
                         (Symbols, Cond, Truth => True, Flow => State);
                  end;
               end if;
            end;

            Before_State := State;
            Before_Symbols := Symbols;

            declare
               Reached_Back : Boolean;
               OK           : constant Boolean :=
                 Advance
                   (Header, Allow_Branch => True, State => State,
                    Symbols => Symbols, Steps => Steps,
                    Reached_Back => Reached_Back);
               Path_OK      : constant Boolean := OK and then Reached_Back;
            begin
               Mark_Preservation (Header, State, Symbols, Path_OK);
               Mark_Variant_Progress
                 (Header, Before_State, Before_Symbols, State, Symbols,
                  Path_OK);
            end;
         end Prove_Header;
      begin
         for Item of Loop_Invariants loop
            if Item.Leading
              and then Item.Header /= CFG.No_Node
              and then not Checked (Item.Header)
            then
               Checked (Item.Header) := True;
               Prove_Header (Item.Header);
            end if;
         end loop;
         for Item of Loop_Variants loop
            if Item.Leading
              and then Item.Header /= CFG.No_Node
              and then not Checked (Item.Header)
            then
               Checked (Item.Header) := True;
               Prove_Header (Item.Header);
            end if;
         end loop;
      end Prove_Loop_Preservation_VCs;

      function Matching_CFG_Node
        (Node : Libadalang.Analysis.Ada_Node) return CFG.Node_Id
      is
      begin
         for Id in 1 .. CFG.Node_Count (Graph) loop
            if Source_Node (Id) = Node then
               return Id;
            end if;
         end loop;
         return CFG.No_Node;
      end Matching_CFG_Node;

      procedure Final_Outcome
        (Node       : Libadalang.Analysis.Ada_Node'Class;
         Kind       : Proof.Obligation_Kind;
         Container  : CFG.Node_Id;
         Explanation : String)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported (Unit, Node, Kind, Explanation);
         elsif Container /= CFG.No_Node and then not Reachable (Container) then
            Record_Unreachable
              (Unit, Node, Kind,
               "the containing CFG node is unreachable");
         else
            Record_Unproved
              (Unit, Node, Kind, Proof.Abstract_Interpretation,
               Explanation,
               Imprecision =>
                 "the fixed-point state did not discharge this obligation");
         end if;
      end Final_Outcome;

      --  As Final_Outcome, but for Range_Check specifically: rather than
      --  always defaulting to Unproved, replays Check_Value_Range's own
      --  Proved_Safe/Definite_Error/Unproved determination against
      --  Container's own fully-converged State, marked Final so it
      --  supersedes whatever a premature live recording (made while
      --  Verify_Subprogram's CFG fixed point could still have been
      --  mid-convergence for Container) left behind for the same
      --  obligation (see FP-034, following FP-031's Ada_Identifier fix).
      procedure Finalize_Range_Check
        (Value     : Libadalang.Analysis.Expr'Class;
         Typ       : Libadalang.Analysis.Base_Type_Decl;
         Container : CFG.Node_Id;
         Rule      : Rules.Rule_Kind;
         Message   : String)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported (Unit, Value, Proof.Range_Check, Message);
         elsif Container /= CFG.No_Node
           and then not Reachable (Container)
         then
            Record_Unreachable
              (Unit, Value, Proof.Range_Check,
               "the containing CFG node is unreachable");
         else
            Check_Value_Range
              (Unit, Value, Typ,
               (if Container = CFG.No_Node then Empty_Flow_State
                else States (Container)),
               Rule, Message,
               (if Container = CFG.No_Node then VC.Empty_Symbolic_State
                else Symbolic_States (Container)),
               Final => True);
         end if;
      end Finalize_Range_Check;

      --  As Finalize_Range_Check, but for Index_Check via Check_Index_Range
      --  (see FP-035, the same mechanism applied to array indexing).
      procedure Finalize_Index_Check
        (Index_Value : Libadalang.Analysis.Expr'Class;
         Bounds      : Abstract_Range;
         Container   : CFG.Node_Id)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Index_Value, Proof.Index_Check,
               "array index safety has not been established");
         elsif Container /= CFG.No_Node
           and then not Reachable (Container)
         then
            Record_Unreachable
              (Unit, Index_Value, Proof.Index_Check,
               "the containing CFG node is unreachable");
         else
            Check_Index_Range
              (Unit, Index_Value, Bounds,
               (if Container = CFG.No_Node then Empty_Flow_State
                else States (Container)),
               (if Container = CFG.No_Node then VC.Empty_Symbolic_State
                else Symbolic_States (Container)),
               Final => True);
         end if;
      end Finalize_Index_Check;

      --  As Finalize_Range_Check, for Division_By_Zero_Check via
      --  Check_Division_By_Zero (see FP-036).
      procedure Finalize_Division_Check
        (Expr      : Libadalang.Analysis.Bin_Op;
         Container : CFG.Node_Id)
      is
      begin
         if Expr.F_Op not in Libadalang.Common.Ada_Op_Div
             | Libadalang.Common.Ada_Op_Mod
             | Libadalang.Common.Ada_Op_Rem
         then
            return;
         end if;

         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
               "zero has not been excluded from the divisor");
         elsif Container /= CFG.No_Node
           and then not Reachable (Container)
         then
            Record_Unreachable
              (Unit, Expr.F_Right, Proof.Division_By_Zero_Check,
               "the containing CFG node is unreachable");
         else
            Check_Division_By_Zero
              (Unit, Expr,
               (if Container = CFG.No_Node then Empty_Flow_State
                else States (Container)),
               (if Container = CFG.No_Node then VC.Empty_Symbolic_State
                else Symbolic_States (Container)),
               Final => True);
         end if;
      end Finalize_Division_Check;

      --  As Finalize_Division_Check, for Integer_Overflow_Check via
      --  Check_Integer_Overflow (see FP-037).
      procedure Finalize_Overflow_Check
        (Expr      : Libadalang.Analysis.Bin_Op;
         Container : CFG.Node_Id)
      is
      begin
         if Expr.F_Op not in
           Libadalang.Common.Ada_Op_Plus
             | Libadalang.Common.Ada_Op_Minus
             | Libadalang.Common.Ada_Op_Mult
             | Libadalang.Common.Ada_Op_Div
             | Libadalang.Common.Ada_Op_Pow
         then
            return;
         end if;

         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Expr, Proof.Integer_Overflow_Check,
               "overflow safety has not been established");
         elsif Container /= CFG.No_Node
           and then not Reachable (Container)
         then
            Record_Unreachable
              (Unit, Expr, Proof.Integer_Overflow_Check,
               "the containing CFG node is unreachable");
         else
            Check_Integer_Overflow
              (Unit, Expr,
               (if Container = CFG.No_Node then Empty_Flow_State
                else States (Container)),
               (if Container = CFG.No_Node then VC.Empty_Symbolic_State
                else Symbolic_States (Container)),
               Final => True);
         end if;
      end Finalize_Overflow_Check;

      --  As Finalize_Range_Check, for Assertion_Check via
      --  Check_Proof_Pragma_Assertion, covering pragma Assert and the
      --  per-visit condition check shared by pragma Loop_Invariant /
      --  Loop_Variant (see FP-032, the same mechanism applied to
      --  Interpret_Proof_Pragma's live recording).
      procedure Finalize_Assertion_Check
        (Cond      : Libadalang.Analysis.Expr;
         Container : CFG.Node_Id)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Cond, Proof.Assertion_Check,
               "assertion has not been established");
         elsif Container /= CFG.No_Node
           and then not Reachable (Container)
         then
            Record_Unreachable
              (Unit, Cond, Proof.Assertion_Check,
               "the containing CFG node is unreachable");
         else
            Check_Proof_Pragma_Assertion
              (Unit, Cond,
               (if Container = CFG.No_Node then Empty_Flow_State
                else States (Container)),
               (if Container = CFG.No_Node then VC.Empty_Symbolic_State
                else Symbolic_States (Container)),
               Final => True);
         end if;
      end Finalize_Assertion_Check;

      --  As Finalize_Range_Check, for Precondition_Check via
      --  Check_Call_Precondition (see FP-033, the same mechanism applied
      --  to a call's precondition). A call statement's precondition is
      --  live-recorded twice under two distinct stable IDs -- once for
      --  the whole call (Process_Node's Ada_Call_Stmt handling, with the
      --  full symbolic state) and once for just the callee name
      --  (Scan_Expression_For_Flow_Bugs's own Ada_Call_Expr case, reached
      --  by its generic recursion over the same call statement, without
      --  symbols) -- so both must be replayed, not just one.
      procedure Finalize_Precondition_Check
        (Call      : Libadalang.Analysis.Call_Expr;
         Container : CFG.Node_Id)
      is
      begin
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Call, Proof.Precondition_Check,
               "call precondition has not been established");
            Record_Unsupported
              (Unit, Call.F_Name, Proof.Precondition_Check,
               "call precondition has not been established");
         elsif Container /= CFG.No_Node
           and then not Reachable (Container)
         then
            Record_Unreachable
              (Unit, Call, Proof.Precondition_Check,
               "the containing CFG node is unreachable");
            Record_Unreachable
              (Unit, Call.F_Name, Proof.Precondition_Check,
               "the containing CFG node is unreachable");
         else
            declare
               State   : constant Flow_State :=
                 (if Container = CFG.No_Node then Empty_Flow_State
                  else States (Container));
               Symbols : constant VC.Symbolic_State :=
                 (if Container = CFG.No_Node then VC.Empty_Symbolic_State
                  else Symbolic_States (Container));
            begin
               Check_Call_Precondition
                 (Unit, Call, State, Symbols, Final => True);
               Check_Call_Precondition
                 (Unit, Call.F_Name, State, Symbols, Final => True);
            end;
         end if;
      end Finalize_Precondition_Check;

      procedure Finalize_Loop_Invariant
        (Condition : Libadalang.Analysis.Expr;
         Container : CFG.Node_Id)
      is
      begin
         for Item of Loop_Invariants loop
            if Libadalang.Analysis.Ada_Node (Item.Condition) =
              Libadalang.Analysis.Ada_Node (Condition)
            then
               if not Boundary_Supported then
                  Record_Unsupported
                    (Unit, Condition, Proof.Loop_Invariant_Initialization,
                     "loop invariant initialization is outside the bounded " &
                       "verification subset");
                  Record_Unsupported
                    (Unit, Condition, Proof.Loop_Invariant_Preservation,
                     "loop invariant preservation is outside the bounded " &
                       "verification subset");
               elsif not Item.Leading then
                  Record_Unproved
                    (Unit, Condition, Proof.Loop_Invariant_Initialization,
                     Proof.No_Analysis,
                     "only leading loop invariants currently generate " &
                       "inductive verification conditions",
                     Imprecision =>
                       "the invariant is not at the loop-head cut point");
                  Record_Unproved
                    (Unit, Condition, Proof.Loop_Invariant_Preservation,
                     Proof.No_Analysis,
                     "only leading loop invariants currently generate " &
                       "inductive verification conditions",
                     Imprecision =>
                       "the invariant is not at the loop-head cut point");
               elsif Item.Initialization = VC_Discharged then
                  --  proof-path: loop-invariant-initialization
                  Record_Proved_Safe
                    (Unit, Condition,
                     Proof.Loop_Invariant_Initialization,
                     Item.Initialization_By,
                     "the invariant holds on every represented entry to " &
                       "the loop",
                     (if Item.Initialization_By = Proof.External_Prover
                      then VC.Evidence
                      else "loop entry state => invariant"));
               elsif Item.Initialization = Not_Seen
                 or else
                   (Item.Header /= CFG.No_Node
                    and then not Reachable (Item.Header))
               then
                  Record_Unreachable
                    (Unit, Condition,
                     Proof.Loop_Invariant_Initialization,
                     "the loop head has no represented entry");
               else
                  Record_VC_Unproved
                    (Unit, Condition,
                     Proof.Loop_Invariant_Initialization,
                     Proof.Abstract_Interpretation,
                     "the loop-entry state does not establish the invariant",
                     "the scalar loop initialization VC was not discharged",
                     Item.Initialization_Outcome);
               end if;

               if Boundary_Supported and then Item.Leading then
                  if Item.Preservation = VC_Discharged then
                     --  proof-path: loop-invariant-preservation
                     Record_Proved_Safe
                       (Unit, Condition,
                        Proof.Loop_Invariant_Preservation,
                        Item.Preservation_By,
                        "one arbitrary represented iteration preserves the " &
                          "invariant",
                        (if Item.Preservation_By = Proof.External_Prover
                         then VC.Evidence
                         else "invariant and loop body => invariant"));
                  elsif Item.Preservation = Not_Seen then
                     Record_Unreachable
                       (Unit, Condition,
                        Proof.Loop_Invariant_Preservation,
                        "no represented loop back edge is reachable");
                  else
                     Record_VC_Unproved
                       (Unit, Condition,
                        Proof.Loop_Invariant_Preservation,
                        Proof.Abstract_Interpretation,
                        "the loop body does not establish invariant " &
                          "preservation",
                        "the scalar loop preservation VC was not discharged",
                        Item.Preservation_Outcome);
                  end if;
               end if;
               return;
            end if;
         end loop;

         Final_Outcome
           (Condition, Proof.Loop_Invariant_Initialization, Container,
            "loop invariant initialization is not discharged");
         Final_Outcome
           (Condition, Proof.Loop_Invariant_Preservation, Container,
            "loop invariant preservation is not discharged");
      end Finalize_Loop_Invariant;

      procedure Finalize_Loop_Variant
        (Expression : Libadalang.Analysis.Expr;
         Container  : CFG.Node_Id)
      is
      begin
         for Item of Loop_Variants loop
            if Libadalang.Analysis.Ada_Node (Item.Expression) =
              Libadalang.Analysis.Ada_Node (Expression)
            then
               if not Boundary_Supported then
                  Record_Unsupported
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     "loop-variant progress is outside the bounded " &
                       "verification subset");
               elsif not Item.Leading then
                  Record_Unproved
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Proof.No_Analysis,
                     "only a leading loop variant currently generates a " &
                       "termination verification condition",
                     Imprecision =>
                       "the variant is not at the loop-head cut point");
               elsif not Item.Direction_Supported then
                  Record_Unproved
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Proof.No_Analysis,
                     "the loop-variant direction is unsupported",
                     Imprecision =>
                       "exactly one Increases or Decreases component is " &
                         "required");
               elsif Item.Progress = VC_Discharged then
                  --  proof-path: loop-variant-progress
                  Record_Proved_Safe
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Item.Progress_By,
                     "one arbitrary represented iteration makes strict, " &
                       "bounded progress",
                     VC.Evidence);
               elsif Item.Progress = Not_Seen
                 or else
                   (Item.Header /= CFG.No_Node
                    and then not Reachable (Item.Header))
               then
                  Record_Unreachable
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     "no represented loop iteration is reachable");
               elsif Item.Progress_Outcome.Result = VC.VC_Refuted then
                  Record_Definite_Error
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Proof.External_Prover,
                     "the loop variant does not make the declared bounded " &
                       "progress",
                     VC.Evidence);
               else
                  Record_VC_Unproved
                    (Unit, Expression, Proof.Loop_Variant_Check,
                     Proof.Abstract_Interpretation,
                     "loop-variant progress is not discharged",
                     "the bounded generic-iteration VC did not establish " &
                       "strict progress",
                     Item.Progress_Outcome);
               end if;
               return;
            end if;
         end loop;

         Final_Outcome
           (Expression, Proof.Loop_Variant_Check, Container,
            "loop-variant progress is not discharged");
      end Finalize_Loop_Variant;

      procedure Finalize_Node
        (Node      : Libadalang.Analysis.Ada_Node'Class;
         Container : CFG.Node_Id := CFG.No_Node)
      is
         Here : CFG.Node_Id := Container;
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         end if;

         declare
            Match : constant CFG.Node_Id :=
              Matching_CFG_Node (Libadalang.Analysis.Ada_Node (Node));
         begin
            if Match /= CFG.No_Node then
               Here := Match;
            end if;
         end;

         --  Several branches below call Libadalang properties
         --  (P_Expression_Type, P_Designated_Type_Decl, ...) directly as
         --  argument expressions, outside any begin/exception block of
         --  their own. A Property_Error from one of those (e.g. the same
         --  precise-resolution failure documented for FP-040's CallExpr.P_
         --  Kind case, or the unrelated "dereferencing a null access"
         --  memoized failures seen on real corpora such as CubedOS) used to
         --  escape Finalize_Node entirely and abort the whole file via
         --  Process_File's outer handler, instead of just this one node's
         --  obligations. This outer handler makes every branch as
         --  conservative as the Ada_Call_Expr/Ada_Identifier branches
         --  already were: skip this node's own finalization and fall
         --  through to the child-recursion loop below so the rest of the
         --  file is still analyzed.
         begin
            if Node.Kind in Libadalang.Common.Ada_Bin_Op_Range then
               declare
                  Expr : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               begin
                  Finalize_Division_Check (Expr, Here);
                  Finalize_Overflow_Check (Expr, Here);
               end;
            elsif Node.Kind = Libadalang.Common.Ada_Assign_Stmt then
               Finalize_Range_Check
                 (Node.As_Assign_Stmt.F_Expr,
                  Node.As_Assign_Stmt.F_Dest.P_Expression_Type, Here,
                  Rules.Known_Range_Check_Failure,
                  "assigned value is outside the target subtype range");
            elsif Node.Kind = Libadalang.Common.Ada_Object_Decl
              and then not Libadalang.Analysis.Is_Null
                (Node.As_Object_Decl.F_Default_Expr)
            then
               Finalize_Range_Check
                 (Node.As_Object_Decl.F_Default_Expr,
                  Node.As_Object_Decl.F_Type_Expr.P_Designated_Type_Decl, Here,
                  Rules.Known_Range_Check_Failure,
                  "initial value is outside the object's subtype range");
            elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
               declare
                  Call : constant Libadalang.Analysis.Call_Expr :=
                    Node.As_Call_Expr;
               begin
                  case Call.P_Kind is
                     when Libadalang.Common.Type_Conversion =>
                        declare
                           Decl  : constant Libadalang.Analysis.Basic_Decl :=
                             Call.F_Name.P_Referenced_Decl;
                           Value : constant Libadalang.Analysis.Expr :=
                             Assoc_Expression (Call.F_Suffix, 1);
                        begin
                           if not Libadalang.Analysis.Is_Null (Decl)
                             and then Decl.Kind in
                               Libadalang.Common.Ada_Base_Type_Decl
                             and then not Libadalang.Analysis.Is_Null (Value)
                           then
                              Finalize_Range_Check
                                (Value, Decl.As_Base_Type_Decl, Here,
                                 Rules.Known_Range_Check_Failure,
                                 "value is outside the target subtype range");
                           end if;
                        end;

                     when Libadalang.Common.Array_Index =>
                        declare
                           Array_Type : constant Libadalang.Analysis.Base_Type_Decl :=
                             Call.F_Name.P_Expression_Type;
                           Dimensions : constant Positive :=
                             (if Call.F_Suffix.Kind in Libadalang.Common.Ada_Expr
                              then 1 else Call.F_Suffix.Children_Count);
                           Here_State : constant Flow_State :=
                             (if Here = CFG.No_Node then Empty_Flow_State
                              else States (Here));
                        begin
                           if not Libadalang.Analysis.Is_Null (Array_Type)
                             and then Array_Type.P_Is_Array_Type
                           then
                              for Dimension in 1 .. Dimensions loop
                                 declare
                                    Index_Value : constant
                                      Libadalang.Analysis.Expr :=
                                        Assoc_Expression
                                          (Call.F_Suffix, Dimension);
                                 begin
                                    if not Libadalang.Analysis.Is_Null
                                      (Index_Value)
                                    then
                                       Finalize_Index_Check
                                         (Index_Value,
                                          Array_Index_Range
                                            (Array_Type, Dimension, Here_State),
                                          Here);
                                    end if;
                                 end;
                              end loop;
                           end if;
                        end;

                     when Libadalang.Common.Call =>
                        declare
                           Decl : constant Libadalang.Analysis.Basic_Decl :=
                             Call_Declaration (Call.F_Name);
                        begin
                           if not Libadalang.Analysis.Is_Null (Decl)
                             and then not Libadalang.Analysis.Is_Null
                               (Contract_Expression (Decl, "Pre"))
                           then
                              Finalize_Precondition_Check (Call, Here);
                           end if;
                        end;

                     when others =>
                        null;
                  end case;
               exception
                  when E : others =>
                     Report_Recoverable_Failure_Once
                       (Rule       => "Verification",
                        Operation  => "finalize expression proof obligations",
                        Source     => Ada_Text.Safe_Filename (Unit),
                        Occurrence => E);
               end;
            elsif Node.Kind = Libadalang.Common.Ada_Pragma_Node then
               declare
                  Pragma_Node : constant Libadalang.Analysis.Pragma_Node :=
                    Node.As_Pragma_Node;
                  Name : constant String :=
                    Normalized_Text (Pragma_Node.F_Id);
                  Cond : constant Libadalang.Analysis.Expr :=
                    Verification_Pragma_Condition (Pragma_Node);
               begin
                  if not Libadalang.Analysis.Is_Null (Cond)
                    and then Name /= "assume"
                  then
                     if Name /= "loop-variant" then
                        Finalize_Assertion_Check (Cond, Here);
                     end if;
                     if Name = "loop-invariant" then
                        Finalize_Loop_Invariant (Cond, Here);
                     elsif Name = "loop-variant" then
                        Finalize_Loop_Variant (Cond, Here);
                     end if;
                  end if;
               end;
            elsif Node.Kind = Libadalang.Common.Ada_Identifier
              and then Initialization_Read_Required (Node)
            then
               declare
                  Key     : constant Libadalang.Analysis.Ada_Node :=
                    Flow_Referenced_Name (Node);
                  Current : Libadalang.Analysis.Ada_Node := Key;
                  Tracked : Boolean := False;
               begin
                  while not Libadalang.Analysis.Is_Null (Current) loop
                     if Current.Kind in
                       Libadalang.Common.Ada_Object_Decl_Range
                         | Libadalang.Common.Ada_Param_Spec_Range
                     then
                        Tracked := True;
                        exit;
                     elsif Current.Kind in Libadalang.Common.Ada_Basic_Decl then
                        exit;
                     end if;
                     Current := Current.Parent;
                  end loop;
                  if Tracked then
                     if not Boundary_Supported then
                        Record_Unsupported
                          (Unit, Node, Proof.Initialization_Check,
                           "object initialization has not been established");
                     elsif Here /= CFG.No_Node
                       and then not Reachable (Here)
                     then
                        Record_Unreachable
                          (Unit, Node, Proof.Initialization_Check,
                           "the containing CFG node is unreachable");
                     else
                        --  Unlike the live recording this mirrors (made while
                        --  Verify_Subprogram's CFG fixed point may still be
                        --  mid-convergence for Here, and so can be based on an
                        --  intermediate, not-yet-joined state), this call is
                        --  made once, after the fixed point has fully
                        --  converged, against Here's own final State -- so it
                        --  is marked Final to always supersede whatever a
                        --  premature live recording left behind for the same
                        --  obligation (see FP-031).
                        case Flow_Initialization
                               ((if Here = CFG.No_Node then Empty_Flow_State
                                 else States (Here)),
                                Key)
                        is
                           when Bool_True =>
                              --  proof-path: initialization-final
                              Record_Proved_Safe
                                (Unit, Node, Proof.Initialization_Check,
                                 Proof.Flow_Analysis,
                                 "object is initialized on every incoming " &
                                   "path",
                                 "initialization => true", Final => True);
                           when Bool_False =>
                              Record_Definite_Error
                                (Unit, Node, Proof.Initialization_Check,
                                 Proof.Flow_Analysis,
                                 "object is uninitialized on every incoming " &
                                   "path",
                                 "initialization => false", Final => True);
                           when Bool_Unknown =>
                              Record_Unproved
                                (Unit, Node, Proof.Initialization_Check,
                                 Proof.Flow_Analysis,
                                 "object initialization is not established",
                                 Imprecision =>
                                   "incoming paths disagree or object is " &
                                     "external",
                                 Final => True);
                        end case;
                     end if;
                  end if;
               exception
                  when E : others =>
                     Report_Recoverable_Failure_Once
                       (Rule       => "Initialization_Check",
                        Operation  => "finalize identifier proof obligation",
                        Source     => Ada_Text.Safe_Filename (Unit),
                        Occurrence => E);
               end;
            end if;
         exception
            when E : others =>
               Report_Recoverable_Failure_Once
                 (Rule       => "Verification",
                  Operation  => "finalize node proof obligations",
                  Source     => Ada_Text.Safe_Filename (Unit),
                  Occurrence => E);
         end;

         --  Final obligation enumeration follows the same read/write
         --  distinction as the transfer scan above. In particular, an
         --  identifier used as an out-only actual does not itself create an
         --  initialization obligation.
         if Node.Kind = Libadalang.Common.Ada_Call_Expr then
            declare
               --  Node.As_Call_Expr.P_Kind can itself raise Property_Error
               --  (e.g. Libadalang's own "undetermined CallExpr kind" when
               --  precise overload resolution fails for a call into a
               --  separate, with'd GNAT project -- see FP-040). Unlike the
               --  case statement above, this second P_Kind call sits in an
               --  if-condition rather than inside a begin/exception block,
               --  so an unhandled failure here used to escape Finalize_Node
               --  entirely and abort the whole file via Process_File's
               --  outer handler instead of just this one obligation.
               Is_Plain_Call : Boolean := False;
            begin
               begin
                  Is_Plain_Call :=
                    Node.As_Call_Expr.P_Kind = Libadalang.Common.Call;
               exception
                  when others =>
                     Is_Plain_Call := False;
               end;

               if Is_Plain_Call then
                  begin
                     Finalize_Node (Node.As_Call_Expr.F_Name, Here);
                     for Pair of Node.As_Call_Expr.F_Name.P_Call_Params loop
                        if Formal_Mode (Libadalang.Analysis.Param (Pair)) /=
                          Libadalang.Common.Ada_Mode_Out
                          or else Libadalang.Analysis.Actual (Pair).Kind /=
                            Libadalang.Common.Ada_Identifier
                        then
                           Finalize_Node
                             (Libadalang.Analysis.Actual (Pair), Here);
                        end if;
                     end loop;
                     return;
                  exception
                     when others =>
                        --  Fall through to conservative raw-tree
                        --  enumeration when semantic parameter resolution
                        --  is unavailable.
                        null;
                  end;
               end if;
            end;
         end if;

         --  An aspect specification (Global, Depends, ...) is never
         --  executed at its own textual position -- unlike Pre/Post, which
         --  are genuinely-evaluated expressions and are already scanned
         --  explicitly via Contract_Expression/Scan_Expression_For_Flow_Bugs
         --  above, an aspect like "Global => (In_Out => (X, Y))" merely
         --  names X and Y as a contract; it must not be walked as if it
         --  were a read, or every scalar named in a nested subprogram's
         --  Global aspect would appear to read the outer object before it
         --  is ever assigned.
         if Node.Kind = Libadalang.Common.Ada_Aspect_Spec then
            return;
         end if;

         for Index in 1 .. Node.Children_Count loop
            if Node.Kind /= Libadalang.Common.Ada_Subp_Body
              or else Libadalang.Analysis.Ada_Node (Node) =
                Libadalang.Analysis.Ada_Node (Subprogram)
            then
               Finalize_Node (Node.Child (Index), Here);
            end if;
         end loop;
      end Finalize_Node;

      Initial : Flow_State := Empty_Flow_State;
      Initial_Symbols : VC.Symbolic_State := VC.Empty_Symbolic_State;
      Pre     : constant Libadalang.Analysis.Expr :=
        Contract_Expression (Subprogram, "Pre");
      Post    : constant Libadalang.Analysis.Expr :=
        Contract_Expression (Subprogram, "Post");
   begin
      Collect_Loop_Invariants (Subprogram);
      Seed_Parameters (Initial);
      if not Libadalang.Analysis.Is_Null (Pre) then
         declare
            True_State, False_State : Flow_State;
         begin
            Scan_Expression_For_Flow_Bugs (Unit, Pre, Initial);
            Narrow_By_Condition (Pre, Initial, True_State, False_State);
            Initial := True_State;
            Initial_Symbols :=
              VC.Assume
                (VC.Empty_Symbolic_State, Pre, Truth => True,
                 Flow => Initial);
         end;
      end if;

      Reachable (CFG.Entry_Id (Graph)) := True;
      States (CFG.Entry_Id (Graph)) := Initial;
      Symbolic_States (CFG.Entry_Id (Graph)) := Initial_Symbols;
      Enqueue (CFG.Entry_Id (Graph));

      if Boundary_Supported then
         while Head <= Natural (Work.Length) loop
            declare
               Id : constant CFG.Node_Id := Work.Element (Head);
            begin
               Head := Head + 1;
               Process_Node (Id);
            end;
         end loop;

         Prove_Loop_Preservation_VCs;

         --  Once induction has been checked independently, rerun the CFG
         --  with each proved loop represented by its invariant summary.
         --  Back edges into such a summary are cut: the invariant denotes
         --  an arbitrary iteration, so iterating concrete symbolic terms
         --  would only destroy the relational fact at downstream joins.
         Summary_Mode := True;  --  adalang-analyzer: ignore Dead_Store -- rationale: read by nested Process_Node
         States := (others => Empty_Flow_State);
         Symbolic_States := (others => VC.Empty_Symbolic_State);
         Reachable := (others => False);
         Updates := (others => 0);  --  adalang-analyzer: ignore Dead_Store -- rationale: read by nested Process_Node
         Work.Clear;
         Head := 1;
         Reachable (CFG.Entry_Id (Graph)) := True;
         States (CFG.Entry_Id (Graph)) := Initial;
         Symbolic_States (CFG.Entry_Id (Graph)) := Initial_Symbols;
         Enqueue (CFG.Entry_Id (Graph));

         while Head <= Natural (Work.Length) loop
            declare
               Id : constant CFG.Node_Id := Work.Element (Head);
            begin
               Head := Head + 1;
               Process_Node (Id);
            end;
         end loop;
      end if;

      Finalize_Node (Subprogram);

      if not Libadalang.Analysis.Is_Null (Post) then
         if not Boundary_Supported then
            Record_Unsupported
              (Unit, Post, Proof.Postcondition_Check,
               "subprogram is outside the bounded verification subset");
         elsif not Reachable (CFG.Normal_Exit (Graph)) then
            Record_Unreachable
              (Unit, Post, Proof.Postcondition_Check,
               "the subprogram has no reachable normal exit");
         else
            declare
               Exit_State : constant Flow_State :=
                 States (CFG.Normal_Exit (Graph));
               Value : constant Abstract_Bool :=
                 Boolean_Value (Post, Exit_State);
               VC_Outcome : constant VC.VC_Outcome :=
                 (if Value = Bool_Unknown
                  then VC.Decide
                    (Post, Exit_State,
                     Symbolic_States (CFG.Normal_Exit (Graph)))
                  else VC.Unknown_Outcome);
               VC_Result : constant VC.VC_Result := VC_Outcome.Result;
            begin
               Scan_Expression_For_Flow_Bugs (Unit, Post, Exit_State);
               if Value = Bool_True or else VC_Result = VC.VC_Proved then
                  --  proof-path: postcondition-final
                  Record_Proved_Safe
                    (Unit, Post, Proof.Postcondition_Check,
                     (if VC_Result = VC.VC_Proved
                      then Proof.External_Prover
                      else Proof.Abstract_Interpretation),
                     "every represented normal exit satisfies the " &
                       "postcondition",
                     (if VC_Result = VC.VC_Proved
                      then VC.Evidence else "postcondition => true"));
               elsif Value = Bool_False
                 or else
                   (VC_Result = VC.VC_Refuted
                    and then not Contains_VC_Arithmetic (Post))
               then
                  Record_Definite_Error
                    (Unit, Post, Proof.Postcondition_Check,
                     (if VC_Result = VC.VC_Refuted
                      then Proof.External_Prover
                      else Proof.Abstract_Interpretation),
                     "every represented normal exit violates the " &
                       "postcondition",
                     (if VC_Result = VC.VC_Refuted
                      then VC.Evidence else "postcondition => false"));
               else
                  Record_VC_Unproved
                    (Unit, Post, Proof.Postcondition_Check,
                     Proof.Abstract_Interpretation,
                     "postcondition is inconclusive at the joined normal " &
                       "exit",
                     "exit states do not imply the contract",
                     VC_Outcome);
               end if;
            end;
         end if;
      end if;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("bounded verification skipped for subprogram: " &
            Ada.Exceptions.Exception_Message (Exc));
         Finalize_Node (Subprogram);
   end Verify_Subprogram;

   procedure Verify_Unit
     (Unit : Libadalang.Analysis.Analysis_Unit)
   is
      procedure Visit (Node : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Subp_Body then
            Verify_Subprogram (Unit, Node.As_Subp_Body);
         end if;

         for Index in 1 .. Node.Children_Count loop
            Visit (Node.Child (Index));
         end loop;
      end Visit;
   begin
      if Config.Verification_Mode then
         Visit (Unit.Root);
      end if;
   end Verify_Unit;

end Adalang_Analyzer.Flow_Interp;
