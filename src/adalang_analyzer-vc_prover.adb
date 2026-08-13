--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Langkit_Support.Text;

with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config; use Adalang_Analyzer.Config;
with Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.VC_Prover is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;
   use type Adalang_Analyzer.Flow_Domain.Abstract_Bool;
   use type Ada.Containers.Count_Type;
   use type GNAT.OS_Lib.File_Descriptor;
   use type GNAT.OS_Lib.String_Access;

   package Domain renames Adalang_Analyzer.Flow_Domain;
   package Eval renames Adalang_Analyzer.Flow_Eval;

   --  Phase 0 v2 measurement scaffolding (diagnostic only, see
   --  Dump_Symbolic_Diagnostics): tallies of why Assign/Assume/Join/
   --  Include_Root discarded a symbolic fact, kept only for the lifetime of
   --  one process. Reading Symbolic_Diagnostics_Enabled costs a hash
   --  lookup; every increment site is gated by it so the counters (and the
   --  Value.Kind'Image call feeding the by-kind maps) cost nothing when
   --  unset.
   function Symbolic_Diagnostics_Enabled return Boolean is
     (Ada.Environment_Variables.Exists
        ("ADALANG_VERIFY_SYMBOLIC_DIAGNOSTICS"));

   package Kind_Tally_Maps is new Ada.Containers.Indefinite_Ordered_Maps
     (Key_Type => String, Element_Type => Natural);

   Assign_Havoc_By_Kind      : Kind_Tally_Maps.Map;
   Assume_Havoc_By_Kind      : Kind_Tally_Maps.Map;
   Join_Havoc_Count          : Natural := 0;
   Join_Merge_Survived_Count : Natural := 0;
   Join_Merge_Fresh_Count    : Natural := 0;
   Include_Root_Poison_Count : Natural := 0;

   procedure Tally (Map : in out Kind_Tally_Maps.Map; Key : String) is
      Cursor : constant Kind_Tally_Maps.Cursor := Map.Find (Key);
   begin
      if Kind_Tally_Maps.Has_Element (Cursor) then
         Map.Replace_Element (Cursor, Kind_Tally_Maps.Element (Cursor) + 1);
      else
         Map.Insert (Key, 1);
      end if;
   end Tally;

   --  Join is a function, so its own Join_Havoc_Count increment must go
   --  through a procedure call rather than a direct assignment statement,
   --  or it trips this project's own Function_Side_Effect check.
   procedure Bump (Counter : in out Natural) is
   begin
      Counter := Counter + 1;
   end Bump;

   --  Scalar formals are substituted with SMT terms. Composite objects
   --  need a different kind of substitution: record-component symbols are
   --  keyed by the enclosing object's defining name, so retain the actual
   --  object's identity for dotted-name translation in an inlined callee.
   type Object_Binding is record
      Formal : Libadalang.Analysis.Ada_Node;
      Actual : Libadalang.Analysis.Ada_Node;
   end record;

   package Object_Binding_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Object_Binding);

   type Translation_Context is record
      State           : Domain.Flow_State;
      Symbols         : Symbolic_State := Empty_Symbolic_State;
      Object_Bindings : Object_Binding_Vectors.Vector;
      Failure_Reason  : Unsupported_Reason := No_Unsupported_Reason;
      Failure_Node    : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Inlining_Path   : Unbounded_String;
      Supported       : Boolean := True;
      Depth           : Natural := 0;
      --  How many expression-function inlinings or quantifier scopes deep
      --  the current translation is, scoped per call-tree branch (see
      --  Inlined_Call_Term and the Ada_Quantified_Expr case in
      --  Boolean_Term) -- never propagated back to a parent context, only
      --  used to bound how deep a single recursive translation may go.
   end record;

   Max_Inline_Depth : constant := 4;

   procedure Mark_Unsupported
     (Context : in out Translation_Context;
      Node    : Libadalang.Analysis.Ada_Node'Class;
      Reason  : Unsupported_Reason)
   is
   begin
      Context.Supported := False;
      if Context.Failure_Reason = No_Unsupported_Reason then
         Context.Failure_Reason := Reason;
         if not Libadalang.Analysis.Is_Null (Node) then
            Context.Failure_Node := Libadalang.Analysis.Ada_Node (Node);
         end if;
      end if;
   end Mark_Unsupported;

   procedure Copy_Failure
     (Target : in out Translation_Context;
      Source : Translation_Context)
   is
   begin
      Target.Supported := Source.Supported;
      if not Source.Supported then
         Target.Failure_Reason := Source.Failure_Reason;
         Target.Failure_Node := Source.Failure_Node;
         Target.Inlining_Path := Source.Inlining_Path;
      end if;
   end Copy_Failure;

   function Unsupported_Provenance_For
     (Context  : Translation_Context;
      Fallback : Libadalang.Analysis.Ada_Node'Class)
      return Unsupported_Provenance
   is
      Node : constant Libadalang.Analysis.Ada_Node :=
        (if Libadalang.Analysis.Is_Null (Context.Failure_Node)
         then Libadalang.Analysis.Ada_Node (Fallback)
         else Context.Failure_Node);
   begin
      return
        (Reason =>
           (if Context.Failure_Reason = No_Unsupported_Reason
            then Unsupported_Expression_Kind
            else Context.Failure_Reason),
         Blocking_Expression =>
           (if Libadalang.Analysis.Is_Null (Node)
            then Null_Unbounded_String
            else To_Unbounded_String
              (Adalang_Analyzer.Ada_Text.Node_Text (Node))),
         Inline_Path => Context.Inlining_Path);
   exception
      when others =>
         return
           (Reason              => Translation_Error,
            Blocking_Expression => Null_Unbounded_String,
            Inline_Path         => Context.Inlining_Path);
   end Unsupported_Provenance_For;

   function Appended_Path
     (Path : Unbounded_String;
      Call : Libadalang.Analysis.Call_Expr) return Unbounded_String
   is
      Name : constant String :=
        Adalang_Analyzer.Ada_Text.Node_Text (Call.F_Name);
   begin
      return To_Unbounded_String
        ((if Length (Path) = 0 then Name
          else To_String (Path) & " -> " & Name));
   exception
      when others =>
         return Path;
   end Appended_Path;

   function Trimmed_Image (Value : Long_Long_Integer) return String is
     (Ada.Strings.Fixed.Trim
        (Long_Long_Integer'Image (Value), Ada.Strings.Both));

   function SMT_Integer (Value : Long_Long_Integer) return String is
      Image : constant String := Trimmed_Image (Value);
   begin
      if Image (Image'First) = '-' then
         return "(- " & Image (Image'First + 1 .. Image'Last) & ")";
      else
         return Image;
      end if;
   end SMT_Integer;

   function Natural_Image (Value : Natural) return String is
     (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Both));

   function Abs_Of (Term : String) return String is
     ("(ite (>= " & Term & " 0) " & Term & " (- " & Term & "))");

   --  A plain object's name is derived from its own defining name's source
   --  location, as before. A record-component key (Key.Component set)
   --  additionally suffixes the component's own name text, since the
   --  component's declaration -- shared by every object of the record
   --  type -- has no location of its own that would distinguish
   --  "TheAdmin.RolePresent" from "SomeOtherAdmin.RolePresent"; the
   --  object part of the name already does that.
   function Root_Name
     (Key    : Symbol_Key;
      Prefix : String := "b") return String
   is
      Object_Name : constant String :=
        Prefix &
        Natural_Image (Natural (Key.Object.Sloc_Range.Start_Line)) & "_" &
        Natural_Image (Natural (Key.Object.Sloc_Range.Start_Column));
   begin
      if Libadalang.Analysis.Is_Null (Key.Component) then
         return Object_Name;
      end if;
      return Object_Name & "_" &
        Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
          (Adalang_Analyzer.Ada_Text.Node_Text (Key.Component));
   end Root_Name;

   function Binding_Index
     (State : Symbolic_State;
      Key   : Symbol_Key) return Natural
   is
   begin
      for Index in 1 .. Natural (State.Bindings.Length) loop
         if State.Bindings.Element (Index).Key = Key then
            return Index;
         end if;
      end loop;
      return 0;
   end Binding_Index;

   function Root_Index
     (State : Symbolic_State;
      Name  : String) return Natural
   is
   begin
      for Index in 1 .. Natural (State.Roots.Length) loop
         if To_String (State.Roots.Element (Index).Name) = Name then
            return Index;
         end if;
      end loop;
      return 0;
   end Root_Index;

   procedure Add_Root
     (State           : in out Symbolic_State;
      Name            : String;
      Key             : Symbol_Key;
      Sort            : Scalar_Sort;
      Flow            : Domain.Flow_State;
      Enum_Bounds     : Domain.Abstract_Range := Domain.Unknown_Range;
      Explicit_Bounds : Domain.Abstract_Range := Domain.Unknown_Range)
   is
      --  The scalar interval domain (Flow_Range_Lookup) never tracks
      --  enum-typed objects, nor any record component -- Enum_Sort roots
      --  get their bounds from the enum type's own literal count instead
      --  (supplied by the caller), and a record-component root gets no
      --  declared bounds at all (Flow_Range_Lookup has no notion of
      --  "Key.Object.Key.Component" to look up). Explicit_Bounds is the
      --  same idea generalized to a non-enum root the caller already knows
      --  a sound bound for from the language itself rather than from flow
      --  tracking -- e.g. an unconstrained array's 'Length, which is
      --  always >= 0 regardless of what Flow_Range_Lookup could ever infer
      --  about the array object itself.
      Range_Value : constant Domain.Abstract_Range :=
        (if Sort = Enum_Sort then Enum_Bounds
         elsif Explicit_Bounds.Has_Low or else Explicit_Bounds.Has_High
           then Explicit_Bounds
         elsif not Libadalang.Analysis.Is_Null (Key.Component)
           then Domain.Unknown_Range
         else Domain.Flow_Range_Lookup (Flow, Key.Object));
   begin
      if Root_Index (State, Name) /= 0 then
         return;
      end if;

      State.Roots.Append
        ((Name     => To_Unbounded_String (Name),
          Key      => Key,
          Sort     => Sort,
          Has_Low  => Sort in Integer_Sort | Enum_Sort
            and then Range_Value.Has_Low,
          Low      => Range_Value.Low,
          Has_High => Sort in Integer_Sort | Enum_Sort
            and then Range_Value.Has_High,
          High     => Range_Value.High));
   end Add_Root;

   function Symbol_For
     (Context         : in out Translation_Context;
      Key             : Symbol_Key;
      Sort            : Scalar_Sort;
      Enum_Bounds     : Domain.Abstract_Range := Domain.Unknown_Range;
      Explicit_Bounds : Domain.Abstract_Range := Domain.Unknown_Range)
      return String
   is
      Binding : constant Natural := Binding_Index (Context.Symbols, Key);
   begin
      if Libadalang.Analysis.Is_Null (Key.Object) then
         Mark_Unsupported (Context, Key.Object, Null_Expression);
         return "";
      elsif Binding /= 0 then
         if Context.Symbols.Bindings.Element (Binding).Sort /= Sort then
            Mark_Unsupported (Context, Key.Object, Sort_Mismatch);
            return "";
         end if;
         return To_String (Context.Symbols.Bindings.Element (Binding).Term);
      end if;

      declare
         Name : constant String := Root_Name (Key);
      begin
         Add_Root
           (Context.Symbols, Name, Key, Sort, Context.State, Enum_Bounds,
            Explicit_Bounds);
         return Name;
      end;
   end Symbol_For;

   function Referenced_Key
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
   begin
      return Libadalang.Analysis.Ada_Node
        (Node.As_Name.P_Referenced_Defining_Name);
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Referenced_Key;

   --  An ordinary (non-component) Symbol_Key for Node, the common case
   --  every plain-identifier/formal/quantifier-bound-variable call site
   --  uses.
   function Plain_Key
     (Node : Libadalang.Analysis.Ada_Node) return Symbol_Key
   is
     (Object => Node, Component => Libadalang.Analysis.No_Ada_Node);

   --  True only when Node can be shown, from this expression alone, never
   --  to be zero: a nonzero integer literal, or an identifier whose known
   --  flow range excludes zero. Anything else (an unconstrained variable,
   --  a range straddling zero, an arbitrary subexpression) returns False,
   --  the same conservative answer Context.Supported := False already
   --  gives for every other unhandled shape in this file -- division/mod/
   --  rem are only translated to SMT when this holds, so a wrong guess
   --  here can only cost precision (falling back to Unsupported), never
   --  soundness.
   function Divisor_Provably_Nonzero
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      State : Domain.Flow_State) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Paren_Expr =>
            return Divisor_Provably_Nonzero
              (Node.As_Paren_Expr.F_Expr, State);

         when Libadalang.Common.Ada_Int_Literal =>
            declare
               Value : constant Domain.Abstract_Int :=
                 Eval.Integer_Value (Node);
            begin
               return Value.Known and then Value.Value /= 0;
            end;

         when Libadalang.Common.Ada_Identifier =>
            declare
               Key         : constant Libadalang.Analysis.Ada_Node :=
                 Referenced_Key (Node);
               Range_Value : constant Domain.Abstract_Range :=
                 Domain.Flow_Range_Lookup (State, Key);
            begin
               return (Range_Value.Has_Low and then Range_Value.Low > 0)
                 or else
                   (Range_Value.Has_High and then Range_Value.High < 0);
            end;

         when others =>
            return False;
      end case;
   exception
      when others =>
         return False;
   end Divisor_Provably_Nonzero;

   --  A single positional call/conversion actual is represented directly as
   --  an expression by Libadalang, not wrapped in an association list --
   --  mirrors Adalang_Analyzer.Flow_Interp.Assoc_Expression (private to
   --  that unit's body, so not reusable directly) for the one-actual case
   --  a type conversion always has.
   function Single_Actual_Expr
     (Suffix : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Expr
   is
   begin
      if Libadalang.Analysis.Is_Null (Suffix) then
         return Libadalang.Analysis.No_Expr;
      elsif Suffix.Kind in Libadalang.Common.Ada_Expr then
         return Suffix.As_Expr;
      elsif Suffix.Children_Count < 1 then
         return Libadalang.Analysis.No_Expr;
      elsif Suffix.Child (1).Kind = Libadalang.Common.Ada_Param_Assoc then
         return Suffix.Child (1).As_Param_Assoc.F_R_Expr;
      elsif Suffix.Child (1).Kind in Libadalang.Common.Ada_Base_Assoc then
         return Suffix.Child (1).As_Base_Assoc.P_Assoc_Expr;
      else
         return Libadalang.Analysis.No_Expr;
      end if;
   exception
      when others =>
         return Libadalang.Analysis.No_Expr;
   end Single_Actual_Expr;

   --  True only for a conversion whose target is a plain signed integer
   --  type -- a modular target needs "mod 2**N" wraparound semantics, not
   --  the identity translation this file gives every other conversion, so
   --  it is deliberately excluded rather than translated incorrectly.
   function Signed_Integer_Target
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
   begin
      if Decl.Kind not in Libadalang.Common.Ada_Base_Type_Decl then
         return False;
      end if;

      declare
         Typ  : constant Libadalang.Analysis.Base_Type_Decl :=
           Decl.As_Base_Type_Decl;
         Root : Libadalang.Analysis.Base_Type_Decl;
      begin
         if not Typ.P_Is_Int_Type then
            return False;
         end if;

         Root := Typ.P_Root_Type;
         return not
           (Root.Kind in Libadalang.Common.Ada_Type_Decl
            and then Root.As_Type_Decl.F_Type_Def.Kind =
              Libadalang.Common.Ada_Mod_Int_Type_Def);
      end;
   exception
      when others =>
         return False;
   end Signed_Integer_Target;

   --  Resolve the SMT sort from Ada's semantic type identity. In particular,
   --  Boolean is recognized as Standard.Boolean, not by the spelling of an
   --  identifier or by the absence of integer interval facts: ordinary enum
   --  objects have no Flow_Domain value/range either, and the old negative
   --  heuristic consequently mistyped them as Boolean.
   type Sort_Resolution is record
      Supported : Boolean := False;
      Sort      : Scalar_Sort := Integer_Sort;
   end record;

   function Type_Sort
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return Sort_Resolution
   is
   begin
      if Libadalang.Analysis.Is_Null (Typ) then
         return (Supported => False, Sort => Integer_Sort);
      elsif Langkit_Support.Text.To_UTF8
        (Typ.P_Canonical_Fully_Qualified_Name) = "standard.boolean"
      then
         return (Supported => True, Sort => Boolean_Sort);
      elsif Typ.P_Is_Int_Type then
         return (Supported => True, Sort => Integer_Sort);
      elsif Typ.P_Is_Enum_Type then
         return (Supported => True, Sort => Enum_Sort);
      end if;
      return (Supported => False, Sort => Integer_Sort);
   exception
      when others =>
         return (Supported => False, Sort => Integer_Sort);
   end Type_Sort;

   function Expression_Sort
     (Node : Libadalang.Analysis.Ada_Node'Class) return Sort_Resolution
   is
   begin
      if Node.Kind not in Libadalang.Common.Ada_Expr then
         return (Supported => False, Sort => Integer_Sort);
      end if;
      return Type_Sort (Node.As_Expr.P_Expression_Type);
   exception
      when others =>
         return (Supported => False, Sort => Integer_Sort);
   end Expression_Sort;

   --  As Adalang_Analyzer.Flow_Interp.Formal_Mode (private to that unit's
   --  body): walks up from a formal's own defining name to its enclosing
   --  Param_Spec to read its mode.
   function Enclosing_Param_Spec
     (Formal : Libadalang.Analysis.Defining_Name'Class)
      return Libadalang.Analysis.Param_Spec
   is
      Current : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.Ada_Node (Formal);
   begin
      while not Libadalang.Analysis.Is_Null (Current) loop
         if Current.Kind = Libadalang.Common.Ada_Param_Spec then
            return Current.As_Param_Spec;
         end if;
         Current := Current.Parent;
      end loop;
      return Libadalang.Analysis.No_Param_Spec;
   exception
      when others =>
         return Libadalang.Analysis.No_Param_Spec;
   end Enclosing_Param_Spec;

   function Formal_Is_Writable
     (Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean
   is
      Spec : constant Libadalang.Analysis.Param_Spec :=
        Enclosing_Param_Spec (Formal);
   begin
      return not Libadalang.Analysis.Is_Null (Spec)
        and then Spec.F_Mode in
          Libadalang.Common.Ada_Mode_Out
            | Libadalang.Common.Ada_Mode_In_Out;
   end Formal_Is_Writable;

   function Formal_Is_Record
     (Formal : Libadalang.Analysis.Defining_Name'Class) return Boolean
   is
      Spec : constant Libadalang.Analysis.Param_Spec :=
        Enclosing_Param_Spec (Formal);
   begin
      if Libadalang.Analysis.Is_Null (Spec)
        or else Libadalang.Analysis.Is_Null (Spec.F_Type_Expr)
      then
         return False;
      end if;

      declare
         Typ  : constant Libadalang.Analysis.Base_Type_Decl :=
           Spec.F_Type_Expr.P_Designated_Type_Decl;
         Root : Libadalang.Analysis.Base_Type_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Typ) then
            return False;
         end if;
         Root := Typ.P_Root_Type;
         return Root.Kind in Libadalang.Common.Ada_Type_Decl
           and then Root.As_Type_Decl.F_Type_Def.Kind =
             Libadalang.Common.Ada_Record_Type_Def;
      end;
   exception
      when others =>
         return False;
   end Formal_Is_Record;

   procedure Set_Object_Binding
     (Context : in out Translation_Context;
      Formal  : Libadalang.Analysis.Ada_Node;
      Actual  : Libadalang.Analysis.Ada_Node)
   is
   begin
      for Index in 1 .. Natural (Context.Object_Bindings.Length) loop
         if Context.Object_Bindings.Element (Index).Formal = Formal then
            Context.Object_Bindings.Replace_Element
              (Index, (Formal => Formal, Actual => Actual));
            return;
         end if;
      end loop;
      Context.Object_Bindings.Append ((Formal => Formal, Actual => Actual));
   end Set_Object_Binding;

   function Object_Identity
     (Context : Translation_Context;
      Object  : Libadalang.Analysis.Ada_Node)
      return Libadalang.Analysis.Ada_Node
   is
      Result : Libadalang.Analysis.Ada_Node := Object;
   begin
      --  Following the chain matters for F (R) calling G (R): G's formal
      --  must still resolve to the original caller object, not F's formal.
      for Step in 1 .. Natural (Context.Object_Bindings.Length) loop
         for Binding of Context.Object_Bindings loop
            if Binding.Formal = Result then
               Result := Binding.Actual;
               exit;
            end if;
         end loop;
      end loop;
      return Result;
   end Object_Identity;

   --  Resolve a formal's declared scalar type through its Param_Spec. A
   --  failure is explicit rather than silently defaulting to Integer_Sort.
   function Formal_Sort
     (Formal : Libadalang.Analysis.Defining_Name'Class)
      return Sort_Resolution
   is
   begin
      declare
         Spec : constant Libadalang.Analysis.Param_Spec :=
           Enclosing_Param_Spec (Formal);
      begin
         if Libadalang.Analysis.Is_Null (Spec) then
            return (Supported => False, Sort => Integer_Sort);
         end if;
         return Type_Sort (Spec.F_Type_Expr.P_Designated_Type_Decl);
      end;
   exception
      when others =>
         return (Supported => False, Sort => Integer_Sort);
   end Formal_Sort;

   --  When Node is a reference to an enumeration literal (a bare
   --  identifier like "Mon", or a package-qualified one), returns its
   --  0-based declaration-order position (Ada's 'Pos). Deliberately not
   --  GNAT's 'Enum_Rep/P_Enum_Rep, which an explicit representation clause
   --  can remap away from declaration order -- an "=" or "in" comparison
   --  means 'Pos equality, not storage-representation equality. Returns
   --  Known => False for anything else, the same conservative-Unsupported
   --  fallback as every other unhandled shape in this file.
   function Enum_Literal_Position
     (Node : Libadalang.Analysis.Ada_Node'Class) return Domain.Abstract_Int
   is
      Not_Known : constant Domain.Abstract_Int := Domain.Unknown_Int;
      Decl      : Libadalang.Analysis.Basic_Decl;
   begin
      if Node.Kind not in Libadalang.Common.Ada_Name then
         return Not_Known;
      end if;

      Decl := Node.As_Name.P_Referenced_Decl;
      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind /= Libadalang.Common.Ada_Enum_Literal_Decl
      then
         return Not_Known;
      end if;

      declare
         Enum_Type : constant Libadalang.Analysis.Type_Decl :=
           Decl.As_Enum_Literal_Decl.P_Enum_Type;
      begin
         if Libadalang.Analysis.Is_Null (Enum_Type)
           or else Enum_Type.F_Type_Def.Kind /=
             Libadalang.Common.Ada_Enum_Type_Def
         then
            return Not_Known;
         end if;

         declare
            Literals : constant Libadalang.Analysis.Enum_Literal_Decl_List :=
              Enum_Type.F_Type_Def.As_Enum_Type_Def.F_Enum_Literals;
         begin
            for Index in 1 .. Literals.Children_Count loop
               if Literals.Child (Index) =
                 Libadalang.Analysis.Ada_Node (Decl)
               then
                  return (Known => True,
                          Value => Long_Long_Integer (Index - 1));
               end if;
            end loop;
            return Not_Known;
         end;
      end;
   exception
      when others =>
         return Not_Known;
   end Enum_Literal_Position;

   --  The position range every value of enum type Typ falls in, 0 ..
   --  Literal_Count - 1 -- used to bound a not-yet-known enum-typed
   --  variable's symbolic root the same way an integer subtype's own
   --  declared range bounds an ordinary Integer_Sort root. Only resolves a
   --  full base type declaration ("type T is (...)"), not a range-narrowed
   --  subtype ("subtype S is T range A .. B"): Domain.Unknown_Range for
   --  anything else, the same conservative fallback used throughout this
   --  file (costs precision, never soundness, since the true range is
   --  always a subset of the base type's).
   function Enum_Type_Position_Range
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class)
      return Domain.Abstract_Range
   is
   begin
      if Libadalang.Analysis.Is_Null (Typ)
        or else Typ.Kind not in Libadalang.Common.Ada_Type_Decl
        or else Typ.As_Type_Decl.F_Type_Def.Kind /=
          Libadalang.Common.Ada_Enum_Type_Def
      then
         return Domain.Unknown_Range;
      end if;

      declare
         Count : constant Natural :=
           Typ.As_Type_Decl.F_Type_Def.As_Enum_Type_Def.F_Enum_Literals
             .Children_Count;
      begin
         if Count = 0 then
            return Domain.Unknown_Range;
         end if;
         return
           (Has_Low => True, Low => 0,
            Has_High => True, High => Long_Long_Integer (Count - 1));
      end;
   exception
      when others =>
         return Domain.Unknown_Range;
   end Enum_Type_Position_Range;

   --  As Enum_Type_Position_Range, but starting from a Name node (e.g. an
   --  Ada_Identifier) instead of an already-resolved type declaration --
   --  resolves Node's own expression type first.
   function Enum_Variable_Bounds
     (Node : Libadalang.Analysis.Ada_Node'Class)
      return Domain.Abstract_Range
   is
   begin
      if Node.Kind not in Libadalang.Common.Ada_Name then
         return Domain.Unknown_Range;
      end if;
      return Enum_Type_Position_Range (Node.As_Name.P_Expression_Type);
   exception
      when others =>
         return Domain.Unknown_Range;
   end Enum_Variable_Bounds;

   function Integer_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String;

   function Boolean_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String;

   procedure Set_Binding
     (State : in out Symbolic_State;
      Item  : Symbolic_Binding);

   --  Inlines a call that resolves to a plain Ada expression function (a
   --  single-expression body, "is (...)") by substitution: each scalar
   --  actual is translated once under the caller's own Context and bound as
   --  an SMT term; a record formal with a plain-object actual is instead
   --  bound to that object's identity. The callee's return expression is
   --  then translated under the fresh child context. Anything else (a
   --  statement-bodied subprogram, a dispatching
   --  or unresolved call, an out/in out formal, nesting past
   --  Max_Inline_Depth) falls back to Context.Supported := False -- the
   --  same conservative-fallback philosophy as every other unhandled shape
   --  in this file. This single "callee must be an Expr_Function" gate is
   --  also the purity guard: inlining only ever recurses into further
   --  Expr_Function bodies, and anything else Integer_Term/Boolean_Term
   --  encounter falls to their own exhaustive "others => Unsupported", so
   --  no assignment statement or side-effecting call can ever be reached
   --  through this path.
   function Inlined_Call_Term
     (Call    : Libadalang.Analysis.Call_Expr;
      Context : in out Translation_Context;
      Sort    : Scalar_Sort) return Unbounded_String;

   function Binary
     (Operator : String;
      Left     : Unbounded_String;
      Right    : Unbounded_String) return Unbounded_String is
     (To_Unbounded_String
        ("(" & Operator & " " & To_String (Left) & " " &
           To_String (Right) & ")"));

   function Integer_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         Mark_Unsupported (Context, Node, Null_Expression);
         return Null_Unbounded_String;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Int_Literal =>
            declare
               Value : constant Domain.Abstract_Int := Eval.Integer_Value (Node);
            begin
               if not Value.Known then
                  Mark_Unsupported
                    (Context, Node, Unsupported_Expression_Kind);
                  return Null_Unbounded_String;
               end if;
               return To_Unbounded_String (SMT_Integer (Value.Value));
            end;

         when Libadalang.Common.Ada_Identifier =>
            declare
               Sort_Info : constant Sort_Resolution := Expression_Sort (Node);
               --  Checked first: an enum literal (e.g. "Mon") is not a
               --  flow-tracked object at all, so it must be recognized
               --  before the ordinary variable path below, which would
               --  otherwise (correctly, but needlessly) reject it as
               --  uninitialized.
               Literal_Position : constant Domain.Abstract_Int :=
                 Enum_Literal_Position (Node);
            begin
               if not Sort_Info.Supported
                 or else Sort_Info.Sort not in Integer_Sort | Enum_Sort
               then
                  Mark_Unsupported (Context, Node, Sort_Mismatch);
                  return Null_Unbounded_String;
               end if;
               if Literal_Position.Known then
                  return To_Unbounded_String
                    (SMT_Integer (Literal_Position.Value));
               end if;
            end;

            declare
               Key   : constant Libadalang.Analysis.Ada_Node :=
                 Referenced_Key (Node);
               Value : constant Domain.Abstract_Int :=
                 Domain.Flow_Lookup (Context.State, Key);
               Bool_Value : constant Domain.Abstract_Bool :=
                 Domain.Flow_Bool_Lookup (Context.State, Key);
               Sort_Info : constant Sort_Resolution := Expression_Sort (Node);
            begin
               if not Sort_Info.Supported
                 or else Sort_Info.Sort not in Integer_Sort | Enum_Sort
               then
                  Mark_Unsupported (Context, Node, Sort_Mismatch);
                  return Null_Unbounded_String;
               elsif Domain.Flow_Initialization (Context.State, Key) /=
                 Domain.Bool_True
                 or else Bool_Value /= Domain.Bool_Unknown
               then
                  Mark_Unsupported (Context, Node, Uninitialized_Object);
                  return Null_Unbounded_String;
               elsif Value.Known then
                  return To_Unbounded_String (SMT_Integer (Value.Value));
               else
                  declare
                     --  Unknown-valued and not otherwise flow-tracked: if
                     --  Node's own type is an enum, bound its symbolic
                     --  root to the type's position range instead of
                     --  leaving it a plain unconstrained Integer_Sort
                     --  symbol -- same idea as an ordinary integer
                     --  subtype's declared range, just resolved from the
                     --  type declaration instead of Flow_Range_Lookup.
                     Enum_Bounds : constant Domain.Abstract_Range :=
                       Enum_Variable_Bounds (Node);
                  begin
                     if Sort_Info.Sort = Enum_Sort then
                        return To_Unbounded_String
                          (Symbol_For
                             (Context, Plain_Key (Key), Enum_Sort,
                              Enum_Bounds));
                     end if;
                     return To_Unbounded_String
                       (Symbol_For (Context, Plain_Key (Key), Integer_Sort));
                  end;
               end if;
            end;

         when Libadalang.Common.Ada_Call_Expr =>
            declare
               Call : constant Libadalang.Analysis.Call_Expr :=
                 Node.As_Call_Expr;
            begin
               case Call.P_Kind is
                  when Libadalang.Common.Type_Conversion =>
                     declare
                        Target : constant Libadalang.Analysis.Basic_Decl :=
                          Call.F_Name.P_Referenced_Decl;
                        Actual : constant Libadalang.Analysis.Expr :=
                          Single_Actual_Expr (Call.F_Suffix);
                     begin
                        if Libadalang.Analysis.Is_Null (Target)
                          or else Libadalang.Analysis.Is_Null (Actual)
                          or else not Signed_Integer_Target (Target)
                        then
                           Mark_Unsupported
                             (Context, Node, Unsupported_Conversion);
                           return Null_Unbounded_String;
                        end if;
                        return Integer_Term (Actual, Context);
                     end;

                  when Libadalang.Common.Call =>
                     return Inlined_Call_Term (Call, Context, Integer_Sort);

                  when others =>
                     Mark_Unsupported (Context, Node, Unsupported_Call);
                     return Null_Unbounded_String;
               end case;
            end;

         when Libadalang.Common.Ada_Paren_Expr =>
            return Integer_Term (Node.As_Paren_Expr.F_Expr, Context);

         when Libadalang.Common.Ada_Qual_Expr =>
            return Integer_Term (Node.As_Qual_Expr.F_Suffix, Context);

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Expr : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
               Item : constant Unbounded_String :=
                 Integer_Term (Expr.F_Expr, Context);
            begin
               case Expr.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Item;
                  when Libadalang.Common.Ada_Op_Minus =>
                     return To_Unbounded_String ("(- " & To_String (Item) & ")");
                  when Libadalang.Common.Ada_Op_Abs =>
                     return To_Unbounded_String (Abs_Of (To_String (Item)));
                  when others =>
                     Mark_Unsupported (Context, Node, Unsupported_Operator);
                     return Null_Unbounded_String;
               end case;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               Left  : constant Unbounded_String :=
                 Integer_Term (Expr.F_Left, Context);
               Right : constant Unbounded_String :=
                 Integer_Term (Expr.F_Right, Context);
            begin
               case Expr.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Binary ("+", Left, Right);
                  when Libadalang.Common.Ada_Op_Minus =>
                     return Binary ("-", Left, Right);
                  when Libadalang.Common.Ada_Op_Mult =>
                     return Binary ("*", Left, Right);

                  when Libadalang.Common.Ada_Op_Div
                     | Libadalang.Common.Ada_Op_Mod
                     | Libadalang.Common.Ada_Op_Rem =>
                     --  Only translated once the divisor is provably
                     --  nonzero (see Divisor_Provably_Nonzero) -- SMT-LIB's
                     --  native div/mod are Euclidean (remainder always in
                     --  [0, |divisor|)), which is neither Ada's truncating
                     --  "/" nor Ada's floored "mod" in general, so both are
                     --  rebuilt from the Euclidean primitives via sign
                     --  correction rather than mapped 1:1.
                     if not Divisor_Provably_Nonzero
                       (Expr.F_Right, Context.State)
                     then
                        Mark_Unsupported
                          (Context, Node, Unsafe_Divisor_Semantics);
                        return Null_Unbounded_String;
                     end if;

                     declare
                        L : constant String := To_String (Left);
                        R : constant String := To_String (Right);

                        --  Euclidean division of absolute values coincides
                        --  with truncating division when both operands are
                        --  non-negative; reapplying the operands' combined
                        --  sign then gives Ada's truncating "/".
                        Mag       : constant String :=
                          "(div " & Abs_Of (L) & " " & Abs_Of (R) & ")";
                        Same_Sign : constant String :=
                          "(= (>= " & L & " 0) (>= " & R & " 0))";
                        Tdiv      : constant String :=
                          "(ite " & Same_Sign & " " & Mag &
                            " (- " & Mag & "))";
                     begin
                        case Expr.F_Op is
                           when Libadalang.Common.Ada_Op_Div =>
                              return To_Unbounded_String (Tdiv);

                           when Libadalang.Common.Ada_Op_Rem =>
                              --  Ada "rem" truncates toward zero and
                              --  follows the dividend's sign, by
                              --  definition a - b * (a / b).
                              return To_Unbounded_String
                                ("(- " & L & " (* " & R & " " & Tdiv & "))");

                           when others =>
                              --  Ada "mod" floors and follows the
                              --  divisor's sign. SMT-LIB's Euclidean
                              --  "mod" already matches when the divisor
                              --  is positive; when it is negative and
                              --  the (nonzero) Euclidean remainder needs
                              --  to fall below zero, shift down by the
                              --  divisor's own magnitude (i.e. add it,
                              --  since it is negative).
                              declare
                                 Er : constant String :=
                                   "(mod " & L & " " & R & ")";
                              begin
                                 return To_Unbounded_String
                                   ("(ite (and (< " & R & " 0) (not (= " &
                                      Er & " 0))) (+ " & Er & " " & R &
                                      ") " & Er & ")");
                              end;
                        end case;
                     end;

                  when others =>
                     --  Ada exponentiation needs a bounded case-split over
                     --  the exponent's range to map onto SMT and is not
                     --  yet encoded.
                     Mark_Unsupported (Context, Node, Unsupported_Operator);
                     return Null_Unbounded_String;
               end case;
            end;

         when Libadalang.Common.Ada_Attribute_Ref =>
            declare
               Attr : constant Libadalang.Analysis.Attribute_Ref :=
                 Node.As_Attribute_Ref;
               Name : constant String :=
                 Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                   (Adalang_Analyzer.Ada_Text.Node_Text (Attr.F_Attribute));
            begin
               --  'First/'Last/'Length only, on the default (first)
               --  dimension: no explicit dimension argument, and no
               --  attempt at 'Range (not itself integer-valued) or any
               --  other attribute. A wrong guess here only costs
               --  Unsupported, never an incorrect bound.
               if Attr.F_Args.Children_Count > 0
                 or else Name not in "first" | "last" | "length"
               then
                  Mark_Unsupported (Context, Node, Unsupported_Attribute);
                  return Null_Unbounded_String;
               end if;

               declare
                  Prefix_Decl : Libadalang.Analysis.Basic_Decl :=
                    Libadalang.Analysis.No_Basic_Decl;
                  Bounds      : Domain.Abstract_Range := Domain.Unknown_Range;
               begin
                  if Attr.F_Prefix.Kind in Libadalang.Common.Ada_Name then
                     Prefix_Decl := Attr.F_Prefix.As_Name.P_Referenced_Decl;
                  end if;

                  if not Libadalang.Analysis.Is_Null (Prefix_Decl)
                    and then Prefix_Decl.Kind in
                      Libadalang.Common.Ada_Base_Type_Decl
                  then
                     --  X'First/'Last/'Length where X is itself a discrete
                     --  subtype mark (e.g. Some_Subtype'Last).
                     Bounds := Eval.Type_Range
                       (Prefix_Decl.As_Base_Type_Decl, Context.State);
                  else
                     declare
                        Prefix_Type : constant
                          Libadalang.Analysis.Base_Type_Decl :=
                            Attr.F_Prefix.P_Expression_Type;
                     begin
                        --  X'First/'Last/'Length where X is an array
                        --  object; only the default first dimension.
                        if not Libadalang.Analysis.Is_Null (Prefix_Type)
                          and then Prefix_Type.P_Is_Array_Type
                        then
                           Bounds := Eval.Array_Index_Range
                             (Prefix_Type, 1, Context.State);
                        end if;
                     end;
                  end if;

                  if Name = "first" then
                     if not Bounds.Has_Low then
                        Mark_Unsupported
                          (Context, Node, Missing_Static_Bounds);
                        return Null_Unbounded_String;
                     end if;
                     return To_Unbounded_String (SMT_Integer (Bounds.Low));
                  elsif Name = "last" then
                     if not Bounds.Has_High then
                        Mark_Unsupported
                          (Context, Node, Missing_Static_Bounds);
                        return Null_Unbounded_String;
                     end if;
                     return To_Unbounded_String (SMT_Integer (Bounds.High));
                  else
                     if Bounds.Has_Low and then Bounds.Has_High then
                        if Bounds.Low > Bounds.High then
                           return To_Unbounded_String ("0");
                        end if;
                        return To_Unbounded_String
                          (SMT_Integer (Bounds.High - Bounds.Low + 1));
                     end if;

                     --  The object's own bounds aren't statically known
                     --  (an unconstrained array parameter, e.g. `Chain :
                     --  in out Alphanumeric_Mixed` where `Alphanumeric_
                     --  Mixed is String`), so there is no literal to
                     --  substitute. Unlike a scalar value, whose actual
                     --  content genuinely could be anything the SMT
                     --  translation must stay silent about, an array's
                     --  'Length is always >= 0 by the language itself --
                     --  a fact true regardless of what Flow_Range_Lookup
                     --  could ever learn about the object -- so this is a
                     --  sound, if imprecise, root, not a guess: represent
                     --  it as a fresh symbol lower-bounded at 0, the same
                     --  way an ordinary unconstrained scalar formal
                     --  becomes a symbol via Symbol_For elsewhere,
                     --  instead of refusing the whole obligation.
                     declare
                        Object_Key : constant Libadalang.Analysis.Ada_Node :=
                          Object_Identity
                            (Context, Referenced_Key (Attr.F_Prefix));
                     begin
                        if Libadalang.Analysis.Is_Null (Object_Key) then
                           Mark_Unsupported
                             (Context, Node, Missing_Static_Bounds);
                           return Null_Unbounded_String;
                        end if;
                        return To_Unbounded_String
                          (Symbol_For
                             (Context,
                              (Object => Object_Key,
                               Component =>
                                 Libadalang.Analysis.Ada_Node
                                   (Attr.F_Attribute)),
                              Integer_Sort,
                              Explicit_Bounds => (Has_Low => True, Low => 0,
                                                   others  => <>)));
                     end;
                  end if;
               end;
            end;

         when Libadalang.Common.Ada_Dotted_Name =>
            --  An ordinary record-component read, e.g.
            --  "TheAdmin.RolePresent" -- never GNAT's own RM 8.3
            --  own-name-qualification shape ("Subp_Name.Param" inside
            --  "procedure Subp_Name (Param : ...)", Flow_Assigned_Name's
            --  own special case in Flow_Interp), nor a package-qualified
            --  name ("Some_Package.Some_Constant"): both are excluded by
            --  the same two checks below (the resolved declaration must
            --  be a genuine Ada_Component_Decl, and the prefix must be a
            --  flow-initialized object -- a subprogram's or package's own
            --  defining name is neither).
            declare
               Dotted     : constant Libadalang.Analysis.Dotted_Name :=
                 Node.As_Dotted_Name;
               Object_Key : constant Libadalang.Analysis.Ada_Node :=
                 Object_Identity
                   (Context, Referenced_Key (Dotted.F_Prefix));
               Field_Name : Libadalang.Analysis.Ada_Node :=
                 Libadalang.Analysis.No_Ada_Node;
            begin
               if Dotted.F_Suffix.Kind = Libadalang.Common.Ada_Identifier then
                  Field_Name := Referenced_Key (Dotted.F_Suffix);
               end if;

               if Libadalang.Analysis.Is_Null (Object_Key)
                 or else Libadalang.Analysis.Is_Null (Field_Name)
                 or else Field_Name.Kind /= Libadalang.Common.Ada_Defining_Name
                 or else Field_Name.As_Defining_Name.P_Basic_Decl.Kind /=
                   Libadalang.Common.Ada_Component_Decl
                 or else Domain.Flow_Initialization
                   (Context.State, Object_Key) /= Domain.Bool_True
               then
                  Mark_Unsupported
                    (Context, Node,
                     (if not Libadalang.Analysis.Is_Null (Object_Key)
                        and then not Libadalang.Analysis.Is_Null (Field_Name)
                        and then Field_Name.Kind =
                          Libadalang.Common.Ada_Defining_Name
                        and then Field_Name.As_Defining_Name.P_Basic_Decl.Kind =
                          Libadalang.Common.Ada_Component_Decl
                      then Uninitialized_Object
                      else Unsupported_Expression_Kind));
                  return Null_Unbounded_String;
               end if;

               declare
                  --  No per-component tracking exists anywhere in this
                  --  codebase's abstract interpreter (Flow_Domain never
                  --  models "Object.Component" writes at all -- only the
                  --  RM 8.3 shape excluded above), so there is no way to
                  --  verify this specific field was itself written, only
                  --  that its enclosing object was. This is the same
                  --  level of trust the interpreter already places at
                  --  every subprogram boundary (an "in"/"in out"
                  --  parameter's own Flow_Initialization is asserted, not
                  --  proven, from Ada's calling-convention discipline),
                  --  not a new category of risk this addition introduces.
                  Key         : constant Symbol_Key :=
                    (Object => Object_Key, Component => Field_Name);
                  Enum_Bounds : constant Domain.Abstract_Range :=
                    Enum_Variable_Bounds (Node);
                  Sort_Info   : constant Sort_Resolution :=
                    Expression_Sort (Node);
               begin
                  if not Sort_Info.Supported
                    or else Sort_Info.Sort not in Integer_Sort | Enum_Sort
                  then
                     Mark_Unsupported (Context, Node, Sort_Mismatch);
                     return Null_Unbounded_String;
                  elsif Sort_Info.Sort = Enum_Sort then
                     return To_Unbounded_String
                       (Symbol_For (Context, Key, Enum_Sort, Enum_Bounds));
                  end if;
                  return To_Unbounded_String
                    (Symbol_For (Context, Key, Integer_Sort));
               end;
            end;

         when others =>
            Mark_Unsupported
              (Context, Node, Unsupported_Expression_Kind);
            return Null_Unbounded_String;
      end case;
   exception
      when others =>
         Mark_Unsupported (Context, Node, Translation_Error);
         return Null_Unbounded_String;
   end Integer_Term;

   function Boolean_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         Mark_Unsupported (Context, Node, Null_Expression);
         return Null_Unbounded_String;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier then
         declare
            Text : constant String :=
              Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                (Adalang_Analyzer.Ada_Text.Node_Text (Node));
            Key : Libadalang.Analysis.Ada_Node;
            Value : Domain.Abstract_Bool;
            Sort_Info : constant Sort_Resolution := Expression_Sort (Node);
         begin
            if not Sort_Info.Supported
              or else Sort_Info.Sort /= Boolean_Sort
            then
               Mark_Unsupported (Context, Node, Sort_Mismatch);
               return Null_Unbounded_String;
            elsif Text = "true" or else Text = "false" then
               return To_Unbounded_String (Text);
            end if;
            Key := Referenced_Key (Node);
            Value := Domain.Flow_Bool_Lookup (Context.State, Key);
            if Domain.Flow_Initialization (Context.State, Key) /=
              Domain.Bool_True
              or else Domain.Flow_Lookup (Context.State, Key).Known
              or else Domain.Flow_Range_Lookup
                (Context.State, Key).Has_Low
              or else Domain.Flow_Range_Lookup
                (Context.State, Key).Has_High
            then
               Mark_Unsupported (Context, Node, Uninitialized_Object);
               return Null_Unbounded_String;
            elsif Value = Domain.Bool_True then
               return To_Unbounded_String ("true");
            elsif Value = Domain.Bool_False then
               return To_Unbounded_String ("false");
            else
               return To_Unbounded_String
                 (Symbol_For (Context, Plain_Key (Key), Boolean_Sort));
            end if;
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Boolean_Term (Node.As_Paren_Expr.F_Expr, Context);
      elsif Node.Kind = Libadalang.Common.Ada_Call_Expr then
         declare
            Call : constant Libadalang.Analysis.Call_Expr := Node.As_Call_Expr;
         begin
            if Call.P_Kind = Libadalang.Common.Call then
               return Inlined_Call_Term (Call, Context, Boolean_Sort);
            end if;
            Mark_Unsupported (Context, Node, Unsupported_Call);
            return Null_Unbounded_String;
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Quantified_Expr then
         declare
            Quant     : constant Libadalang.Analysis.Quantified_Expr :=
              Node.As_Quantified_Expr;
            Spec      : constant Libadalang.Analysis.For_Loop_Spec :=
              Quant.F_Loop_Spec;
            Iter_Expr : constant Libadalang.Analysis.Ada_Node :=
              Spec.F_Iter_Expr;
         begin
            if Spec.F_Loop_Type /= Libadalang.Common.Ada_Iter_Type_In
              or else not Libadalang.Analysis.Is_Null (Spec.F_Iter_Filter)
              or else Iter_Expr.Kind /= Libadalang.Common.Ada_Bin_Op
              or else Iter_Expr.As_Bin_Op.F_Op /=
                Libadalang.Common.Ada_Op_Double_Dot
            then
               Mark_Unsupported (Context, Node, Unsupported_Quantifier);
               return Null_Unbounded_String;
            end if;

            declare
               Low        : constant Unbounded_String :=
                 Integer_Term (Iter_Expr.As_Bin_Op.F_Left, Context);
               High       : constant Unbounded_String :=
                 Integer_Term (Iter_Expr.As_Bin_Op.F_Right, Context);
               Bound_Key  : constant Libadalang.Analysis.Ada_Node :=
                 Libadalang.Analysis.Ada_Node (Spec.F_Var_Decl.F_Id);
               Bound_Name : constant String :=
                 Root_Name (Plain_Key (Bound_Key), "q");
               Child      : Translation_Context := Context;
            begin
               Child.Depth := Context.Depth + 1;
               Domain.Flow_Set_Initialized
                 (Child.State, Bound_Key, Domain.Bool_True);
               Set_Binding
                 (Child.Symbols,
                  (Key  => Plain_Key (Bound_Key),
                   Sort => Integer_Sort,
                   Term => To_Unbounded_String (Bound_Name)));

               declare
                  Body_Term : constant Unbounded_String :=
                    Boolean_Term (Quant.F_Expr, Child);
                  Range_Hyp : constant String :=
                    "(and (<= " & To_String (Low) & " " & Bound_Name &
                      ") (<= " & Bound_Name & " " & To_String (High) & "))";
               begin
                  Copy_Failure (Context, Child);
                  Context.Symbols.Roots := Child.Symbols.Roots;

                  case Quant.F_Quantifier is
                     when Libadalang.Common.Ada_Quantifier_All =>
                        return To_Unbounded_String
                          ("(forall ((" & Bound_Name & " Int)) (=> " &
                             Range_Hyp & " " & To_String (Body_Term) & "))");
                     when Libadalang.Common.Ada_Quantifier_Some =>
                        return To_Unbounded_String
                          ("(exists ((" & Bound_Name & " Int)) (and " &
                             Range_Hyp & " " & To_String (Body_Term) & "))");
                  end case;
               end;
            end;
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Un_Op then
         declare
            Expr : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
         begin
            if Expr.F_Op = Libadalang.Common.Ada_Op_Not then
               return To_Unbounded_String
                 ("(not " & To_String
                    (Boolean_Term (Expr.F_Expr, Context)) & ")");
            end if;
            Mark_Unsupported (Context, Node, Unsupported_Operator);
            return Null_Unbounded_String;
         end;
      elsif Node.Kind in Libadalang.Common.Ada_Bin_Op_Range then
         declare
            Expr : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
            Op   : constant Libadalang.Common.Ada_Node_Kind_Type := Expr.F_Op;
         begin
            case Op is
               when Libadalang.Common.Ada_Op_And
                  | Libadalang.Common.Ada_Op_And_Then =>
                  return Binary
                    ("and", Boolean_Term (Expr.F_Left, Context),
                     Boolean_Term (Expr.F_Right, Context));
               when Libadalang.Common.Ada_Op_Or
                  | Libadalang.Common.Ada_Op_Or_Else =>
                  return Binary
                    ("or", Boolean_Term (Expr.F_Left, Context),
                     Boolean_Term (Expr.F_Right, Context));
               when Libadalang.Common.Ada_Op_Xor =>
                  return Binary
                    ("xor", Boolean_Term (Expr.F_Left, Context),
                     Boolean_Term (Expr.F_Right, Context));
               when Libadalang.Common.Ada_Op_Lt =>
                  return Binary
                    ("<", Integer_Term (Expr.F_Left, Context),
                     Integer_Term (Expr.F_Right, Context));
               when Libadalang.Common.Ada_Op_Lte =>
                  return Binary
                    ("<=", Integer_Term (Expr.F_Left, Context),
                     Integer_Term (Expr.F_Right, Context));
               when Libadalang.Common.Ada_Op_Gt =>
                  return Binary
                    (">", Integer_Term (Expr.F_Left, Context),
                     Integer_Term (Expr.F_Right, Context));
               when Libadalang.Common.Ada_Op_Gte =>
                  return Binary
                    (">=", Integer_Term (Expr.F_Left, Context),
                     Integer_Term (Expr.F_Right, Context));
               when Libadalang.Common.Ada_Op_Eq
                  | Libadalang.Common.Ada_Op_Neq =>
                  declare
                     Trial : Translation_Context := Context;
                     Left_Bool : constant Unbounded_String :=
                       Boolean_Term (Expr.F_Left, Trial);
                     Right_Bool : constant Unbounded_String :=
                       Boolean_Term (Expr.F_Right, Trial);
                     Equality : Unbounded_String;
                  begin
                     if Trial.Supported then
                        Context := Trial;
                        Equality := Binary ("=", Left_Bool, Right_Bool);
                     else
                        Equality := Binary
                          ("=", Integer_Term (Expr.F_Left, Context),
                           Integer_Term (Expr.F_Right, Context));
                     end if;
                     if Op = Libadalang.Common.Ada_Op_Neq then
                        return To_Unbounded_String
                          ("(not " & To_String (Equality) & ")");
                     else
                        return Equality;
                     end if;
                  end;
               when others =>
                  Mark_Unsupported (Context, Node, Unsupported_Operator);
                  return Null_Unbounded_String;
            end case;
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Membership_Expr then
         --  Mirrors Flow_Eval's own Ada_Membership_Expr case: each
         --  alternative is either a range (Low .. High) or a single value,
         --  combined with "or", negated for "not in". Any one alternative
         --  this bridge cannot translate (a subtype-mark choice, e.g.) fails
         --  the whole expression rather than silently under-approximating
         --  the membership set, the same fail-fast-on-any-unhandled-shape
         --  discipline every other case in this file already follows.
         declare
            Expr    : constant Libadalang.Analysis.Membership_Expr :=
              Node.As_Membership_Expr;
            Subject : constant Unbounded_String :=
              Integer_Term (Expr.F_Expr, Context);
            Goal    : Unbounded_String;
         begin
            if not Context.Supported or else Length (Subject) = 0 then
               if Context.Failure_Reason = No_Unsupported_Reason then
                  Mark_Unsupported
                    (Context, Node, Unsupported_Expression_Kind);
               end if;
               return Null_Unbounded_String;
            end if;

            for I in 1 .. Expr.F_Membership_Exprs.Children_Count loop
               declare
                  Alternative : constant Libadalang.Analysis.Ada_Node :=
                    Expr.F_Membership_Exprs.Child (I);
                  Term        : Unbounded_String;
               begin
                  if Alternative.Kind in Libadalang.Common.Ada_Bin_Op_Range
                    and then Alternative.As_Bin_Op.F_Op =
                      Libadalang.Common.Ada_Op_Double_Dot
                  then
                     declare
                        Low  : constant Unbounded_String :=
                          Integer_Term
                            (Alternative.As_Bin_Op.F_Left, Context);
                        High : constant Unbounded_String :=
                          Integer_Term
                            (Alternative.As_Bin_Op.F_Right, Context);
                     begin
                        if not Context.Supported then
                           return Null_Unbounded_String;
                        end if;
                        Term := To_Unbounded_String
                          ("(and (<= " & To_String (Low) & " " &
                             To_String (Subject) & ") (<= " &
                             To_String (Subject) & " " & To_String (High) &
                             "))");
                     end;
                  else
                     declare
                        --  A subtype-mark choice (e.g. "X in Some_Subtype")
                        --  is syntactically a Name but isn't a value-
                        --  yielding expression; resolve it to its own
                        --  static range instead of trying to translate it
                        --  as one, mirroring the "and (<= Low Subject)
                        --  (<= Subject High)" range shape above.
                        Type_Decl : Libadalang.Analysis.Basic_Decl :=
                          Libadalang.Analysis.No_Basic_Decl;
                     begin
                        if Alternative.Kind in Libadalang.Common.Ada_Name then
                           Type_Decl := Alternative.As_Name.P_Referenced_Decl;
                        end if;

                        if not Libadalang.Analysis.Is_Null (Type_Decl)
                          and then Type_Decl.Kind in
                            Libadalang.Common.Ada_Base_Type_Decl
                        then
                           declare
                              Int_Bounds : constant Domain.Abstract_Range :=
                                Eval.Type_Range
                                  (Type_Decl.As_Base_Type_Decl,
                                   Context.State);
                              --  Eval.Type_Range only resolves integer
                              --  subtypes; when the choice is an enum
                              --  subtype mark instead (Type_Range leaves
                              --  both bounds unset), fall back to its
                              --  literal-position range.
                              Bounds     : constant Domain.Abstract_Range :=
                                (if Int_Bounds.Has_Low
                                   or else Int_Bounds.Has_High
                                 then Int_Bounds
                                 else Enum_Type_Position_Range
                                   (Type_Decl.As_Base_Type_Decl));
                           begin
                              if not Bounds.Has_Low
                                or else not Bounds.Has_High
                              then
                                 Mark_Unsupported
                                   (Context, Alternative,
                                    Missing_Static_Bounds);
                                 return Null_Unbounded_String;
                              end if;
                              Term := To_Unbounded_String
                                ("(and (<= " & SMT_Integer (Bounds.Low) &
                                   " " & To_String (Subject) & ") (<= " &
                                   To_String (Subject) & " " &
                                   SMT_Integer (Bounds.High) & "))");
                           end;
                        else
                           declare
                              Value : constant Unbounded_String :=
                                Integer_Term (Alternative, Context);
                           begin
                              if not Context.Supported then
                                 return Null_Unbounded_String;
                              end if;
                              Term := Binary ("=", Subject, Value);
                           end;
                        end if;
                     end;
                  end if;

                  Goal :=
                    (if Length (Goal) = 0 then Term
                     else To_Unbounded_String
                       ("(or " & To_String (Goal) & " " & To_String (Term) &
                          ")"));
               end;
            end loop;

            if Length (Goal) = 0 then
               Mark_Unsupported
                 (Context, Node, Unsupported_Expression_Kind);
               return Null_Unbounded_String;
            elsif Expr.F_Op = Libadalang.Common.Ada_Op_In then
               return Goal;
            else
               return To_Unbounded_String ("(not " & To_String (Goal) & ")");
            end if;
         end;
      end if;

      Mark_Unsupported (Context, Node, Unsupported_Expression_Kind);
      return Null_Unbounded_String;
   exception
      when others =>
         Mark_Unsupported (Context, Node, Translation_Error);
         return Null_Unbounded_String;
   end Boolean_Term;

   function Inlined_Call_Term
     (Call    : Libadalang.Analysis.Call_Expr;
      Context : in out Translation_Context;
      Sort    : Scalar_Sort) return Unbounded_String
   is
      Decl : Libadalang.Analysis.Basic_Decl := Call.F_Name.P_Referenced_Decl;
   begin
      if Context.Depth >= Max_Inline_Depth
        or else Libadalang.Analysis.Is_Null (Decl)
        or else Call.F_Name.P_Is_Dispatching_Call
      then
         Context.Inlining_Path := Appended_Path (Context.Inlining_Path, Call);
         Mark_Unsupported
           (Context, Call,
            (if Context.Depth >= Max_Inline_Depth
             then Inline_Depth_Exceeded
             else Unsupported_Call));
         return Null_Unbounded_String;
      end if;

      if Decl.Kind = Libadalang.Common.Ada_Subp_Decl then
         Decl := Libadalang.Analysis.Basic_Decl
           (Decl.As_Subp_Decl.P_Body_Part (Imprecise_Fallback => True));
      end if;

      if Libadalang.Analysis.Is_Null (Decl)
        or else Decl.Kind /= Libadalang.Common.Ada_Expr_Function
      then
         Context.Inlining_Path := Appended_Path (Context.Inlining_Path, Call);
         Mark_Unsupported
           (Context, Call, Callee_Not_Expression_Function);
         return Null_Unbounded_String;
      end if;

      declare
         Callee : Translation_Context := Context;
      begin
         Callee.Depth := Context.Depth + 1;
         Callee.Inlining_Path := Appended_Path (Context.Inlining_Path, Call);

         for Pair of Call.F_Name.P_Call_Params loop
            declare
               Formal : constant Libadalang.Analysis.Defining_Name'Class :=
                 Libadalang.Analysis.Param (Pair);
               Actual : constant Libadalang.Analysis.Expr'Class :=
                 Libadalang.Analysis.Actual (Pair);
            begin
               if Formal_Is_Writable (Formal) then
                  Mark_Unsupported (Callee, Call, Writable_Formal);
                  Copy_Failure (Context, Callee);
                  return Null_Unbounded_String;
               end if;

               if Formal_Is_Record (Formal) then
                  --  A record has no scalar SMT term of its own. For the
                  --  deliberately narrow supported shape, retain the plain
                  --  actual object's identity so Formal.Field builds the
                  --  same Symbol_Key as Actual.Field in the caller.
                  if Actual.Kind /= Libadalang.Common.Ada_Identifier then
                     Mark_Unsupported
                       (Callee, Actual, Record_Actual_Not_Object);
                     Copy_Failure (Context, Callee);
                     return Null_Unbounded_String;
                  end if;
                  declare
                     Actual_Key : constant Libadalang.Analysis.Ada_Node :=
                       Object_Identity (Context, Referenced_Key (Actual));
                  begin
                     if Libadalang.Analysis.Is_Null (Actual_Key)
                       or else Domain.Flow_Initialization
                         (Context.State, Actual_Key) /= Domain.Bool_True
                     then
                        Mark_Unsupported
                          (Callee, Actual, Uninitialized_Object);
                        Copy_Failure (Context, Callee);
                        return Null_Unbounded_String;
                     end if;
                     Set_Object_Binding
                       (Callee, Libadalang.Analysis.Ada_Node (Formal),
                        Actual_Key);
                  end;
               else
                  declare
                     Formal_Sort_Info : constant Sort_Resolution :=
                       Formal_Sort (Formal);
                     Term : Unbounded_String;
                  begin
                     if not Formal_Sort_Info.Supported then
                        Mark_Unsupported
                          (Context, Actual, Unsupported_Expression_Kind);
                        return Null_Unbounded_String;
                     end if;
                     case Formal_Sort_Info.Sort is
                        when Integer_Sort =>
                           Term := Integer_Term (Actual, Context);
                        when Boolean_Sort =>
                           Term := Boolean_Term (Actual, Context);
                        when Enum_Sort =>
                           Term := Integer_Term (Actual, Context);
                     end case;

                     if not Context.Supported then
                        return Null_Unbounded_String;
                     end if;

                     Set_Binding
                       (Callee.Symbols,
                        (Key  => Plain_Key
                           (Libadalang.Analysis.Ada_Node (Formal)),
                         Sort => Formal_Sort_Info.Sort,
                         Term => Term));
                  end;
               end if;

               --  Scalar identifier translation and record dotted-name
               --  translation both require the formal to be initialized in
               --  the callee's scratch flow state.
               Domain.Flow_Set_Initialized
                 (Callee.State, Libadalang.Analysis.Ada_Node (Formal),
                  Domain.Bool_True);
            end;
         end loop;

         declare
            Body_Expr : constant Libadalang.Analysis.Expr :=
              Decl.As_Expr_Function.F_Expr;
            Result    : Unbounded_String;
         begin
            case Sort is
               when Integer_Sort =>
                  Result := Integer_Term (Body_Expr, Callee);
               when Boolean_Sort =>
                  Result := Boolean_Term (Body_Expr, Callee);
               when Enum_Sort =>
                  --  Inlined_Call_Term is only ever called with the Sort of
                  --  an Integer_Term/Boolean_Term call site (line ~486,
                  --  ~748 below), never Enum_Sort; kept exhaustive for
                  --  Scalar_Sort's sake. Callee.Supported (not
                  --  Context.Supported) is the one that actually reaches
                  --  the caller, via the unconditional assignment just
                  --  below.
                  Mark_Unsupported (Callee, Call, Sort_Mismatch);
                  Result := Null_Unbounded_String;
            end case;

            Copy_Failure (Context, Callee);
            Context.Symbols.Roots := Callee.Symbols.Roots;
            return Result;
         end;
      end;
   end Inlined_Call_Term;

   procedure Set_Binding
     (State : in out Symbolic_State;
      Item  : Symbolic_Binding)
   is
      Index : constant Natural := Binding_Index (State, Item.Key);
   begin
      if Index = 0 then
         State.Bindings.Append (Item);
      else
         State.Bindings.Replace_Element (Index, Item);
      end if;
   end Set_Binding;

   function Assign
     (State       : Symbolic_State;
      Destination : Libadalang.Analysis.Ada_Node;
      Value       : Libadalang.Analysis.Expr'Class;
      Flow        : Domain.Flow_State) return Symbolic_State
   is
      Context : Translation_Context :=
        (State => Flow, Symbols => State, Supported => State.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Sort_Info : constant Sort_Resolution := Expression_Sort (Value);
      Term      : Unbounded_String;
   begin
      if Libadalang.Analysis.Is_Null (Destination)
        or else Libadalang.Analysis.Is_Null (Value)
      then
         if Symbolic_Diagnostics_Enabled then
            Tally (Assign_Havoc_By_Kind, "null-node");
         end if;
         return Havoc;
      elsif not Sort_Info.Supported then
         if Symbolic_Diagnostics_Enabled then
            Tally (Assign_Havoc_By_Kind, Value.Kind'Image);
         end if;
         return Havoc;
      end if;

      case Sort_Info.Sort is
         when Boolean_Sort =>
            Term := Boolean_Term (Value, Context);
         when Integer_Sort | Enum_Sort =>
            Term := Integer_Term (Value, Context);
      end case;
      if not Context.Supported or else Length (Term) = 0 then
         if Symbolic_Diagnostics_Enabled then
            Tally (Assign_Havoc_By_Kind, Value.Kind'Image);
         end if;
         return Havoc;
      end if;
      Set_Binding
        (Context.Symbols,
         (Key => Plain_Key (Destination), Sort => Sort_Info.Sort, Term => Term));
      return Context.Symbols;
   exception
      when others =>
         if Symbolic_Diagnostics_Enabled then
            Tally (Assign_Havoc_By_Kind, "exception");
         end if;
         return Havoc;
   end Assign;

   function Assume
     (State     : Symbolic_State;
      Condition : Libadalang.Analysis.Expr;
      Truth     : Boolean;
      Flow      : Domain.Flow_State) return Symbolic_State
   is
      Context : Translation_Context :=
        (State => Flow, Symbols => State, Supported => State.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Term : constant Unbounded_String := Boolean_Term (Condition, Context);
   begin
      if not Context.Supported or else Length (Term) = 0 then
         if Symbolic_Diagnostics_Enabled then
            Tally (Assume_Havoc_By_Kind, Condition.Kind'Image);
         end if;
         return Havoc;
      end if;
      declare
         Assumption : constant Unbounded_String :=
           (if Truth then Term
            else To_Unbounded_String ("(not " & To_String (Term) & ")"));
         Present : Boolean := False;
      begin
         for Item of Context.Symbols.Assumptions loop
            if Item = Assumption then
               Present := True;
               exit;
            end if;
         end loop;
         if not Present then
            Context.Symbols.Assumptions.Append (Assumption);
         end if;
      end;
      return Context.Symbols;
   exception
      when others =>
         if Symbolic_Diagnostics_Enabled then
            Tally (Assume_Havoc_By_Kind, "exception");
         end if;
         return Havoc;
   end Assume;

   procedure Include_Root
     (State : in out Symbolic_State;
      Item  : Symbol_Root)
   is
      Index : constant Natural := Root_Index (State, To_String (Item.Name));
   begin
      if Index = 0 then
         State.Roots.Append (Item);
      else
         declare
            Current : Symbol_Root := State.Roots.Element (Index);
         begin
            if Current.Key /= Item.Key or else Current.Sort /= Item.Sort then
               if Symbolic_Diagnostics_Enabled then
                  Include_Root_Poison_Count := Include_Root_Poison_Count + 1;
               end if;
               State.Supported := False;
               return;
            end if;

            if Current.Has_Low and then Item.Has_Low then
               Current.Low := Long_Long_Integer'Min (Current.Low, Item.Low);
            else
               Current.Has_Low := False;
            end if;
            if Current.Has_High and then Item.Has_High then
               Current.High := Long_Long_Integer'Max
                 (Current.High, Item.High);
            else
               Current.Has_High := False;
            end if;
            State.Roots.Replace_Element (Index, Current);
         end;
      end if;
   end Include_Root;

   function Join
     (Left, Right : Symbolic_State;
      Flow        : Domain.Flow_State;
      Merge_Tag   : Positive) return Symbolic_State
   is
      Result : Symbolic_State := Empty_Symbolic_State;

      function Right_Binding
        (Key : Symbol_Key) return Natural is
        (Binding_Index (Right, Key));

      procedure Merge_Binding
        (Item : Symbolic_Binding;
         Other_Index : Natural)
      is
      begin
         if Other_Index /= 0
           and then Right.Bindings.Element (Other_Index).Sort = Item.Sort
           and then Right.Bindings.Element (Other_Index).Term = Item.Term
         then
            if Symbolic_Diagnostics_Enabled then
               Join_Merge_Survived_Count := Join_Merge_Survived_Count + 1;
            end if;
            Set_Binding (Result, Item);
         else
            if Symbolic_Diagnostics_Enabled then
               Join_Merge_Fresh_Count := Join_Merge_Fresh_Count + 1;
            end if;
            declare
               Name : constant String :=
                 Root_Name (Item.Key, "j" & Natural_Image (Merge_Tag) & "_");
            begin
               Add_Root (Result, Name, Item.Key, Item.Sort, Flow);
               Set_Binding
                 (Result,
                  (Key  => Item.Key,
                   Sort => Item.Sort,
                   Term => To_Unbounded_String (Name)));
            end;
         end if;
      end Merge_Binding;
   begin
      if not Left.Supported or else not Right.Supported then
         if Symbolic_Diagnostics_Enabled then
            Bump (Join_Havoc_Count);
         end if;
         return Havoc;
      end if;

      for Item of Left.Roots loop
         Include_Root (Result, Item);
      end loop;
      for Item of Right.Roots loop
         Include_Root (Result, Item);
      end loop;

      for Item of Left.Bindings loop
         Merge_Binding (Item, Right_Binding (Item.Key));
      end loop;
      for Item of Right.Bindings loop
         if Binding_Index (Left, Item.Key) = 0 then
            Merge_Binding (Item, 0);
         end if;
      end loop;

      for Item of Left.Assumptions loop
         for Other of Right.Assumptions loop
            if Item = Other then
               Result.Assumptions.Append (Item);
               exit;
            end if;
         end loop;
      end loop;
      return Result;
   exception
      when others =>
         return Havoc;
   end Join;

   function Equal (Left, Right : Symbolic_State) return Boolean is
   begin
      if Left.Supported /= Right.Supported
        or else Left.Roots.Length /= Right.Roots.Length
        or else Left.Bindings.Length /= Right.Bindings.Length
        or else Left.Assumptions.Length /= Right.Assumptions.Length
      then
         return False;
      end if;

      for Index in 1 .. Natural (Left.Roots.Length) loop
         if Left.Roots.Element (Index) /= Right.Roots.Element (Index) then
            return False;
         end if;
      end loop;
      for Index in 1 .. Natural (Left.Bindings.Length) loop
         if Left.Bindings.Element (Index) /= Right.Bindings.Element (Index) then
            return False;
         end if;
      end loop;
      for Index in 1 .. Natural (Left.Assumptions.Length) loop
         if Left.Assumptions.Element (Index) /=
           Right.Assumptions.Element (Index)
         then
            return False;
         end if;
      end loop;
      return True;
   end Equal;

   function Constraints
     (Context : Translation_Context) return Unbounded_String
   is
      Result : Unbounded_String;
   begin
      for Index in 1 .. Natural (Context.Symbols.Roots.Length) loop
         declare
            Item : constant Symbol_Root :=
              Context.Symbols.Roots.Element (Index);
            Name : constant String := To_String (Item.Name);
         begin
            Append
              (Result,
               "(declare-fun " & Name & " () " &
                 (if Item.Sort = Boolean_Sort then "Bool" else "Int") &
                 ")" & ASCII.LF);
            if Item.Sort in Integer_Sort | Enum_Sort then
               if Item.Has_Low then
                  Append
                    (Result,
                     "(assert (>= " & Name & " " &
                       SMT_Integer (Item.Low) & "))" &
                       ASCII.LF);
               end if;
               if Item.Has_High then
                  Append
                    (Result,
                     "(assert (<= " & Name & " " &
                       SMT_Integer (Item.High) & "))" &
                       ASCII.LF);
               end if;
            end if;
         end;
      end loop;

      for Item of Context.Symbols.Assumptions loop
         Append
           (Result, "(assert " & To_String (Item) & ")" & ASCII.LF);
      end loop;
      return Result;
   end Constraints;

   type Solver_Answer is
     (Solver_Unsat, Solver_Sat, Solver_Unknown, Solver_Unavailable);

   function Solver_Path (Name, Override : String) return String is
      Located : GNAT.OS_Lib.String_Access;
   begin
      if Ada.Environment_Variables.Exists (Override) then
         return Ada.Environment_Variables.Value (Override);
      end if;

      Located := GNAT.OS_Lib.Locate_Exec_On_Path (Name);
      if Located /= null then
         declare
            Result : constant String := Located.all;
         begin
            GNAT.OS_Lib.Free (Located);
            return Result;
         end;
      end if;

      if Ada.Environment_Variables.Exists ("HOME") then
         declare
            Candidate : constant String :=
              Ada.Environment_Variables.Value ("HOME") &
              "/.alire/libexec/spark/bin/" & Name;
         begin
            if Ada.Directories.Exists (Candidate) then
               return Candidate;
            end if;
         end;
      end if;
      return "";
   end Solver_Path;

   function First_Line (Filename : String) return String is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);
      declare
         Line : constant String :=
           (if Ada.Text_IO.End_Of_File (File)
            then "" else Ada.Text_IO.Get_Line (File));
      begin
         Ada.Text_IO.Close (File);
         return Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both);
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return "";
   end First_Line;

   function Run_Solver
     (Path       : String;
      Is_CVC5    : Boolean;
      Input_File : String) return Solver_Answer
   is
      Output_FD   : GNAT.OS_Lib.File_Descriptor;
      Output_Name : GNAT.OS_Lib.String_Access;
      Success     : Boolean := False;
      Return_Code : Integer := 0;
   begin
      if Path = "" then
         return Solver_Unavailable;
      end if;

      GNAT.OS_Lib.Create_Temp_Output_File (Output_FD, Output_Name);
      if Output_FD = GNAT.OS_Lib.Invalid_FD or else Output_Name = null then
         return Solver_Unknown;
      end if;
      GNAT.OS_Lib.Close (Output_FD);

      if Is_CVC5 then
         declare
            Args : GNAT.OS_Lib.Argument_List :=
              (1 => new String'("--lang=smt2"),
               2 => new String'("--tlimit=2000"),
               3 => new String'(Input_File));
         begin
            GNAT.OS_Lib.Spawn
              (Path, Args, Output_Name.all, Success, Return_Code,
               Err_To_Out => True);
            for Arg of Args loop
               GNAT.OS_Lib.Free (Arg);
            end loop;
         end;
      else
         declare
            Args : GNAT.OS_Lib.Argument_List :=
              (1 => new String'("-smt2"),
               2 => new String'("-t:2000"),
               3 => new String'(Input_File));
         begin
            GNAT.OS_Lib.Spawn
              (Path, Args, Output_Name.all, Success, Return_Code,
               Err_To_Out => True);
            for Arg of Args loop
               GNAT.OS_Lib.Free (Arg);
            end loop;
         end;
      end if;

      declare
         Line : constant String := First_Line (Output_Name.all);
         Deleted : Boolean := False;
      begin
         GNAT.OS_Lib.Delete_File (Output_Name.all, Deleted);
         if not Deleted then
            Log_Verbose ("could not remove solver output file");
         end if;
         GNAT.OS_Lib.Free (Output_Name);
         if not Success or else Return_Code /= 0 then
            return Solver_Unknown;
         elsif Line = "unsat" then
            return Solver_Unsat;
         elsif Line = "sat" then
            return Solver_Sat;
         else
            return Solver_Unknown;
         end if;
      end;
   exception
      when others =>
         if Output_Name /= null then
            declare
               Deleted : Boolean := False;
            begin
               GNAT.OS_Lib.Delete_File (Output_Name.all, Deleted);
               if not Deleted then
                  Log_Verbose ("could not remove solver output file");
               end if;
               GNAT.OS_Lib.Free (Output_Name);
            end;
         end if;
         return Solver_Unknown;
   end Run_Solver;

   function Query
     (Formula : String;
      Negate  : Boolean) return Solver_Answer
   is
      Input_FD   : GNAT.OS_Lib.File_Descriptor;
      Input_Name : GNAT.OS_Lib.String_Access;
      File       : Ada.Text_IO.File_Type;
      CVC5_Path  : constant String := Solver_Path ("cvc5", "ADALANG_CVC5");
      Z3_Path    : constant String := Solver_Path ("z3", "ADALANG_Z3");
      CVC5, Z3   : Solver_Answer;
      Deleted    : Boolean := False;
   begin
      if CVC5_Path = "" or else Z3_Path = "" then
         return Solver_Unavailable;
      end if;

      GNAT.OS_Lib.Create_Temp_File (Input_FD, Input_Name);
      if Input_FD = GNAT.OS_Lib.Invalid_FD or else Input_Name = null then
         return Solver_Unknown;
      end if;
      GNAT.OS_Lib.Close (Input_FD);
      Ada.Text_IO.Open (File, Ada.Text_IO.Out_File, Input_Name.all);
      Ada.Text_IO.Put_Line (File, "(set-logic ALL)");
      Ada.Text_IO.Put (File, Formula);
      Ada.Text_IO.Put_Line
        (File,
         "(assert " & (if Negate then "(not " else "") & "goal" &
           (if Negate then ")" else "") & ")");
      Ada.Text_IO.Put_Line (File, "(check-sat)");
      Ada.Text_IO.Close (File);

      CVC5 := Run_Solver (CVC5_Path, True, Input_Name.all);
      Z3 := Run_Solver (Z3_Path, False, Input_Name.all);
      GNAT.OS_Lib.Delete_File (Input_Name.all, Deleted);
      if not Deleted then
         Log_Verbose ("could not remove solver input file");
      end if;
      GNAT.OS_Lib.Free (Input_Name);

      if CVC5 = Z3 then
         return CVC5;
      else
         return Solver_Unknown;
      end if;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         if Input_Name /= null then
            GNAT.OS_Lib.Delete_File (Input_Name.all, Deleted);
            if not Deleted then
               Log_Verbose ("could not remove solver input file");
            end if;
            GNAT.OS_Lib.Free (Input_Name);
         end if;
         return Solver_Unknown;
   end Query;

   --  Shared solver core for Decide/Decide_Bounds/Decide_Nonzero: each only
   --  differs in how Goal is built (a translated source condition, or a
   --  synthesized containment/nonzero formula), never in how it is decided.
   function Decide_Goal
     (Goal    : Unbounded_String;
      Context : Translation_Context) return VC_Outcome
   is
      Formula : Unbounded_String;
      Negated : Solver_Answer;
      Direct  : Solver_Answer;
   begin
      Formula := Constraints (Context);
      Append
        (Formula,
         "(define-fun goal () Bool " & To_String (Goal) & ")" & ASCII.LF);
      Negated := Query (To_String (Formula), Negate => True);
      if Negated = Solver_Unavailable then
         return (Result => VC_Unavailable,
                 Provenance => No_Unsupported_Provenance);
      elsif Negated = Solver_Unsat then
         return (Result => VC_Proved,
                 Provenance => No_Unsupported_Provenance);
      end if;

      Direct := Query (To_String (Formula), Negate => False);
      if Direct = Solver_Unavailable then
         return (Result => VC_Unavailable,
                 Provenance => No_Unsupported_Provenance);
      elsif Direct = Solver_Unsat then
         return (Result => VC_Refuted,
                 Provenance => No_Unsupported_Provenance);
      else
         return Unknown_Outcome;
      end if;
   end Decide_Goal;

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Domain.Flow_State) return VC_Outcome
   is
   begin
      return Decide (Condition, State, Empty_Symbolic_State);
   end Decide;

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Domain.Flow_State;
      Symbols   : Symbolic_State) return VC_Outcome
   is
      Context : Translation_Context :=
        (State => State, Symbols => Symbols, Supported => Symbols.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Goal : Unbounded_String;
   begin
      Goal := Boolean_Term (Condition, Context);
      if not Context.Supported or else Length (Goal) = 0 then
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For (Context, Condition));
      end if;
      return Decide_Goal (Goal, Context);
   exception
      when others =>
         return Unknown_Outcome;
   end Decide;

   function Decide_Bounds
     (Value   : Libadalang.Analysis.Expr'Class;
      Bounds  : Domain.Abstract_Range;
      State   : Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome
   is
      Context : Translation_Context :=
        (State => State, Symbols => Symbols, Supported => Symbols.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Term : Unbounded_String;
      Goal : Unbounded_String;
   begin
      Term := Integer_Term (Value, Context);
      if not Context.Supported or else Length (Term) = 0
        or else (not Bounds.Has_Low and then not Bounds.Has_High)
      then
         if Context.Supported then
            Mark_Unsupported (Context, Value, Missing_Static_Bounds);
         end if;
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For (Context, Value));
      end if;

      if Bounds.Has_Low then
         Goal := To_Unbounded_String
           ("(<= " & SMT_Integer (Bounds.Low) & " " & To_String (Term) & ")");
      end if;
      if Bounds.Has_High then
         declare
            High_Term : constant String :=
              "(<= " & To_String (Term) & " " & SMT_Integer (Bounds.High) &
                ")";
         begin
            Goal :=
              (if Length (Goal) = 0 then To_Unbounded_String (High_Term)
               else To_Unbounded_String
                 ("(and " & To_String (Goal) & " " & High_Term & ")"));
         end;
      end if;

      return Decide_Goal (Goal, Context);
   exception
      when others =>
         return Unknown_Outcome;
   end Decide_Bounds;

   function Decide_Nonzero
     (Value   : Libadalang.Analysis.Expr'Class;
      State   : Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome
   is
      Context : Translation_Context :=
        (State => State, Symbols => Symbols, Supported => Symbols.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Term : Unbounded_String;
   begin
      Term := Integer_Term (Value, Context);
      if not Context.Supported or else Length (Term) = 0 then
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For (Context, Value));
      end if;
      return Decide_Goal
        (To_Unbounded_String ("(not (= " & To_String (Term) & " 0))"),
         Context);
   exception
      when others =>
         return Unknown_Outcome;
   end Decide_Nonzero;

   function Decide_Variant_Progress
     (Value          : Libadalang.Analysis.Expr'Class;
      Direction      : Loop_Variant_Direction;
      Bounds         : Domain.Abstract_Range;
      Before_State   : Domain.Flow_State;
      Before_Symbols : Symbolic_State;
      After_State    : Domain.Flow_State;
      After_Symbols  : Symbolic_State) return VC_Outcome
   is
      Before_Context : Translation_Context :=
        (State => Before_State, Symbols => Before_Symbols,
         Supported => Before_Symbols.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      After_Context : Translation_Context :=
        (State => After_State, Symbols => After_Symbols,
         Supported => After_Symbols.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Before_Term : Unbounded_String;
      After_Term  : Unbounded_String;
      Goal        : Unbounded_String;

      procedure Add_Bound_Goals
        (Term : Unbounded_String;
         Into : in out Unbounded_String)
      is
         procedure Add (Clause : String) is
         begin
            Into :=
              (if Length (Into) = 0 then To_Unbounded_String (Clause)
               else To_Unbounded_String
                 ("(and " & To_String (Into) & " " & Clause & ")"));
         end Add;
      begin
         if Bounds.Has_Low then
            Add
              ("(<= " & SMT_Integer (Bounds.Low) & " " &
                 To_String (Term) & ")");
         end if;
         if Bounds.Has_High then
            Add
              ("(<= " & To_String (Term) & " " &
                 SMT_Integer (Bounds.High) & ")");
         end if;
      end Add_Bound_Goals;

      procedure Add_Goal (Clause : String) is
      begin
         Goal :=
           (if Length (Goal) = 0 then To_Unbounded_String (Clause)
            else To_Unbounded_String
              ("(and " & To_String (Goal) & " " & Clause & ")"));
      end Add_Goal;
   begin
      if not Bounds.Has_Low or else not Bounds.Has_High then
         Mark_Unsupported (Before_Context, Value, Missing_Static_Bounds);
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For
              (Before_Context, Value));
      end if;

      Before_Term := Integer_Term (Value, Before_Context);
      if not Before_Context.Supported or else Length (Before_Term) = 0 then
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For
              (Before_Context, Value));
      end if;

      After_Term := Integer_Term (Value, After_Context);
      if not After_Context.Supported or else Length (After_Term) = 0 then
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For
              (After_Context, Value));
      end if;

      --  After_Symbols is normally derived from Before_Symbols and already
      --  contains these roots and assumptions. Merge explicitly so this
      --  query remains correct if a future transfer creates either term's
      --  first root only while translating it here.
      for Root of Before_Context.Symbols.Roots loop
         Include_Root (After_Context.Symbols, Root);
      end loop;
      for Assumption of Before_Context.Symbols.Assumptions loop
         declare
            Present : Boolean := False;
         begin
            for Existing of After_Context.Symbols.Assumptions loop
               if Existing = Assumption then
                  Present := True;
                  exit;
               end if;
            end loop;
            if not Present then
               After_Context.Symbols.Assumptions.Append (Assumption);
            end if;
         end;
      end loop;
      if not After_Context.Symbols.Supported then
         Mark_Unsupported (After_Context, Value, Sort_Mismatch);
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For
              (After_Context, Value));
      end if;

      Add_Bound_Goals (Before_Term, Goal);
      Add_Bound_Goals (After_Term, Goal);
      case Direction is
         when Decreases =>
            Add_Goal ("(>= " & To_String (Before_Term) & " 0)");
            Add_Goal
              ("(< " & To_String (After_Term) & " " &
                 To_String (Before_Term) & ")");
         when Increases =>
            Add_Goal
              ("(> " & To_String (After_Term) & " " &
                 To_String (Before_Term) & ")");
      end case;

      return Decide_Goal (Goal, After_Context);
   exception
      when others =>
         return Unknown_Outcome;
   end Decide_Variant_Progress;

   function Evidence return String is
     ("SMT-LIB scalar VC; CVC5 and Z3 agreement required");

   function Reason_Code (Reason : Unsupported_Reason) return String is
   begin
      case Reason is
         when No_Unsupported_Reason =>
            return "";
         when Null_Expression =>
            return "null-expression";
         when Uninitialized_Object =>
            return "uninitialized-object";
         when Sort_Mismatch =>
            return "sort-mismatch";
         when Unsupported_Expression_Kind =>
            return "unsupported-expression-kind";
         when Unsupported_Operator =>
            return "unsupported-operator";
         when Unsupported_Call =>
            return "unsupported-call";
         when Unsupported_Conversion =>
            return "unsupported-conversion";
         when Unsupported_Attribute =>
            return "unsupported-attribute";
         when Unsupported_Quantifier =>
            return "unsupported-quantifier";
         when Missing_Static_Bounds =>
            return "missing-static-bounds";
         when Unsafe_Divisor_Semantics =>
            return "unsafe-divisor-semantics";
         when Inline_Depth_Exceeded =>
            return "inline-depth-exceeded";
         when Callee_Not_Expression_Function =>
            return "callee-not-expression-function";
         when Writable_Formal =>
            return "writable-formal";
         when Record_Actual_Not_Object =>
            return "record-actual-not-object";
         when Translation_Error =>
            return "translation-error";
      end case;
   end Reason_Code;

   function Unsupported_Reason_Code (Outcome : VC_Outcome) return String is
     (Reason_Code (Outcome.Provenance.Reason));

   function Unsupported_Description (Outcome : VC_Outcome) return String is
   begin
      case Outcome.Provenance.Reason is
         when No_Unsupported_Reason =>
            return "";
         when Null_Expression =>
            return "the expression could not be resolved";
         when Uninitialized_Object =>
            return "the blocking object is not known to be initialized";
         when Sort_Mismatch =>
            return "the expression conflicts with its symbolic scalar sort";
         when Unsupported_Expression_Kind =>
            return "this expression form is outside the scalar VC subset";
         when Unsupported_Operator =>
            return "this operator is outside the scalar VC subset";
         when Unsupported_Call =>
            return "this call form cannot be inlined safely";
         when Unsupported_Conversion =>
            return "this conversion is not modeled conservatively";
         when Unsupported_Attribute =>
            return "this attribute is outside the scalar VC subset";
         when Unsupported_Quantifier =>
            return "this quantified-expression form is not modeled";
         when Missing_Static_Bounds =>
            return "the required bounds are not statically known";
         when Unsafe_Divisor_Semantics =>
            return "Ada division semantics require a provably nonzero divisor";
         when Inline_Depth_Exceeded =>
            return "expression-function inlining exceeded its depth limit";
         when Callee_Not_Expression_Function =>
            return "the callee is not a plain expression function";
         when Writable_Formal =>
            return "an out or in out formal prevents pure call inlining";
         when Record_Actual_Not_Object =>
            return "a record formal requires a plain object-reference actual";
         when Translation_Error =>
            return "semantic translation raised an internal property error";
      end case;
   end Unsupported_Description;

   function Blocking_Expression (Outcome : VC_Outcome) return String is
     (To_String (Outcome.Provenance.Blocking_Expression));

   function Inline_Path (Outcome : VC_Outcome) return String is
     (To_String (Outcome.Provenance.Inline_Path));

   procedure Dump_Symbolic_Diagnostics is
      use Ada.Text_IO;

      function Natural_Text (Value : Natural) return String is
        (Ada.Strings.Fixed.Trim (Natural'Image (Value), Ada.Strings.Both));
   begin
      if not Symbolic_Diagnostics_Enabled then
         return;
      end if;

      Put_Line
        (Standard_Error,
         "symbolic-diagnostics join-havoc=" &
           Natural_Text (Join_Havoc_Count));
      Put_Line
        (Standard_Error,
         "symbolic-diagnostics join-merge-survived=" &
           Natural_Text (Join_Merge_Survived_Count));
      Put_Line
        (Standard_Error,
         "symbolic-diagnostics join-merge-fresh=" &
           Natural_Text (Join_Merge_Fresh_Count));
      Put_Line
        (Standard_Error,
         "symbolic-diagnostics include-root-poison=" &
           Natural_Text (Include_Root_Poison_Count));

      for Cursor in Assign_Havoc_By_Kind.Iterate loop
         Put_Line
           (Standard_Error,
            "symbolic-diagnostics assign-havoc kind=" &
              Kind_Tally_Maps.Key (Cursor) & " count=" &
              Natural_Text (Kind_Tally_Maps.Element (Cursor)));
      end loop;
      for Cursor in Assume_Havoc_By_Kind.Iterate loop
         Put_Line
           (Standard_Error,
            "symbolic-diagnostics assume-havoc kind=" &
              Kind_Tally_Maps.Key (Cursor) & " count=" &
              Natural_Text (Kind_Tally_Maps.Element (Cursor)));
      end loop;
   end Dump_Symbolic_Diagnostics;

end Adalang_Analyzer.VC_Prover;
