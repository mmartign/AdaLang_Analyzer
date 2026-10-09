--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Ordered_Maps;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Strings.Unbounded.Hash;
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
   use type Adalang_Analyzer.Flow_Domain.Object_Class;
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
   --
   --  The name also carries a number for the object's file. A subprogram's
   --  declaration and its body are in two files, and objects of the two
   --  can be declared at the same line and column: under one name, what
   --  is known of one would be taken for the other (FP-110).
   package File_Number_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Positive,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");
   File_Numbers : File_Number_Maps.Map;

   procedure Number_File (Filename : String; Number : out Positive) is
      Position : constant File_Number_Maps.Cursor :=
        File_Numbers.Find (Filename);
   begin
      if File_Number_Maps.Has_Element (Position) then
         Number := File_Number_Maps.Element (Position);
      else
         Number := Natural (File_Numbers.Length) + 1;
         File_Numbers.Insert (Filename, Number);
      end if;
   end Number_File;

   --  The number of a file as a symbol carries it. Files are numbered as
   --  the analysis meets them, so the number of one depends on which other
   --  files were analyzed before it. A query must not: a solver's answer
   --  to a formula at the edge of what it decides can change with the
   --  names in it, and the verdict on a subprogram would then depend on
   --  what else the run analyzed. Renumbered gives a query numbers of its
   --  own before it is sent.
   File_Mark_Character : constant Character := '#';

   function File_Mark (File : Positive) return String is
     (File_Mark_Character & Natural_Image (File) & File_Mark_Character);

   package File_Rank_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Positive);

   --  Formula with each file number, as File_Mark wrote it, replaced by
   --  the rank of that file among those Formula names, in the order it
   --  names them. Two files keep two numbers.
   function Renumbered (Formula : String) return String is
      Result : Unbounded_String;
      Seen   : File_Rank_Vectors.Vector;
      Index  : Natural := Formula'First;

      function Rank (File : Positive) return Positive is
      begin
         for Position in 1 .. Natural (Seen.Length) loop
            if Seen.Element (Position) = File then
               return Position;
            end if;
         end loop;
         Seen.Append (File);
         return Positive (Seen.Length);
      end Rank;
   begin
      while Index <= Formula'Last loop
         declare
            Stop : Natural := Index + 1;
         begin
            if Formula (Index) = File_Mark_Character then
               while Stop <= Formula'Last
                 and then Formula (Stop) in '0' .. '9'
               loop
                  Stop := Stop + 1;
               end loop;
            end if;

            if Formula (Index) = File_Mark_Character
              and then Stop > Index + 1
              and then Stop <= Formula'Last
              and then Formula (Stop) = File_Mark_Character
            then
               Append
                 (Result,
                  Natural_Image
                    (Rank (Positive'Value (Formula (Index + 1 .. Stop - 1)))));
               Index := Stop + 1;
            else
               Append (Result, Formula (Index));
               Index := Index + 1;
            end if;
         end;
      end loop;
      return To_String (Result);
   end Renumbered;

   function Root_Name
     (Key    : Symbol_Key;
      Prefix : String := "b") return String
   is
      File : Positive;
   begin
      Number_File (Key.Object.Unit.Get_Filename, File);
      declare
         Object_Name : constant String :=
           Prefix & File_Mark (File) & "_" &
           Natural_Image (Natural (Key.Object.Sloc_Range.Start_Line)) & "_" &
           Natural_Image (Natural (Key.Object.Sloc_Range.Start_Column));
      begin
         if Libadalang.Analysis.Is_Null (Key.Component) then
            return Object_Name;
         end if;
         return Object_Name & "_" &
           Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
             (Adalang_Analyzer.Ada_Text.Node_Text (Key.Component));
      end;
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

   function Alias_Object
     (State    : Symbolic_State;
      From, To : Libadalang.Analysis.Ada_Node) return Symbolic_State
   is
      Result : Symbolic_State := State;

      procedure Bind (Key : Symbol_Key; Sort : Scalar_Sort; Term : String) is
         --  A value key's component is the object itself.
         Target : constant Symbol_Key :=
           (Object    => To,
            Component => (if Key.Component = From then To
                          else Key.Component));
         Index  : constant Natural := Binding_Index (Result, Target);
         Item   : constant Symbolic_Binding :=
           (Key => Target, Sort => Sort, Term => To_Unbounded_String (Term));
      begin
         if Index = 0 then
            Result.Bindings.Append (Item);
         else
            Result.Bindings.Replace_Element (Index, Item);
         end if;
      end Bind;
   begin
      if Libadalang.Analysis.Is_Null (From)
        or else Libadalang.Analysis.Is_Null (To)
      then
         return Result;
      end if;

      --  An unassigned key still denotes its root; an assigned one, its
      --  binding's term. Bindings are applied last so they win.
      for Root of State.Roots loop
         if Root.Key.Object = From
           and then Binding_Index (State, Root.Key) = 0
         then
            Bind (Root.Key, Root.Sort, To_String (Root.Name));
         end if;
      end loop;
      for Binding of State.Bindings loop
         if Binding.Key.Object = From then
            Bind (Binding.Key, Binding.Sort, To_String (Binding.Term));
         end if;
      end loop;
      return Result;
   end Alias_Object;

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

   Component_Subtypes_Hold : Boolean := False;

   procedure Assume_Component_Subtypes (Enabled : Boolean) is
   begin
      Component_Subtypes_Hold := Enabled;
   end Assume_Component_Subtypes;

   --  The bounds of the root for a scalar component of a record object:
   --  where Assume_Component_Subtypes says so, those of the subtype the
   --  component is declared with, as far as they are fixed whatever the
   --  state. A root for the value of a whole object (Value_Key) has none.
   function Component_Bounds (Key : Symbol_Key) return Domain.Abstract_Range
   is
   begin
      if not Component_Subtypes_Hold or else Key.Component = Key.Object then
         return Domain.Unknown_Range;
      end if;
      return Eval.Declared_Range (Key.Component);
   end Component_Bounds;

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
           then Component_Bounds (Key)
         else Domain.Flow_Range_Lookup (Flow, Key.Object));
      Has_Low     : constant Boolean :=
        Sort in Integer_Sort | Enum_Sort and then Range_Value.Has_Low;
      Has_High    : constant Boolean :=
        Sort in Integer_Sort | Enum_Sort and then Range_Value.Has_High;
      Existing    : constant Natural := Root_Index (State, Name);
   begin
      if Existing /= 0 then
         --  The fixed-point run reaches a merge point more than once, each
         --  time minting the same root name for the same object from a
         --  flow state that has grown since. The root must cover every
         --  value seen so far: keeping the bounds of the first visit would
         --  leave it confined to an early, narrower interval (FP-090).
         declare
            Current : Symbol_Root := State.Roots.Element (Existing);
         begin
            if Current.Has_Low and then Has_Low then
               Current.Low :=
                 Long_Long_Integer'Min (Current.Low, Range_Value.Low);
            else
               Current.Has_Low := False;
            end if;
            if Current.Has_High and then Has_High then
               Current.High :=
                 Long_Long_Integer'Max (Current.High, Range_Value.High);
            else
               Current.Has_High := False;
            end if;
            State.Roots.Replace_Element (Existing, Current);
         end;
         return;
      end if;

      State.Roots.Append
        ((Name     => To_Unbounded_String (Name),
          Key      => Key,
          Sort     => Sort,
          Has_Low  => Has_Low,
          Low      => Range_Value.Low,
          Has_High => Has_High,
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
      elsif Domain.Classify (Key.Object) /= Domain.Tracked then
         --  Two reads of a volatile, aliased or renamed object need not see
         --  the same value, so no symbol can stand for it (FP-092).
         Mark_Unsupported (Context, Key.Object, Unsupported_Expression_Kind);
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
      elsif not Libadalang.Analysis.Is_Null (Eval.Expanded_Name_Target (Node))
      then
         return Divisor_Provably_Nonzero
           (Eval.Expanded_Name_Target (Node), State);
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
   --  subtype ("subtype S is T range A .. B") nor a character type:
   --  Domain.Unknown_Range for anything else, the same conservative fallback used throughout this
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

      --  Libadalang declares Standard's character types with a single
      --  placeholder literal ("type Character is ('A')"), so counting
      --  literals would confine every Character to position 0 and make any
      --  two of them provably equal (FP-089).
      if Typ.P_Is_Char_Type then
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

   --  The term for a call: its inlined body where Inlined_Call_Term gives
   --  one, and otherwise the application of the function to its
   --  arguments, when the oracle says the callee is a function of them.
   function Call_Term
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

   --  A parameter has one defining name in the subprogram's declaration
   --  and another in its body; contracts use the first, the body's own
   --  statements the second. For a body's parameter this is its namesake in
   --  the declaration the body completes, so that both stand for one
   --  object; any other key is returned as it is. Only a precise
   --  resolution is followed.
   function Declaration_Formal
     (Key : Libadalang.Analysis.Ada_Node) return Libadalang.Analysis.Ada_Node
   is
      Current : Libadalang.Analysis.Ada_Node := Key;
   begin
      while not Libadalang.Analysis.Is_Null (Current)
        and then Current.Kind not in Libadalang.Common.Ada_Basic_Decl
      loop
         Current := Current.Parent;
      end loop;
      if Libadalang.Analysis.Is_Null (Current)
        or else Current.Kind /= Libadalang.Common.Ada_Param_Spec
      then
         return Key;
      end if;

      while not Libadalang.Analysis.Is_Null (Current)
        and then Current.Kind not in Libadalang.Common.Ada_Base_Subp_Body
      loop
         exit when Current.Kind in Libadalang.Common.Ada_Basic_Subp_Decl;
         Current := Current.Parent;
      end loop;
      if Libadalang.Analysis.Is_Null (Current)
        or else Current.Kind not in Libadalang.Common.Ada_Base_Subp_Body
      then
         return Key;
      end if;

      declare
         Part : constant Libadalang.Analysis.Basic_Decl :=
           Current.As_Base_Subp_Body.P_Decl_Part;
         Name : constant String :=
           Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
             (Adalang_Analyzer.Ada_Text.Node_Text (Key));
      begin
         if Libadalang.Analysis.Is_Null (Part)
           or else Libadalang.Analysis.Ada_Node (Part) = Current
         then
            return Key;
         end if;
         for Param of Part.P_Subp_Spec_Or_Null.P_Params loop
            for Id of Param.F_Ids loop
               if Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                    (Adalang_Analyzer.Ada_Text.Node_Text (Id)) = Name
               then
                  return Libadalang.Analysis.Ada_Node (Id);
               end if;
            end loop;
         end loop;
      end;
      return Key;
   exception
      when others =>
         return Key;
   end Declaration_Formal;

   --  The defining name of the array object Prefix names, directly or by
   --  an expanded name: a declared object or a parameter of an array type.
   --  Its bounds are fixed for as long as the name is visible, which is
   --  what lets one symbol stand for each of them. No_Ada_Node for a
   --  component, a dereference, a call or a type: a component's defining
   --  name is shared by every object of the record type, and what a
   --  dereference denotes can change.
   function Array_Object_Key
     (Context : Translation_Context;
      Prefix  : Libadalang.Analysis.Ada_Node'Class)
      return Libadalang.Analysis.Ada_Node
   is
      Id : constant Libadalang.Analysis.Ada_Node :=
        (if Libadalang.Analysis.Is_Null (Prefix)
           then Libadalang.Analysis.No_Ada_Node
         elsif Prefix.Kind = Libadalang.Common.Ada_Identifier
           then Libadalang.Analysis.Ada_Node (Prefix)
         else Eval.Expanded_Name_Target (Prefix));
   begin
      if Libadalang.Analysis.Is_Null (Id) then
         return Libadalang.Analysis.No_Ada_Node;
      end if;

      declare
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Id.As_Name.P_Referenced_Decl;
         Typ  : constant Libadalang.Analysis.Base_Type_Decl :=
           Id.As_Expr.P_Expression_Type;
      begin
         if Libadalang.Analysis.Is_Null (Decl)
           or else Decl.Kind not in Libadalang.Common.Ada_Object_Decl_Range
                                  | Libadalang.Common.Ada_Param_Spec
           or else Libadalang.Analysis.Is_Null (Typ)
           or else not Typ.P_Is_Array_Type
           or else Typ.P_Is_Access_Type
         then
            return Libadalang.Analysis.No_Ada_Node;
         end if;
      end;
      return Object_Identity (Context, Declaration_Formal (Referenced_Key (Id)));
   exception
      when others =>
         return Libadalang.Analysis.No_Ada_Node;
   end Array_Object_Key;

   --  The dimension an attribute reference names: 1 without an argument,
   --  the argument's value when it is a plain decimal literal, and 0 for
   --  anything else.
   function Attribute_Dimension
     (Attr : Libadalang.Analysis.Attribute_Ref) return Natural
   is
   begin
      if Attr.F_Args.Children_Count = 0 then
         return 1;
      elsif Attr.F_Args.Children_Count /= 1 then
         return 0;
      end if;

      declare
         Arg  : constant Libadalang.Analysis.Ada_Node := Attr.F_Args.Child (1);
         Expr : constant Libadalang.Analysis.Ada_Node :=
           (if Arg.Kind = Libadalang.Common.Ada_Param_Assoc
            then Libadalang.Analysis.Ada_Node (Arg.As_Param_Assoc.F_R_Expr)
            else Arg);
      begin
         if Expr.Kind /= Libadalang.Common.Ada_Int_Literal then
            return 0;
         end if;
         declare
            Image : constant String :=
              Adalang_Analyzer.Ada_Text.Node_Text (Expr);
         begin
            if Image'Length not in 1 .. 2
              or else (for some Item of Image => Item not in '0' .. '9')
            then
               return 0;
            end if;
            return Natural'Value (Image);
         end;
      end;
   exception
      when others =>
         return 0;
   end Attribute_Dimension;

   --  The term for Prefix'First, Prefix'Last or Prefix'Length (Name, in
   --  normalized form) of the Dimension-th index. A bound a declaration
   --  fixes is its literal value. Otherwise, for an array object, the
   --  three attributes are symbols of their own -- the bounds of a
   --  declared object or a parameter never change -- tied together by
   --  what the language guarantees: Length is Last - First + 1 when that
   --  is positive, and 0 for an empty array.
   function Array_Attribute_Term
     (Prefix    : Libadalang.Analysis.Name;
      Name      : String;
      Node      : Libadalang.Analysis.Ada_Node'Class;
      Context   : in out Translation_Context;
      Dimension : Positive := 1) return Unbounded_String
   is
      --  The first dimension keeps the plain names; a later one carries
      --  its number, which the extra underscore keeps apart from them.
      Tag : constant String :=
        (if Dimension = 1 then "" else Natural_Image (Dimension) & "_");
      Prefix_Decl : Libadalang.Analysis.Basic_Decl :=
        Libadalang.Analysis.No_Basic_Decl;
      Bounds      : Domain.Abstract_Range := Domain.Unknown_Range;
   begin
      if Prefix.Kind in Libadalang.Common.Ada_Name then
         Prefix_Decl := Prefix.P_Referenced_Decl;
      end if;

      if not Libadalang.Analysis.Is_Null (Prefix_Decl)
        and then Prefix_Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
      then
         --  X'First/'Last/'Length where X is itself a subtype mark: of a
         --  constrained array subtype, whose bounds are those of all its
         --  objects, or of a discrete subtype (Some_Subtype'Last).
         if Prefix_Decl.As_Base_Type_Decl.P_Is_Array_Type then
            Bounds := Eval.Array_Index_Range
              (Prefix_Decl.As_Base_Type_Decl, Dimension, Context.State);
         elsif Dimension /= 1 then
            Mark_Unsupported (Context, Node, Unsupported_Attribute);
            return Null_Unbounded_String;
         else
            Bounds := Eval.Type_Range
              (Prefix_Decl.As_Base_Type_Decl, Context.State);
         end if;
      else
         --  X'First/'Last/'Length where X is an array object.
         Bounds :=
           Eval.Array_Object_Index_Range (Prefix, Dimension, Context.State);
      end if;

      if Name = "first" and then Bounds.Has_Low then
         return To_Unbounded_String (SMT_Integer (Bounds.Low));
      elsif Name = "last" and then Bounds.Has_High then
         return To_Unbounded_String (SMT_Integer (Bounds.High));
      elsif Name = "length" and then Bounds.Has_Low and then Bounds.Has_High
      then
         return To_Unbounded_String
           (if Bounds.Low > Bounds.High then "0"
            else SMT_Integer (Bounds.High - Bounds.Low + 1));
      end if;

      declare
         Object_Key : constant Libadalang.Analysis.Ada_Node :=
           Array_Object_Key (Context, Prefix);
      begin
         if Libadalang.Analysis.Is_Null (Object_Key) then
            Mark_Unsupported (Context, Node, Missing_Static_Bounds);
            return Null_Unbounded_String;
         end if;

         declare
            Key    : constant Symbol_Key := Plain_Key (Object_Key);
            First  : constant String := Root_Name (Key, "af" & Tag);
            Last   : constant String := Root_Name (Key, "al" & Tag);
            Length : constant String := Root_Name (Key, "an" & Tag);
            Link   : constant Unbounded_String :=
              To_Unbounded_String
                ("(= " & Length & " (ite (<= " & First & " " & Last &
                 ") (+ (- " & Last & " " & First & ") 1) 0))");
            Linked : Boolean := False;
         begin
            --  A bound one declaration does fix pins its symbol, so the
            --  literal and the symbol can never disagree.
            Add_Root
              (Context.Symbols, First, Key, Integer_Sort, Context.State,
               Explicit_Bounds =>
                 (if Bounds.Has_Low
                  then (Has_Low => True, Low => Bounds.Low,
                        Has_High => True, High => Bounds.Low)
                  else Domain.Unknown_Range));
            Add_Root
              (Context.Symbols, Last, Key, Integer_Sort, Context.State,
               Explicit_Bounds =>
                 (if Bounds.Has_High
                  then (Has_Low => True, Low => Bounds.High,
                        Has_High => True, High => Bounds.High)
                  else Domain.Unknown_Range));
            Add_Root
              (Context.Symbols, Length, Key, Integer_Sort, Context.State,
               Explicit_Bounds => (Has_Low => True, Low => 0, others => <>));

            for Item of Context.Symbols.Assumptions loop
               Linked := Linked or else Item = Link;
            end loop;
            if not Linked then
               Context.Symbols.Assumptions.Append (Link);
            end if;

            return To_Unbounded_String
              (if Name = "first" then First
               elsif Name = "last" then Last
               else Length);
         end;
      end;
   end Array_Attribute_Term;

   function Integer_Term_Unwrapped
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         Mark_Unsupported (Context, Node, Null_Expression);
         return Null_Unbounded_String;
      elsif not Libadalang.Analysis.Is_Null (Eval.Expanded_Name_Target (Node))
      then
         --  "Pkg.Obj" is Obj.
         return Integer_Term (Eval.Expanded_Name_Target (Node), Context);
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

               --  Nor is a named number an object: it is its value.
               declare
                  Number : constant Domain.Abstract_Int :=
                    Eval.Named_Number_Value (Node);
               begin
                  if Number.Known then
                     return To_Unbounded_String (SMT_Integer (Number.Value));
                  end if;
               end;
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
               --  T'Succ(X)/T'Pred(X) on a discrete integer-valued
               --  expression translates to plain +1/-1. Libadalang parses
               --  this as a CallExpr whose F_Name is the bare attribute
               --  ref (T'Succ, no args of its own) and whose F_Suffix
               --  carries the single argument -- Call.P_Kind's five kinds
               --  (Call/Array_Slice/Array_Index/Type_Conversion/Family_
               --  Index) don't classify an attribute call at all, so this
               --  is checked ahead of the P_Kind dispatch below rather
               --  than folded into it. Anything other than this exact
               --  shape (an enum 'Succ/'Pred, a missing/extra argument, a
               --  non-integer result) falls through unchanged to the
               --  P_Kind dispatch, which correctly marks it Unsupported.
               if Call.F_Name.Kind = Libadalang.Common.Ada_Attribute_Ref then
                  declare
                     Attr_Name : constant String :=
                       Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                         (Adalang_Analyzer.Ada_Text.Node_Text
                            (Call.F_Name.As_Attribute_Ref.F_Attribute));
                  begin
                     if Attr_Name in "succ" | "pred" then
                        declare
                           Sort_Info : constant Sort_Resolution :=
                             Expression_Sort (Node);
                           Operand   : constant Libadalang.Analysis.Expr :=
                             Single_Actual_Expr (Call.F_Suffix);
                        begin
                           if not Sort_Info.Supported
                             or else Sort_Info.Sort /= Integer_Sort
                             or else Libadalang.Analysis.Is_Null (Operand)
                           then
                              Mark_Unsupported
                                (Context, Node, Unsupported_Attribute);
                              return Null_Unbounded_String;
                           end if;

                           declare
                              Term : constant String :=
                                To_String (Integer_Term (Operand, Context));
                           begin
                              return To_Unbounded_String
                                ((if Attr_Name = "succ"
                                  then "(+ " else "(- ") &
                                   Term & " 1)");
                           end;
                        end;
                     end if;
                  end;
               end if;

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
                     return Call_Term (Call, Context, Integer_Sort);

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
               --  T'Size of a static discrete subtype is a number.
               if Name = "size" then
                  declare
                     Size : constant Domain.Abstract_Int :=
                       Eval.Integer_Value (Node);
                  begin
                     if Size.Known then
                        return To_Unbounded_String (SMT_Integer (Size.Value));
                     end if;
                     Mark_Unsupported (Context, Node, Unsupported_Attribute);
                     return Null_Unbounded_String;
                  end;
               end if;

               --  Otherwise 'First/'Last/'Length only, of the dimension a
               --  literal argument names (the first without one), and no
               --  attempt at 'Range (not itself integer-valued) or any
               --  other attribute. A wrong guess here only costs
               --  Unsupported, never an incorrect bound.
               if Attribute_Dimension (Attr) = 0
                 or else Name not in "first" | "last" | "length"
               then
                  Mark_Unsupported (Context, Node, Unsupported_Attribute);
                  return Null_Unbounded_String;
               end if;

               return Array_Attribute_Term
                 (Attr.F_Prefix, Name, Node, Context,
                  Attribute_Dimension (Attr));
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
   end Integer_Term_Unwrapped;

   function Integer_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String
   is
      Term : Unbounded_String;
   begin
      --  An operator a declaration defines is a call of that function, not
      --  the operation its symbol reads as (FP-116).
      if Eval.Is_User_Operator (Node) then
         Mark_Unsupported (Context, Node, Unsupported_Call);
         return Null_Unbounded_String;
      end if;

      Term := Integer_Term_Unwrapped (Node, Context);
      if not Context.Supported or else Length (Term) = 0
        or else Libadalang.Analysis.Is_Null (Node)
        or else Node.Kind not in Libadalang.Common.Ada_Un_Op
                               | Libadalang.Common.Ada_Bin_Op_Range
      then
         return Term;
      end if;

      --  Modular arithmetic wraps: the mathematical term is the Ada value
      --  only after reduction by the modulus (FP-091). "/", "mod" and
      --  "rem" stay within the type's range on their own; anything else
      --  without a known modulus is outside the translation.
      declare
         Is_Modular : Boolean;
         Modulus    : constant Domain.Abstract_Int :=
           Eval.Expression_Modulus (Node, Is_Modular);
         Op         : constant Libadalang.Common.Ada_Node_Kind_Type :=
           (if Node.Kind = Libadalang.Common.Ada_Un_Op
            then Libadalang.Common.Ada_Node_Kind_Type'(Node.As_Un_Op.F_Op)
            else Libadalang.Common.Ada_Node_Kind_Type'(Node.As_Bin_Op.F_Op));
      begin
         if not Is_Modular
           or else Op in Libadalang.Common.Ada_Op_Div
                       | Libadalang.Common.Ada_Op_Mod
                       | Libadalang.Common.Ada_Op_Rem
           or else
             (Node.Kind = Libadalang.Common.Ada_Un_Op
              and then Op = Libadalang.Common.Ada_Op_Plus)
         then
            return Term;
         elsif Modulus.Known
           and then Op in Libadalang.Common.Ada_Op_Plus
                        | Libadalang.Common.Ada_Op_Minus
                        | Libadalang.Common.Ada_Op_Mult
         then
            --  The reduction costs the solvers dearly, so it is left out
            --  when the operands' intervals already show the mathematical
            --  result within the type's range: Range_Value reduces a
            --  result that can wrap to the whole range, so anything
            --  narrower was computed without wrapping.
            declare
               Bounds : constant Domain.Abstract_Range :=
                 Eval.Range_Value (Node, Context.State);
            begin
               if Bounds.Has_Low and then Bounds.Has_High
                 and then Bounds.Low >= 0
                 and then Bounds.High < Modulus.Value
                 and then
                   (Bounds.Low > 0 or else Bounds.High < Modulus.Value - 1)
               then
                  return Term;
               end if;
            end;

            --  A product of two unknowns reduced by a modulus is beyond
            --  what the solvers decide within their time limit. All that
            --  is kept of it is that it is some value of the type: a
            --  symbol bounded by the modulus and named after this operator
            --  and its two operand terms, so that the same operands give
            --  the same symbol and different ones never do.
            if Op = Libadalang.Common.Ada_Op_Mult
              and then not Eval.Integer_Value
                (Node.As_Bin_Op.F_Left, Context.State).Known
              and then not Eval.Integer_Value
                (Node.As_Bin_Op.F_Right, Context.State).Known
            then
               declare
                  function Unquoted (Text : String) return String is
                     Result : String := Text;
                  begin
                     for Item of Result loop
                        if Item in '|' | '\' then
                           Item := '!';
                        end if;
                     end loop;
                     return Result;
                  end Unquoted;

                  Key   : constant Symbol_Key :=
                    Plain_Key (Libadalang.Analysis.Ada_Node (Node));
                  Left  : constant String :=
                    To_String (Integer_Term (Node.As_Bin_Op.F_Left, Context));
                  Right : constant String :=
                    To_String
                      (Integer_Term (Node.As_Bin_Op.F_Right, Context));
                  Name  : constant String :=
                    "|" & Root_Name (Key, "mm") & " " & Unquoted (Left) &
                    " * " & Unquoted (Right) & "|";
               begin
                  if not Context.Supported then
                     return Null_Unbounded_String;
                  end if;
                  Add_Root
                    (Context.Symbols, Name, Key, Integer_Sort, Context.State,
                     Explicit_Bounds =>
                       (Has_Low => True, Low => 0,
                        Has_High => True, High => Modulus.Value - 1));
                  return To_Unbounded_String (Name);
               end;
            end if;
            return To_Unbounded_String
              ("(mod " & To_String (Term) & " " &
               SMT_Integer (Modulus.Value) & ")");
         end if;
         Mark_Unsupported (Context, Node, Unsupported_Operator);
         return Null_Unbounded_String;
      end;
   end Integer_Term;

   function Boolean_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         Mark_Unsupported (Context, Node, Null_Expression);
         return Null_Unbounded_String;
      elsif Eval.Is_User_Operator (Node) then
         --  A call of the function that defines the operator (FP-116).
         Mark_Unsupported (Context, Node, Unsupported_Call);
         return Null_Unbounded_String;
      elsif not Libadalang.Analysis.Is_Null (Eval.Expanded_Name_Target (Node))
      then
         return Boolean_Term (Eval.Expanded_Name_Target (Node), Context);
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
            elsif Eval.Is_Boolean_Literal (Node) then
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
               return Call_Term (Call, Context, Boolean_Sort);
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
                  elsif Alternative.Kind = Libadalang.Common.Ada_Attribute_Ref
                    and then Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                      (Adalang_Analyzer.Ada_Text.Node_Text
                         (Alternative.As_Attribute_Ref.F_Attribute)) = "range"
                    and then Attribute_Dimension
                      (Alternative.As_Attribute_Ref) /= 0
                  then
                     --  "X in A'Range" is "X in A'First .. A'Last".
                     declare
                        Dimension : constant Positive :=
                          Attribute_Dimension (Alternative.As_Attribute_Ref);
                        Low  : constant Unbounded_String :=
                          Array_Attribute_Term
                            (Alternative.As_Attribute_Ref.F_Prefix, "first",
                             Alternative, Context, Dimension);
                        High : constant Unbounded_String :=
                          Array_Attribute_Term
                            (Alternative.As_Attribute_Ref.F_Prefix, "last",
                             Alternative, Context, Dimension);
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
                          and then Eval.Has_Subtype_Predicate
                            (Type_Decl.As_Base_Type_Decl)
                        then
                           --  The members of a predicated subtype are a
                           --  subset of its range, so the range shape below
                           --  would wrongly admit every in-range value: its
                           --  negation ("not in") then proves a non-member
                           --  out of range (FP-086).
                           Mark_Unsupported
                             (Context, Alternative,
                              Unsupported_Expression_Kind);
                           return Null_Unbounded_String;
                        elsif not Libadalang.Analysis.Is_Null (Type_Decl)
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
         Bound  : Natural := 0;

         --  The formal the body is written with. A call that is resolved
         --  to a declaration the expression function completes gives the
         --  formals of that declaration, and the expression names those of
         --  the completion: what a formal is bound to has to be bound to
         --  the one the expression names, or it reads there as an object
         --  nothing is known of, and the same one at every call (FP-118).
         function Own_Formal
           (Formal : Libadalang.Analysis.Defining_Name'Class)
            return Libadalang.Analysis.Ada_Node
         is
            Name : constant String :=
              Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                (Adalang_Analyzer.Ada_Text.Node_Text (Formal));
         begin
            for Param of Decl.As_Expr_Function.F_Subp_Spec.P_Params loop
               for Id of Param.F_Ids loop
                  if Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                       (Adalang_Analyzer.Ada_Text.Node_Text (Id)) = Name
                  then
                     return Libadalang.Analysis.Ada_Node (Id);
                  end if;
               end loop;
            end loop;
            return Libadalang.Analysis.No_Ada_Node;
         end Own_Formal;

         function Formal_Count return Natural is
            Result : Natural := 0;
         begin
            for Param of Decl.As_Expr_Function.F_Subp_Spec.P_Params loop
               Result := Result + Param.F_Ids.Children_Count;
            end loop;
            return Result;
         end Formal_Count;
      begin
         Callee.Depth := Context.Depth + 1;
         Callee.Inlining_Path := Appended_Path (Context.Inlining_Path, Call);

         for Pair of Call.F_Name.P_Call_Params loop
            declare
               Formal : constant Libadalang.Analysis.Defining_Name'Class :=
                 Libadalang.Analysis.Param (Pair);
               Actual : constant Libadalang.Analysis.Expr'Class :=
                 Libadalang.Analysis.Actual (Pair);
               Named  : constant Libadalang.Analysis.Ada_Node :=
                 Own_Formal (Formal);
            begin
               if Formal_Is_Writable (Formal) then
                  Mark_Unsupported (Callee, Call, Writable_Formal);
                  Copy_Failure (Context, Callee);
                  return Null_Unbounded_String;
               elsif Libadalang.Analysis.Is_Null (Named) then
                  Mark_Unsupported (Callee, Call, Unsupported_Call);
                  Copy_Failure (Context, Callee);
                  return Null_Unbounded_String;
               end if;
               Bound := Bound + 1;

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
                     Set_Object_Binding (Callee, Named, Actual_Key);
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
                        when Opaque_Sort =>
                           --  Formal_Sort gives scalar sorts only.
                           Mark_Unsupported
                             (Context, Actual, Unsupported_Expression_Kind);
                           return Null_Unbounded_String;
                     end case;

                     if not Context.Supported then
                        return Null_Unbounded_String;
                     end if;

                     Set_Binding
                       (Callee.Symbols,
                        (Key  => Plain_Key (Named),
                         Sort => Formal_Sort_Info.Sort,
                         Term => Term));
                  end;
               end if;

               --  Scalar identifier translation and record dotted-name
               --  translation both require the formal to be initialized in
               --  the callee's scratch flow state.
               Domain.Flow_Set_Initialized
                 (Callee.State, Named, Domain.Bool_True);
            end;
         end loop;

         --  A formal the call leaves to its default is bound to nothing.
         if Bound /= Formal_Count then
            Mark_Unsupported (Callee, Call, Unsupported_Call);
            Copy_Failure (Context, Callee);
            return Null_Unbounded_String;
         end if;

         --  The actuals were translated in the caller's context: a symbol
         --  one of them is the first to use is declared there, and the
         --  declarations of the body are added to those, not put in their
         --  place.
         Callee.Symbols.Roots := Context.Symbols.Roots;

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
               when Enum_Sort | Opaque_Sort =>
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

   ------------------------------------------------------------------
   --  Function terms
   ------------------------------------------------------------------

   Function_Of_Arguments : Function_Oracle := null;

   procedure Set_Function_Oracle (Oracle : Function_Oracle) is
   begin
      Function_Of_Arguments := Oracle;
   end Set_Function_Oracle;

   --  The key under which the value of a whole object that is not a
   --  scalar is kept. Its component is the object itself, which no record
   --  component is, so that it meets neither the object's scalar
   --  components nor the bound symbols of an array, all keyed by the
   --  object.
   function Value_Key
     (Object : Libadalang.Analysis.Ada_Node) return Symbol_Key
   is (Object => Object, Component => Object);

   --  True for the type of a value that can stand as a token: not one of
   --  the scalar sorts, which have terms of their own, not a task or a
   --  protected type, whose state other tasks change, and not volatile.
   function Is_Opaque_Type
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return Boolean
   is
      function Marked (Name : String) return Boolean is
        (Typ.P_Has_Aspect
           (Langkit_Support.Text.To_Unbounded_Text
              (Langkit_Support.Text.To_Text (Name))));
   begin
      if Libadalang.Analysis.Is_Null (Typ) or else Type_Sort (Typ).Supported
      then
         return False;
      end if;

      declare
         Full : constant Libadalang.Analysis.Base_Type_Decl :=
           Typ.P_Full_View;
      begin
         if Typ.Kind in Libadalang.Common.Ada_Task_Type_Decl_Range
                      | Libadalang.Common.Ada_Protected_Type_Decl
           or else
             (not Libadalang.Analysis.Is_Null (Full)
              and then Full.Kind in
                Libadalang.Common.Ada_Task_Type_Decl_Range
                  | Libadalang.Common.Ada_Protected_Type_Decl)
         then
            return False;
         end if;
      end;
      return not (Marked ("Volatile") or else Marked ("Atomic")
                  or else Marked ("Volatile_Full_Access"));
   exception
      when others =>
         return False;
   end Is_Opaque_Type;

   --  The name of the function symbol for the declaration whose defining
   --  name is Name: the place of that name, then Profile, which is the
   --  instantiations it was reached through -- one generic function is a
   --  different function in each instance -- a "!", and the sorts of the
   --  arguments and the result, from which Function_Declarations declares
   --  it.
   function Function_Symbol
     (Name    : Libadalang.Analysis.Ada_Node'Class;
      Profile : String) return String
   is
      File : Positive;
   begin
      Number_File (Name.Unit.Get_Filename, File);
      return "|f!" & File_Mark (File) & "!" &
        Natural_Image (Natural (Name.Sloc_Range.Start_Line)) & "!" &
        Natural_Image (Natural (Name.Sloc_Range.Start_Column)) &
        Profile & "|";
   end Function_Symbol;

   function Applied_Call_Term
     (Call    : Libadalang.Analysis.Call_Expr;
      Context : in out Translation_Context;
      Sort    : Scalar_Sort) return Unbounded_String;

   --  The token for the value of Node: a whole object, a component of
   --  one that is reached without a dereference, or the result of a
   --  function of its arguments.
   function Opaque_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         Mark_Unsupported (Context, Node, Null_Expression);
         return Null_Unbounded_String;
      elsif not Libadalang.Analysis.Is_Null (Eval.Expanded_Name_Target (Node))
      then
         return Opaque_Term (Eval.Expanded_Name_Target (Node), Context);
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Paren_Expr =>
            return Opaque_Term (Node.As_Paren_Expr.F_Expr, Context);

         when Libadalang.Common.Ada_Identifier =>
            declare
               Decl : constant Libadalang.Analysis.Basic_Decl :=
                 Node.As_Name.P_Referenced_Decl;
            begin
               if Libadalang.Analysis.Is_Null (Decl)
                 or else Decl.Kind not in
                   Libadalang.Common.Ada_Object_Decl_Range
                     | Libadalang.Common.Ada_Param_Spec
                 or else not Is_Opaque_Type (Node.As_Expr.P_Expression_Type)
               then
                  Mark_Unsupported
                    (Context, Node, Unsupported_Expression_Kind);
                  return Null_Unbounded_String;
               end if;
               return To_Unbounded_String
                 (Symbol_For
                    (Context,
                     Value_Key
                       (Object_Identity (Context, Referenced_Key (Node))),
                     Opaque_Sort));
            end;

         when Libadalang.Common.Ada_Call_Expr =>
            declare
               Typ : constant Libadalang.Analysis.Base_Type_Decl :=
                 Node.As_Expr.P_Expression_Type;
            begin
               --  A function that allocates returns another value each
               --  time it is called.
               if Node.As_Call_Expr.P_Kind /= Libadalang.Common.Call
                 or else Libadalang.Analysis.Is_Null (Typ)
                 or else Typ.P_Is_Access_Type
               then
                  Mark_Unsupported (Context, Node, Unsupported_Call);
                  return Null_Unbounded_String;
               end if;
               return Applied_Call_Term
                 (Node.As_Call_Expr, Context, Opaque_Sort);
            end;

         when Libadalang.Common.Ada_Dotted_Name =>
            declare
               Dotted : constant Libadalang.Analysis.Dotted_Name :=
                 Node.As_Dotted_Name;
               Field  : constant Libadalang.Analysis.Ada_Node :=
                 (if Dotted.F_Suffix.Kind = Libadalang.Common.Ada_Identifier
                  then Referenced_Key (Dotted.F_Suffix)
                  else Libadalang.Analysis.No_Ada_Node);
               Prefix_Type : constant Libadalang.Analysis.Base_Type_Decl :=
                 Dotted.F_Prefix.P_Expression_Type;
            begin
               if Libadalang.Analysis.Is_Null (Field)
                 or else Field.Kind /= Libadalang.Common.Ada_Defining_Name
                 or else Field.As_Defining_Name.P_Basic_Decl.Kind not in
                   Libadalang.Common.Ada_Component_Decl
                     | Libadalang.Common.Ada_Discriminant_Spec
                 or else Libadalang.Analysis.Is_Null (Prefix_Type)
                 or else Prefix_Type.P_Is_Access_Type
                 or else not Is_Opaque_Type (Node.As_Expr.P_Expression_Type)
               then
                  Mark_Unsupported
                    (Context, Node, Unsupported_Expression_Kind);
                  return Null_Unbounded_String;
               end if;

               declare
                  Prefix : constant Unbounded_String :=
                    Opaque_Term (Dotted.F_Prefix, Context);
               begin
                  if not Context.Supported or else Length (Prefix) = 0 then
                     return Null_Unbounded_String;
                  end if;
                  --  A component is a function of the object it is in.
                  return To_Unbounded_String
                    ("(" & Function_Symbol (Field, "!1O>O") & " " &
                     To_String (Prefix) & ")");
               end;
            end;

         when others =>
            Mark_Unsupported (Context, Node, Unsupported_Expression_Kind);
            return Null_Unbounded_String;
      end case;
   exception
      when others =>
         Mark_Unsupported (Context, Node, Translation_Error);
         return Null_Unbounded_String;
   end Opaque_Term;

   function Applied_Call_Term
     (Call    : Libadalang.Analysis.Call_Expr;
      Context : in out Translation_Context;
      Sort    : Scalar_Sort) return Unbounded_String
   is
      Max_Formals : constant := 16;

      Result_Sort : constant Sort_Resolution := Expression_Sort (Call);
      Decl        : Libadalang.Analysis.Basic_Decl;
      Canonical   : Libadalang.Analysis.Basic_Decl;
      Formals     : array (1 .. Max_Formals) of Unbounded_String;
      Terms       : array (1 .. Max_Formals) of Unbounded_String;
      Letters     : String (1 .. Max_Formals) := (others => ' ');
      Count       : Natural := 0;
      Instances   : Unbounded_String;
      Signature   : Unbounded_String;
      Arguments   : Unbounded_String;
   begin
      if Function_Of_Arguments = null
        or else Call.F_Name.P_Is_Dispatching_Call
        or else not Function_Of_Arguments (Call.F_Name)
        or else
          (case Sort is
              when Integer_Sort | Enum_Sort =>
                not Result_Sort.Supported
                or else Result_Sort.Sort not in Integer_Sort | Enum_Sort,
              when Boolean_Sort =>
                not Result_Sort.Supported
                or else Result_Sort.Sort /= Boolean_Sort,
              when Opaque_Sort =>
                not Is_Opaque_Type (Call.P_Expression_Type))
      then
         Mark_Unsupported (Context, Call, Unsupported_Call);
         return Null_Unbounded_String;
      end if;

      Decl := Call.F_Name.P_Referenced_Decl;
      Canonical := Decl.P_Canonical_Part;
      for Instance of Decl.P_Generic_Instantiations loop
         declare
            File : Positive;
         begin
            Number_File (Instance.Unit.Get_Filename, File);
            Append
              (Instances,
               "@" & File_Mark (File) & "." &
               Natural_Image (Natural (Instance.Sloc_Range.Start_Line)) & "." &
               Natural_Image (Natural (Instance.Sloc_Range.Start_Column)));
         end;
      end loop;

      for Param of Canonical.P_Subp_Spec_Or_Null.P_Params loop
         for Id of Param.F_Ids loop
            if Count = Max_Formals then
               Mark_Unsupported (Context, Call, Unsupported_Call);
               return Null_Unbounded_String;
            end if;
            Count := Count + 1;
            Formals (Count) := To_Unbounded_String
              (Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                 (Adalang_Analyzer.Ada_Text.Node_Text (Id)));
         end loop;
      end loop;

      for Pair of Call.F_Name.P_Call_Params loop
         declare
            Formal : constant Libadalang.Analysis.Defining_Name'Class :=
              Libadalang.Analysis.Param (Pair);
            Actual : constant Libadalang.Analysis.Expr'Class :=
              Libadalang.Analysis.Actual (Pair);
            Name   : constant String :=
              Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                (Adalang_Analyzer.Ada_Text.Node_Text (Formal));
            Formal_Sort_Info : constant Sort_Resolution :=
              Formal_Sort (Formal);
            Position : Natural := 0;
         begin
            for Index in 1 .. Count loop
               if To_String (Formals (Index)) = Name then
                  Position := Index;
               end if;
            end loop;
            if Position = 0
              or else Letters (Position) /= ' '
              or else Formal_Is_Writable (Formal)
            then
               Mark_Unsupported (Context, Call, Unsupported_Call);
               return Null_Unbounded_String;
            end if;

            if not Formal_Sort_Info.Supported then
               Terms (Position) := Opaque_Term (Actual, Context);
               Letters (Position) := 'O';
            elsif Formal_Sort_Info.Sort = Boolean_Sort then
               Terms (Position) := Boolean_Term (Actual, Context);
               Letters (Position) := 'B';
            else
               Terms (Position) := Integer_Term (Actual, Context);
               Letters (Position) := 'I';
            end if;
            if not Context.Supported or else Length (Terms (Position)) = 0
            then
               if Context.Supported then
                  Mark_Unsupported
                    (Context, Actual, Unsupported_Expression_Kind);
               end if;
               return Null_Unbounded_String;
            end if;
         end;
      end loop;

      --  A formal the call leaves to its default has no argument here,
      --  and the symbol says which ones were given.
      for Index in 1 .. Count loop
         if Letters (Index) /= ' ' then
            Append (Signature, Natural_Image (Index) & Letters (Index));
            Append (Arguments, " " & To_String (Terms (Index)));
         end if;
      end loop;
      Append
        (Signature,
         ">" & (case Sort is
                   when Boolean_Sort => 'B',
                   when Integer_Sort | Enum_Sort => 'I',
                   when Opaque_Sort => 'O'));

      declare
         Symbol : constant String :=
           Function_Symbol
             (Canonical.P_Defining_Name,
              To_String (Instances) & "!" & To_String (Signature));
      begin
         if Length (Arguments) = 0 then
            return To_Unbounded_String (Symbol);
         end if;
         return To_Unbounded_String
           ("(" & Symbol & To_String (Arguments) & ")");
      end;
   exception
      when others =>
         Mark_Unsupported (Context, Call, Translation_Error);
         return Null_Unbounded_String;
   end Applied_Call_Term;

   function Call_Term
     (Call    : Libadalang.Analysis.Call_Expr;
      Context : in out Translation_Context;
      Sort    : Scalar_Sort) return Unbounded_String
   is
      Inlined : Translation_Context := Context;
      Result  : constant Unbounded_String :=
        Inlined_Call_Term (Call, Inlined, Sort);
   begin
      if Inlined.Supported and then Length (Result) > 0 then
         Context := Inlined;

         --  Where the call is also a function of its arguments, the
         --  function symbol has, for these arguments, the value its body
         --  has: said once, so that what is known of the call in one form
         --  -- a contract translated where the body could not be used --
         --  is known of it in the other.
         declare
            Applied : Translation_Context := Context;
            Term    : constant Unbounded_String :=
              Applied_Call_Term (Call, Applied, Sort);
            Link    : Unbounded_String;
            Linked  : Boolean := False;
         begin
            if Applied.Supported and then Length (Term) > 0
              and then Term /= Result
            then
               Link := "(= " & Term & " " & Result & ")";
               Context := Applied;
               for Item of Context.Symbols.Assumptions loop
                  Linked := Linked or else Item = Link;
               end loop;
               if not Linked then
                  Context.Symbols.Assumptions.Append (Link);
               end if;
            end if;
         end;
         return Result;
      elsif not Context.Supported then
         return Null_Unbounded_String;
      end if;

      declare
         Applied : Translation_Context := Context;
         Term    : constant Unbounded_String :=
           Applied_Call_Term (Call, Applied, Sort);
      begin
         if Applied.Supported and then Length (Term) > 0 then
            Context := Applied;
            return Term;
         end if;
      end;

      --  Neither: the reason reported is why the body could not be used.
      Context := Inlined;
      if Context.Supported then
         Mark_Unsupported (Context, Call, Unsupported_Call);
      end if;
      return Null_Unbounded_String;
   end Call_Term;

   --  The declarations of the function symbols Text uses, each read from
   --  the symbol itself: after its last "!", the position and the sort of
   --  each argument, then ">" and the sort of the result.
   function Function_Declarations (Text : String) return String is
      function SMT_Sort (Letter : Character) return String is
        (if Letter = 'B' then "Bool" else "Int");

      Result : Unbounded_String;
      Index  : Natural := Text'First;
   begin
      while Index + 2 <= Text'Last loop
         if Text (Index .. Index + 2) = "|f!" then
            declare
               Stop : Natural := Index + 3;
               Mark : Natural := Index + 2;
            begin
               while Stop <= Text'Last and then Text (Stop) /= '|' loop
                  if Text (Stop) = '!' then
                     Mark := Stop;
                  end if;
                  Stop := Stop + 1;
               end loop;
               exit when Stop > Text'Last;

               declare
                  Symbol : constant String := Text (Index .. Stop);
                  Header : constant String :=
                    "(declare-fun " & Symbol & " (";
                  Sorts  : Unbounded_String;
                  Output : Character := 'I';
               begin
                  if Ada.Strings.Unbounded.Index (Result, Header) = 0 then
                     for Position in Mark + 1 .. Stop - 1 loop
                        if Text (Position) = '>' then
                           Output := Text (Position + 1);
                           exit;
                        elsif Text (Position) in 'I' | 'B' | 'O' then
                           Append
                             (Sorts,
                              (if Length (Sorts) = 0 then "" else " ") &
                              SMT_Sort (Text (Position)));
                        end if;
                     end loop;
                     Append
                       (Result,
                        Header & To_String (Sorts) & ") " &
                        SMT_Sort (Output) & ")" & ASCII.LF);
                  end if;
               end;
               Index := Stop + 1;
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
      return To_String (Result);
   end Function_Declarations;

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
      elsif Domain.Classify (Destination) /= Domain.Tracked then
         --  A write the symbolic state must not turn into a fact about the
         --  destination, and that may change what other names denote.
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
         when Opaque_Sort =>
            --  Expression_Sort gives scalar sorts only.
            return Havoc;
      end case;
      if not Context.Supported or else Length (Term) = 0 then
         if Symbolic_Diagnostics_Enabled then
            Tally (Assign_Havoc_By_Kind, Value.Kind'Image);
         end if;

         --  The value has no term, but its sort is known: the destination
         --  now holds some value of that sort, which is all that needs
         --  saying. It gets a symbol of its own, named after the
         --  expression that produced it, and everything known about other
         --  objects stays. Nothing is known about the symbol itself; in
         --  particular it is not the destination's previous value, which
         --  earlier facts may still mention under the old term.
         if not State.Supported or else Sort_Info.Sort = Boolean_Sort then
            return Havoc;
         end if;
         declare
            Result : Symbolic_State := State;
            Key    : constant Symbol_Key :=
              Plain_Key (Libadalang.Analysis.Ada_Node (Value));
            Name   : constant String := Root_Name (Key, "u");
         begin
            Add_Root (Result, Name, Key, Sort_Info.Sort, Flow);
            Set_Binding
              (Result,
               (Key  => Plain_Key (Destination),
                Sort => Sort_Info.Sort,
                Term => To_Unbounded_String (Name)));
            return Result;
         end;
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
      Result : Symbolic_State := State;
      Any    : Boolean := False;

      --  Adds to Result what Node having the value Truth says. A
      --  conjunction that holds is each of its operands holding, and a
      --  disjunction that does not is each of its operands not holding:
      --  each is taken on its own, so that one the translation cannot
      --  express does not cost the others.
      procedure Take
        (Node  : Libadalang.Analysis.Expr'Class;
         Truth : Boolean)
      is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
            Take (Node.As_Paren_Expr.F_Expr, Truth);
            return;
         elsif not Eval.Is_User_Operator (Node) then
            --  Nothing follows for the operands of an operator a
            --  declaration defines from what that function returns.
            if Node.Kind = Libadalang.Common.Ada_Un_Op
              and then Node.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Not
            then
               Take (Node.As_Un_Op.F_Expr, not Truth);
               return;
            elsif Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
              and then
                (if Truth
                 then Node.As_Bin_Op.F_Op in
                   Libadalang.Common.Ada_Op_And
                     | Libadalang.Common.Ada_Op_And_Then
                 else Node.As_Bin_Op.F_Op in
                   Libadalang.Common.Ada_Op_Or
                     | Libadalang.Common.Ada_Op_Or_Else)
            then
               Take (Node.As_Bin_Op.F_Left, Truth);
               Take (Node.As_Bin_Op.F_Right, Truth);
               return;
            end if;
         end if;

         declare
            Context : Translation_Context :=
              (State => Flow, Symbols => Result, Supported => True,
               Object_Bindings => Object_Binding_Vectors.Empty_Vector,
               Failure_Reason => No_Unsupported_Reason,
               Failure_Node => Libadalang.Analysis.No_Ada_Node,
               Inlining_Path => Null_Unbounded_String, Depth => 0);
            Term : constant Unbounded_String := Boolean_Term (Node, Context);
         begin
            if not Context.Supported or else Length (Term) = 0 then
               if Symbolic_Diagnostics_Enabled then
                  Tally (Assume_Havoc_By_Kind, Node.Kind'Image);
               end if;
               return;
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
            Result := Context.Symbols;
            Any := True;
         end;
      end Take;
   begin
      if not State.Supported then
         return Havoc;
      end if;
      Take (Condition, Truth);
      --  With nothing taken the answer is the empty state, as it always
      --  was for a condition that does not translate: callers tell the
      --  two apart by it.
      return (if Any then Result else Havoc);
   exception
      when others =>
         if Symbolic_Diagnostics_Enabled then
            Tally (Assume_Havoc_By_Kind, "exception");
         end if;
         return Havoc;
   end Assume;

   --  The prefix of the symbols minted for what Writer changes.
   function Writer_Prefix
     (Writer : Libadalang.Analysis.Ada_Node'Class) return String
   is
      File : Positive;
   begin
      Number_File (Writer.Unit.Get_Filename, File);
      return "w" & File_Mark (File) & "_" &
        Natural_Image (Natural (Writer.Sloc_Range.Start_Line)) & "_" &
        Natural_Image (Natural (Writer.Sloc_Range.Start_Column)) & "_";
   end Writer_Prefix;

   ------------------------------------------------------------------
   --  Contract frames
   ------------------------------------------------------------------

   procedure Set_Frame_Object
     (Frame  : in out Contract_Frame;
      Formal : Libadalang.Analysis.Ada_Node;
      Actual : Libadalang.Analysis.Ada_Node)
   is
   begin
      for Index in 1 .. Natural (Frame.Objects.Length) loop
         if Frame.Objects.Element (Index).Formal = Formal then
            Frame.Objects.Replace_Element
              (Index, (Formal => Formal, Actual => Actual));
            return;
         end if;
      end loop;
      Frame.Objects.Append ((Formal => Formal, Actual => Actual));
   end Set_Frame_Object;

   procedure Block_Formal
     (Frame  : in out Contract_Frame;
      Formal : Libadalang.Analysis.Ada_Node)
   is
   begin
      if Libadalang.Analysis.Is_Null (Formal) then
         return;
      end if;
      for Index in reverse 1 .. Natural (Frame.Scalars.Length) loop
         if Frame.Scalars.Element (Index).Key.Object = Formal then
            Frame.Scalars.Delete (Index);
         end if;
      end loop;
      Set_Frame_Object (Frame, Formal, Libadalang.Analysis.No_Ada_Node);
   end Block_Formal;

   procedure Bind_Formal
     (Frame  : in out Contract_Frame;
      State  : in out Symbolic_State;
      Formal : Libadalang.Analysis.Ada_Node;
      Actual : Libadalang.Analysis.Expr'Class;
      Flow   : Domain.Flow_State)
   is
      Sort_Info : Sort_Resolution;
   begin
      if Libadalang.Analysis.Is_Null (Formal) then
         return;
      end if;
      Block_Formal (Frame, Formal);
      if Libadalang.Analysis.Is_Null (Actual)
        or else not State.Supported
        or else Formal.Kind /= Libadalang.Common.Ada_Defining_Name
      then
         return;
      end if;

      Sort_Info := Formal_Sort (Formal.As_Defining_Name);
      if Sort_Info.Supported then
         declare
            Context : Translation_Context :=
              (State => Flow, Symbols => State, Supported => True,
               Object_Bindings => Object_Binding_Vectors.Empty_Vector,
               Failure_Reason => No_Unsupported_Reason,
               Failure_Node => Libadalang.Analysis.No_Ada_Node,
               Inlining_Path => Null_Unbounded_String, Depth => 0);
            Term : constant Unbounded_String :=
              (if Sort_Info.Sort = Boolean_Sort
               then Boolean_Term (Actual, Context)
               else Integer_Term (Actual, Context));
         begin
            if Context.Supported and then Length (Term) > 0 then
               State := Context.Symbols;
               Frame.Scalars.Append
                 ((Key  => Plain_Key (Formal),
                   Sort => Sort_Info.Sort,
                   Term => Term));
               --  A scalar is no object of the frame.
               for Index in reverse 1 .. Natural (Frame.Objects.Length) loop
                  if Frame.Objects.Element (Index).Formal = Formal then
                     Frame.Objects.Delete (Index);
                  end if;
               end loop;
            end if;
         end;
         return;
      end if;

      declare
         Id : constant Libadalang.Analysis.Ada_Node :=
           (if Actual.Kind = Libadalang.Common.Ada_Identifier
              then Libadalang.Analysis.Ada_Node (Actual)
            else Eval.Expanded_Name_Target (Actual));
         Decl : Libadalang.Analysis.Basic_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Id) then
            return;
         end if;
         Decl := Id.As_Name.P_Referenced_Decl;
         if not Libadalang.Analysis.Is_Null (Decl)
           and then Decl.Kind in Libadalang.Common.Ada_Object_Decl_Range
                               | Libadalang.Common.Ada_Param_Spec
           and then Domain.Classify (Referenced_Key (Id)) = Domain.Tracked
         then
            Set_Frame_Object (Frame, Formal, Referenced_Key (Id));
         end if;
      end;
   exception
      when others =>
         Block_Formal (Frame, Formal);
   end Bind_Formal;

   function Assume_In_Frame
     (State     : Symbolic_State;
      Frame     : Contract_Frame;
      Condition : Libadalang.Analysis.Expr;
      Flow      : Domain.Flow_State) return Symbolic_State
   is
      Result     : Symbolic_State := State;
      Any        : Boolean := False;
      Frame_Flow : Domain.Flow_State := Flow;
      Objects    : Object_Binding_Vectors.Vector;

      procedure Take (Node : Libadalang.Analysis.Expr'Class) is
      begin
         if Libadalang.Analysis.Is_Null (Node) then
            return;
         elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
            Take (Node.As_Paren_Expr.F_Expr);
            return;
         elsif Node.Kind in Libadalang.Common.Ada_Bin_Op_Range
           and then Node.As_Bin_Op.F_Op in
             Libadalang.Common.Ada_Op_And
               | Libadalang.Common.Ada_Op_And_Then
           and then not Eval.Is_User_Operator (Node)
         then
            Take (Node.As_Bin_Op.F_Left);
            Take (Node.As_Bin_Op.F_Right);
            return;
         end if;

         declare
            --  The formals have their terms in this context only: of what
            --  the translation leaves, the bindings are not kept.
            Context : Translation_Context :=
              (State => Frame_Flow, Symbols => Result, Supported => True,
               Object_Bindings => Objects,
               Failure_Reason => No_Unsupported_Reason,
               Failure_Node => Libadalang.Analysis.No_Ada_Node,
               Inlining_Path => Null_Unbounded_String, Depth => 0);
            Term    : Unbounded_String;
            Present : Boolean := False;
         begin
            for Item of Frame.Scalars loop
               Set_Binding (Context.Symbols, Item);
            end loop;
            Term := Boolean_Term (Node, Context);
            if not Context.Supported or else Length (Term) = 0 then
               return;
            end if;

            Result.Roots := Context.Symbols.Roots;
            Result.Assumptions := Context.Symbols.Assumptions;
            for Item of Result.Assumptions loop
               Present := Present or else Item = Term;
            end loop;
            if not Present then
               Result.Assumptions.Append (Term);
            end if;
            Any := True;
         end;
      end Take;
   begin
      if not State.Supported or else Libadalang.Analysis.Is_Null (Condition)
      then
         return Havoc;
      end if;

      for Item of Frame.Scalars loop
         Domain.Flow_Havoc (Frame_Flow, Item.Key.Object);
         Domain.Flow_Set_Initialized
           (Frame_Flow, Item.Key.Object, Domain.Bool_True);
      end loop;
      for Item of Frame.Objects loop
         --  A blocked formal is no object: nothing reads it as a scalar,
         --  nothing finds an object behind it.
         if Libadalang.Analysis.Is_Null (Item.Actual) then
            Domain.Flow_Havoc (Frame_Flow, Item.Formal);
         end if;
         Objects.Append ((Formal => Item.Formal, Actual => Item.Actual));
      end loop;

      Take (Condition);
      return (if Any then Result else Havoc);
   exception
      when others =>
         return Havoc;
   end Assume_In_Frame;

   function Forget_Composite_Values
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class) return Symbolic_State
   is
      Result : Symbolic_State := State;

      --  The key gets a symbol of its own, named after the writer: what
      --  earlier facts say of the old value they still say of the old
      --  symbol.
      procedure Renew (Key : Symbol_Key; Prefix : String) is
         Name : constant String := Root_Name (Key, Prefix);
      begin
         Add_Root (Result, Name, Key, Opaque_Sort, Domain.Empty_Flow_State);
         Set_Binding
           (Result,
            (Key  => Key,
             Sort => Opaque_Sort,
             Term => To_Unbounded_String (Name)));
      end Renew;
   begin
      if not State.Supported or else Libadalang.Analysis.Is_Null (Writer) then
         return Havoc;
      end if;

      declare
         Prefix : constant String := Writer_Prefix (Writer);
      begin
         for Root of State.Roots loop
            if Root.Sort = Opaque_Sort then
               Renew (Root.Key, Prefix);
            end if;
         end loop;
         for Binding of State.Bindings loop
            if Binding.Sort = Opaque_Sort then
               Renew (Binding.Key, Prefix);
            end if;
         end loop;
      end;
      return Result;
   exception
      when others =>
         return Havoc;
   end Forget_Composite_Values;

   --  Gives each key of State that Renewed selects a symbol of its own. A
   --  key is live when it has a binding, or a root under its own name: any
   --  other root is a symbol some term uses, not the value of an object.
   function Renew_Keys
     (State   : Symbolic_State;
      Writer  : Libadalang.Analysis.Ada_Node'Class;
      After   : Domain.Flow_State;
      Renewed : not null access function (Key : Symbol_Key) return Boolean)
      return Symbolic_State
   is
      Result : Symbolic_State := State;
      Prefix : constant String := Writer_Prefix (Writer);

      procedure Renew (Key : Symbol_Key; Sort : Scalar_Sort) is
         Name : constant String := Root_Name (Key, Prefix);
      begin
         Add_Root (Result, Name, Key, Sort, After);
         Set_Binding
           (Result,
            (Key => Key, Sort => Sort, Term => To_Unbounded_String (Name)));
      end Renew;
   begin
      for Root of State.Roots loop
         if Binding_Index (State, Root.Key) = 0
           and then To_String (Root.Name) = Root_Name (Root.Key)
           and then Renewed (Root.Key)
         then
            Renew (Root.Key, Root.Sort);
         end if;
      end loop;
      for Binding of State.Bindings loop
         if Renewed (Binding.Key) then
            Renew (Binding.Key, Binding.Sort);
         end if;
      end loop;
      return Result;
   end Renew_Keys;

   function Forget_Unowned_Values
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class;
      Scope  : Libadalang.Analysis.Ada_Node;
      After  : Domain.Flow_State) return Symbolic_State
   is
      function Owned (Object : Libadalang.Analysis.Ada_Node) return Boolean
      is
         Current : Libadalang.Analysis.Ada_Node := Object;
      begin
         if Libadalang.Analysis.Is_Null (Scope) then
            return False;
         end if;
         while not Libadalang.Analysis.Is_Null (Current) loop
            if Current = Scope then
               return True;
            end if;
            Current := Current.Parent;
         end loop;
         return False;
      end Owned;

      function Renewed (Key : Symbol_Key) return Boolean is
        (not Libadalang.Analysis.Is_Null (Key.Component)
         or else not Owned (Key.Object));
   begin
      if not State.Supported or else Libadalang.Analysis.Is_Null (Writer) then
         return Havoc;
      end if;
      return Renew_Keys (State, Writer, After, Renewed'Access);
   exception
      when others =>
         return Havoc;
   end Forget_Unowned_Values;

   function Forget_Object
     (State  : Symbolic_State;
      Writer : Libadalang.Analysis.Ada_Node'Class;
      Object : Libadalang.Analysis.Ada_Node;
      After  : Domain.Flow_State) return Symbolic_State
   is
      function Renewed (Key : Symbol_Key) return Boolean is
        (Key.Object = Object);
   begin
      if not State.Supported or else Libadalang.Analysis.Is_Null (Writer) then
         return Havoc;
      elsif Libadalang.Analysis.Is_Null (Object) then
         return State;
      elsif Domain.Classify (Object) /= Domain.Tracked then
         --  A write that may change what other names denote.
         return Havoc;
      end if;
      return Renew_Keys (State, Writer, After, Renewed'Access);
   exception
      when others =>
         return Havoc;
   end Forget_Object;

   function Bind_Actual
     (State  : Symbolic_State;
      Formal : Libadalang.Analysis.Ada_Node;
      Actual : Libadalang.Analysis.Expr'Class;
      Flow   : Domain.Flow_State) return Symbolic_State
   is
   begin
      if Libadalang.Analysis.Is_Null (Formal)
        or else Libadalang.Analysis.Is_Null (Actual)
        or else Expression_Sort (Actual).Supported
        or else not State.Supported
        or else Domain.Classify (Formal) /= Domain.Tracked
      then
         return Assign (State, Formal, Actual, Flow);
      end if;

      --  State speaks of Formal already: the caller is the callee, and
      --  what it knows of its own parameter is not what the call passes.
      for Root of State.Roots loop
         if Root.Key.Object = Formal then
            return Havoc;
         end if;
      end loop;
      for Binding of State.Bindings loop
         if Binding.Key.Object = Formal then
            return Havoc;
         end if;
      end loop;

      declare
         Context : Translation_Context :=
           (State => Flow, Symbols => State, Supported => True,
            Object_Bindings => Object_Binding_Vectors.Empty_Vector,
            Failure_Reason => No_Unsupported_Reason,
            Failure_Node => Libadalang.Analysis.No_Ada_Node,
            Inlining_Path => Null_Unbounded_String, Depth => 0);
         Term : constant Unbounded_String := Opaque_Term (Actual, Context);
      begin
         if not Context.Supported or else Length (Term) = 0 then
            --  No token for the actual: the formal is left with a value
            --  of which nothing is known.
            return State;
         end if;
         Set_Binding
           (Context.Symbols,
            (Key => Value_Key (Formal), Sort => Opaque_Sort, Term => Term));

         --  Where the actual is an object, what is known of its scalar
         --  components is known of the formal's.
         if Actual.Kind = Libadalang.Common.Ada_Identifier then
            return Alias_Object
              (Context.Symbols, Referenced_Key (Actual), Formal);
         end if;
         return Context.Symbols;
      end;
   exception
      when others =>
         return Havoc;
   end Bind_Actual;

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

   --  The generic tail of a branch-merge join: everything that doesn't
   --  care how Selector was derived, shared between Join_On_Condition (an
   --  if/elsif boolean condition) and Join_On_Range (a case alternative's
   --  range-membership predicate). Extra_Roots carries whatever the
   --  caller already resolved while computing Selector (a translated
   --  condition's own free-variable roots, or one freshly-minted
   --  anonymous placeholder root) so it can be folded into Result
   --  alongside True_Side/False_Side's own roots.
   function Join_On_Selector
     (True_Side, False_Side : Symbolic_State;
      Extra_Roots            : Symbolic_State;
      Selector                : Unbounded_String;
      Flow                    : Domain.Flow_State;
      Merge_Tag               : Positive) return Symbolic_State
   is
      Result : Symbolic_State := Empty_Symbolic_State;

      --  Exactly Join's fresh-symbol fallback, for one binding only. Used
      --  now only when a binding's sort itself disagrees between arms (an
      --  ite would be ill-typed) -- confirmed unreachable from real Ada
      --  source, since Assign's sort always comes from the assigned
      --  expression's own resolved static Ada type, kept defensive anyway.
      function Fresh_Term (Key : Symbol_Key; Sort : Scalar_Sort) return String
      is
         Name : constant String :=
           Root_Name (Key, "j" & Natural_Image (Merge_Tag) & "_");
      begin
         Add_Root (Result, Name, Key, Sort, Flow);
         return Name;
      end Fresh_Term;

      --  A key's term on a side that carries no binding for it: the
      --  ordinary "plain root" reference (Symbol_For's own no-binding
      --  case), minted directly into Result so it's recorded where the
      --  returned name actually needs to exist.
      function Missing_Term (Key : Symbol_Key; Sort : Scalar_Sort) return String
      is
         Name : constant String := Root_Name (Key);
      begin
         if Root_Index (Result, Name) = 0 then
            Add_Root (Result, Name, Key, Sort, Flow);
         end if;
         return Name;
      end Missing_Term;

   begin
      if not True_Side.Supported or else not False_Side.Supported then
         return Havoc;
      end if;

      for Item of True_Side.Roots loop
         Include_Root (Result, Item);
      end loop;
      for Item of False_Side.Roots loop
         Include_Root (Result, Item);
      end loop;
      for Item of Extra_Roots.Roots loop
         Include_Root (Result, Item);
      end loop;

      for Item of True_Side.Bindings loop
         declare
            False_Index : constant Natural :=
              Binding_Index (False_Side, Item.Key);
         begin
            if False_Index /= 0
              and then False_Side.Bindings.Element (False_Index).Sort =
                Item.Sort
              and then False_Side.Bindings.Element (False_Index).Term =
                Item.Term
            then
               Set_Binding (Result, Item);
            elsif False_Index /= 0
              and then False_Side.Bindings.Element (False_Index).Sort /=
                Item.Sort
            then
               Set_Binding
                 (Result,
                  (Key => Item.Key, Sort => Item.Sort,
                   Term => To_Unbounded_String
                     (Fresh_Term (Item.Key, Item.Sort))));
            else
               declare
                  False_Term : constant String :=
                    (if False_Index = 0
                     then Missing_Term (Item.Key, Item.Sort)
                     else To_String
                       (False_Side.Bindings.Element (False_Index).Term));
               begin
                  Set_Binding
                    (Result,
                     (Key => Item.Key, Sort => Item.Sort,
                      Term => To_Unbounded_String
                        ("(ite " & To_String (Selector) & " " &
                         To_String (Item.Term) & " " & False_Term & ")")));
               end;
            end if;
         end;
      end loop;

      for Item of False_Side.Bindings loop
         if Binding_Index (True_Side, Item.Key) = 0 then
            declare
               True_Term : constant String :=
                 Missing_Term (Item.Key, Item.Sort);
            begin
               Set_Binding
                 (Result,
                  (Key => Item.Key, Sort => Item.Sort,
                   Term => To_Unbounded_String
                     ("(ite " & To_String (Selector) & " " & True_Term &
                      " " & To_String (Item.Term) & ")")));
            end;
         end if;
      end loop;

      for Item of True_Side.Assumptions loop
         for Other of False_Side.Assumptions loop
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
   end Join_On_Selector;

   function Join_On_Condition
     (True_Side, False_Side : Symbolic_State;
      Pre_Fork_Side          : Symbolic_State;
      Condition              : Libadalang.Analysis.Ada_Node'Class;
      Flow                   : Domain.Flow_State;
      Merge_Tag              : Positive) return Symbolic_State
   is
      Cond_Context : Translation_Context :=
        (State => Flow, Symbols => Pre_Fork_Side, others => <>);
      Cond_Term : constant Unbounded_String :=
        Boolean_Term (Condition, Cond_Context);
      Cond_OK   : constant Boolean :=
        Cond_Context.Supported and then Length (Cond_Term) > 0;

      --  The ite selector for every disagreeing binding at this merge:
      --  Cond_Term when Condition translates (correlating the selector
      --  with any of Condition's own free variables that also appear
      --  elsewhere in the surrounding proof obligation), or an anonymous,
      --  totally unconstrained boolean symbol otherwise -- minted below,
      --  keyed to Condition's own source location so it's deterministic
      --  and unique per merge site, when Condition itself doesn't
      --  translate (an unsupported shape, e.g. an indexed array read).
      --  Sound regardless of what the selector "means": the ite VC is
      --  checked for every possible value of its selector, so proving it
      --  holds for an unconstrained placeholder proves it holds for
      --  whatever the real (but here untranslated) condition actually is
      --  too. A placeholder costs precision relative to a real,
      --  correlated condition (nothing else in the VC can be related back
      --  to it), but is strictly more precise than the fresh-symbol
      --  fallback it replaces, since it still ties the merged value to
      --  exactly the true-arm or false-arm term instead of discarding
      --  both.
      Selector    : Unbounded_String;
      Extra_Roots : Symbolic_State := Empty_Symbolic_State;
   begin
      if not True_Side.Supported or else not False_Side.Supported
        or else not Pre_Fork_Side.Supported
      then
         return Havoc;
      end if;

      if Cond_OK then
         for Item of Cond_Context.Symbols.Roots loop
            Include_Root (Extra_Roots, Item);
         end loop;
         Selector := Cond_Term;
      else
         --  Condition itself doesn't translate: mint one anonymous,
         --  totally unconstrained boolean symbol, keyed to Condition's
         --  own source location so it's deterministic and unique per
         --  merge site, to stand in for it as the ite selector below.
         declare
            Key  : constant Symbol_Key :=
              Plain_Key (Libadalang.Analysis.Ada_Node (Condition));
            Name : constant String :=
              Root_Name (Key, "jc" & Natural_Image (Merge_Tag) & "_");
         begin
            Add_Root (Extra_Roots, Name, Key, Boolean_Sort, Flow);
            Selector := To_Unbounded_String (Name);
         end;
      end if;

      return Join_On_Selector
        (True_Side, False_Side, Extra_Roots, Selector, Flow, Merge_Tag);
   exception
      when others =>
         return Havoc;
   end Join_On_Condition;

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
            --  A root whose bounds exclude every value was minted on a
            --  path the interval domain found infeasible (an empty loop
            --  range, a contradictory condition). Roots survive a join
            --  whichever side they came from, so asserting such bounds
            --  would make every later goal follow from a contradiction
            --  (FP-098). They are left out: the symbol is then merely
            --  unconstrained.
            if Item.Sort in Integer_Sort | Enum_Sort
              and then not (Item.Has_Low and then Item.Has_High
                            and then Item.Low > Item.High)
            then
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

   --  Asks both solvers. Only an UNSAT answer from both is ever acted on,
   --  so Z3 does not run once CVC5 has answered anything else.
   function Run_Query
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
      Z3 :=
        (if CVC5 = Solver_Unsat
         then Run_Solver (Z3_Path, False, Input_Name.all) else CVC5);
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
   end Run_Query;

   --  The answers already obtained in this run, by query text. The CFG
   --  fixed point evaluates a node several times, and most of its queries
   --  come back unchanged; each one saved is two to four solver processes.
   package Answer_Maps is new Ada.Containers.Hashed_Maps
     (Key_Type        => Unbounded_String,
      Element_Type    => Solver_Answer,
      Hash            => Ada.Strings.Unbounded.Hash,
      Equivalent_Keys => "=");
   Max_Remembered_Answers : constant := 50_000;
   Answers : array (Boolean) of Answer_Maps.Map;

   procedure Query
     (Formula : String;
      Negate  : Boolean;
      Answer  : out Solver_Answer)
   is
      Text     : constant String := Renumbered (Formula);
      Key      : constant Unbounded_String := To_Unbounded_String (Text);
      Position : constant Answer_Maps.Cursor := Answers (Negate).Find (Key);
   begin
      if Answer_Maps.Has_Element (Position) then
         Answer := Answer_Maps.Element (Position);
         return;
      end if;

      Answer := Run_Query (Text, Negate);
      --  A missing solver is not an answer about the formula.
      if Answer /= Solver_Unavailable then
         if Answers (Negate).Length >= Max_Remembered_Answers then
            Answers (Negate).Clear;
         end if;
         Answers (Negate).Insert (Key, Answer);
      end if;
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
      Formula :=
        To_Unbounded_String (Function_Declarations (To_String (Formula))) &
        Formula;
      Query (To_String (Formula), Negate => True, Answer => Negated);
      if Negated = Solver_Unavailable then
         return (Result => VC_Unavailable,
                 Provenance => No_Unsupported_Provenance);
      elsif Negated = Solver_Unsat then
         return (Result => VC_Proved,
                 Provenance => No_Unsupported_Provenance);
      end if;

      Query (To_String (Formula), Negate => False, Answer => Direct);
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

   --  The SMT goal string for "Term is within Bounds": shared between
   --  Decide_Bounds's one-shot range-check decision and Join_On_Range's
   --  case-alternative selector (the case-statement counterpart of a
   --  boolean condition's own Boolean_Term translation). Empty when
   --  neither bound is present.
   function Range_Goal
     (Term : Unbounded_String; Bounds : Domain.Abstract_Range)
      return Unbounded_String
   is
      Goal : Unbounded_String;
   begin
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
      return Goal;
   end Range_Goal;

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
   begin
      Term := Integer_Term (Value, Context);
      --  Both bounds are needed: a goal built from one known bound would
      --  prove only that half of the check (FP-088).
      if not Context.Supported or else Length (Term) = 0
        or else not Bounds.Has_Low or else not Bounds.Has_High
      then
         if Context.Supported then
            Mark_Unsupported (Context, Value, Missing_Static_Bounds);
         end if;
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For (Context, Value));
      end if;

      return Decide_Goal (Range_Goal (Term, Bounds), Context);
   exception
      when others =>
         return Unknown_Outcome;
   end Decide_Bounds;

   function Decide_Index_In_Object
     (Index     : Libadalang.Analysis.Expr'Class;
      Prefix    : Libadalang.Analysis.Name'Class;
      State     : Domain.Flow_State;
      Symbols   : Symbolic_State;
      Dimension : Positive := 1) return VC_Outcome
   is
      Context : Translation_Context :=
        (State => State, Symbols => Symbols, Supported => Symbols.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Term  : Unbounded_String;
      First : Unbounded_String;
      Last  : Unbounded_String;
   begin
      Term := Integer_Term (Index, Context);
      if Context.Supported and then Length (Term) > 0 then
         First :=
           Array_Attribute_Term
             (Prefix.As_Name, "first", Index, Context, Dimension);
      end if;
      if Context.Supported and then Length (First) > 0 then
         Last :=
           Array_Attribute_Term
             (Prefix.As_Name, "last", Index, Context, Dimension);
      end if;
      if not Context.Supported or else Length (Last) = 0 then
         if Context.Supported then
            Mark_Unsupported (Context, Index, Missing_Static_Bounds);
         end if;
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For (Context, Index));
      end if;

      return Decide_Goal
        (To_Unbounded_String
           ("(and (<= " & To_String (First) & " " & To_String (Term) &
            ") (<= " & To_String (Term) & " " & To_String (Last) & "))"),
         Context);
   exception
      when others =>
         return Unknown_Outcome;
   end Decide_Index_In_Object;

   --  The term for the length of the Dimension-th dimension of the array
   --  Item denotes, or of the range Item is; empty, with Context marked,
   --  when it has none.
   function Array_Length_Term
     (Item      : Libadalang.Analysis.Expr'Class;
      Dimension : Positive;
      Context   : in out Translation_Context) return Unbounded_String
   is
      Interval : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
   begin
      if Libadalang.Analysis.Is_Null (Item) then
         Mark_Unsupported (Context, Item, Null_Expression);
         return Null_Unbounded_String;
      elsif Item.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Array_Length_Term
           (Item.As_Paren_Expr.F_Expr, Dimension, Context);
      elsif Item.Kind in Libadalang.Common.Ada_Identifier
                       | Libadalang.Common.Ada_Dotted_Name
      then
         return
           Array_Attribute_Term
             (Item.As_Name, "length", Item, Context, Dimension);
      elsif Item.Kind = Libadalang.Common.Ada_Call_Expr
        and then Item.As_Call_Expr.P_Kind = Libadalang.Common.Array_Slice
      then
         Interval := Item.As_Call_Expr.F_Suffix.As_Ada_Node;
      elsif Item.Kind = Libadalang.Common.Ada_Bin_Op then
         Interval := Libadalang.Analysis.Ada_Node (Item);
      end if;

      --  A slice over Y'Range is as long as Y, array or subtype; one over
      --  a subtype, as long as the subtype has values.
      if Dimension = 1
        and then not Libadalang.Analysis.Is_Null (Interval)
        and then Interval.Kind = Libadalang.Common.Ada_Attribute_Ref
        and then Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                   (Adalang_Analyzer.Ada_Text.Node_Text
                      (Interval.As_Attribute_Ref.F_Attribute)) = "range"
        and then
          (Libadalang.Analysis.Is_Null (Interval.As_Attribute_Ref.F_Args)
           or else Interval.As_Attribute_Ref.F_Args.Children_Count = 0)
      then
         return
           Array_Attribute_Term
             (Interval.As_Attribute_Ref.F_Prefix, "length", Item, Context);
      elsif Dimension = 1
        and then not Libadalang.Analysis.Is_Null (Interval)
        and then Interval.Kind in Libadalang.Common.Ada_Identifier
                                | Libadalang.Common.Ada_Dotted_Name
      then
         declare
            Decl   : constant Libadalang.Analysis.Basic_Decl :=
              Interval.As_Name.P_Referenced_Decl;
            Bounds : Domain.Abstract_Range := Domain.Unknown_Range;
         begin
            if not Libadalang.Analysis.Is_Null (Decl)
              and then Decl.Kind in Libadalang.Common.Ada_Base_Type_Decl
            then
               Bounds :=
                 Eval.Type_Range (Decl.As_Base_Type_Decl, Context.State);
            end if;
            if Bounds.Has_Low and then Bounds.Has_High then
               return To_Unbounded_String
                 (if Bounds.Low > Bounds.High then "0"
                  else SMT_Integer (Bounds.High - Bounds.Low + 1));
            end if;
         end;
      end if;

      if Dimension = 1
        and then not Libadalang.Analysis.Is_Null (Interval)
        and then Interval.Kind = Libadalang.Common.Ada_Bin_Op
        and then Interval.As_Bin_Op.F_Op.Kind =
          Libadalang.Common.Ada_Op_Double_Dot
      then
         declare
            Low  : constant Unbounded_String :=
              Integer_Term (Interval.As_Bin_Op.F_Left, Context);
            High : constant Unbounded_String :=
              (if Context.Supported and then Length (Low) > 0
               then Integer_Term (Interval.As_Bin_Op.F_Right, Context)
               else Null_Unbounded_String);
         begin
            if not Context.Supported or else Length (High) = 0 then
               return Null_Unbounded_String;
            end if;
            return
              To_Unbounded_String
                ("(ite (<= " & To_String (Low) & " " & To_String (High) &
                 ") (+ (- " & To_String (High) & " " & To_String (Low) &
                 ") 1) 0)");
         end;
      end if;

      Mark_Unsupported (Context, Item, Unsupported_Expression_Kind);
      return Null_Unbounded_String;
   end Array_Length_Term;

   function Decide_Same_Length
     (Target     : Libadalang.Analysis.Expr'Class;
      Value      : Libadalang.Analysis.Expr'Class;
      Dimensions : Positive;
      State      : Domain.Flow_State;
      Symbols    : Symbolic_State) return VC_Outcome
   is
      Context : Translation_Context :=
        (State => State, Symbols => Symbols, Supported => Symbols.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Goal    : Unbounded_String := To_Unbounded_String ("(and true");
   begin
      for Dimension in 1 .. Dimensions loop
         declare
            Of_Target : constant Unbounded_String :=
              Array_Length_Term (Target, Dimension, Context);
            Of_Value  : constant Unbounded_String :=
              (if Context.Supported and then Length (Of_Target) > 0
               then Array_Length_Term (Value, Dimension, Context)
               else Null_Unbounded_String);
         begin
            if not Context.Supported or else Length (Of_Value) = 0 then
               if Context.Supported then
                  Mark_Unsupported (Context, Value, Missing_Static_Bounds);
               end if;
               return
                 (Result => VC_Unsupported,
                  Provenance => Unsupported_Provenance_For (Context, Value));
            end if;
            Append
              (Goal,
               " (= " & To_String (Of_Target) & " " & To_String (Of_Value) &
               ")");
         end;
      end loop;

      return Decide_Goal (Goal & ")", Context);
   exception
      when others =>
         return Unknown_Outcome;
   end Decide_Same_Length;

   function Decide_Length
     (Value   : Libadalang.Analysis.Expr'Class;
      Length  : Long_Long_Integer;
      State   : Domain.Flow_State;
      Symbols : Symbolic_State) return VC_Outcome
   is
      Context : Translation_Context :=
        (State => State, Symbols => Symbols, Supported => Symbols.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);
      Term    : constant Unbounded_String :=
        Array_Length_Term (Value, 1, Context);
   begin
      if not Context.Supported
        or else Ada.Strings.Unbounded.Length (Term) = 0
      then
         if Context.Supported then
            Mark_Unsupported (Context, Value, Missing_Static_Bounds);
         end if;
         return
           (Result => VC_Unsupported,
            Provenance => Unsupported_Provenance_For (Context, Value));
      end if;
      return Decide_Goal
        (To_Unbounded_String
           ("(= " & To_String (Term) & " " & SMT_Integer (Length) & ")"),
         Context);
   exception
      when others =>
         return Unknown_Outcome;
   end Decide_Length;

   function Array_Bound_Facts (State : Symbolic_State) return Symbolic_State
   is
      --  True for the name Array_Attribute_Term gives a bound or length
      --  symbol: "af", "al" or "an", then the object's file, line and
      --  column.
      function Is_Bound_Symbol (Token : String) return Boolean is
        (Token'Length > 4
         and then Token (Token'First) = 'a'
         and then Token (Token'First + 1) in 'f' | 'l' | 'n'
         and then
           (for all Item of Token (Token'First + 2 .. Token'Last) =>
              Item in '0' .. '9' | '_' | File_Mark_Character));

      --  True when every name in the SMT term Text is a bound symbol, an
      --  operator or a literal.
      function Only_Bounds (Text : String) return Boolean is
         Start : Natural := 0;

         function Acceptable (Token : String) return Boolean is
           (Is_Bound_Symbol (Token)
            or else Token in "and" | "or" | "not" | "ite" | "=" | "<=" | ">="
                           | "<" | ">" | "+" | "-" | "*" | "true" | "false"
            or else (for all Item of Token => Item in '0' .. '9'));
      begin
         for Index in Text'Range loop
            if Text (Index) in ' ' | '(' | ')' then
               if Start /= 0 and then not Acceptable (Text (Start .. Index - 1))
               then
                  return False;
               end if;
               Start := 0;
            elsif Start = 0 then
               Start := Index;
            end if;
         end loop;
         return Start = 0 or else Acceptable (Text (Start .. Text'Last));
      end Only_Bounds;

      Result : Symbolic_State := Empty_Symbolic_State;
   begin
      if not State.Supported then
         return Havoc;
      end if;

      for Item of State.Roots loop
         if Is_Bound_Symbol (To_String (Item.Name)) then
            Result.Roots.Append (Item);
         end if;
      end loop;
      for Item of State.Assumptions loop
         if Only_Bounds (To_String (Item)) then
            Result.Assumptions.Append (Item);
         end if;
      end loop;
      return Result;
   exception
      when others =>
         return Havoc;
   end Array_Bound_Facts;

   function Assume_Loop_Range
     (State     : Symbolic_State;
      Parameter : Libadalang.Analysis.Ada_Node;
      Iteration : Libadalang.Analysis.Ada_Node'Class;
      Flow      : Domain.Flow_State) return Symbolic_State
   is
      Context : Translation_Context :=
        (State => Flow, Symbols => State, Supported => State.Supported,
         Object_Bindings => Object_Binding_Vectors.Empty_Vector,
         Failure_Reason => No_Unsupported_Reason,
         Failure_Node => Libadalang.Analysis.No_Ada_Node,
         Inlining_Path => Null_Unbounded_String, Depth => 0);

      --  True when Expr is built only from literals, names whose value
      --  cannot change, and bounds of array objects: its value on any
      --  iteration is its value when the loop was entered.
      function Fixed (Expr : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
      begin
         if Libadalang.Analysis.Is_Null (Expr) then
            return False;
         end if;

         case Expr.Kind is
            when Libadalang.Common.Ada_Int_Literal =>
               return True;
            when Libadalang.Common.Ada_Paren_Expr =>
               return Fixed (Expr.As_Paren_Expr.F_Expr);
            when Libadalang.Common.Ada_Un_Op =>
               return Fixed (Expr.As_Un_Op.F_Expr);
            when Libadalang.Common.Ada_Bin_Op_Range =>
               return Expr.As_Bin_Op.F_Op in
                   Libadalang.Common.Ada_Op_Plus
                     | Libadalang.Common.Ada_Op_Minus
                     | Libadalang.Common.Ada_Op_Mult
                 and then Fixed (Expr.As_Bin_Op.F_Left)
                 and then Fixed (Expr.As_Bin_Op.F_Right);
            when Libadalang.Common.Ada_Attribute_Ref =>
               return Attribute_Dimension (Expr.As_Attribute_Ref) /= 0
                 and then Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                   (Adalang_Analyzer.Ada_Text.Node_Text
                      (Expr.As_Attribute_Ref.F_Attribute)) in
                     "first" | "last" | "length"
                 and then
                   (not Libadalang.Analysis.Is_Null
                          (Array_Object_Key
                             (Context, Expr.As_Attribute_Ref.F_Prefix))
                    or else Eval.Is_Elaboration_Stable
                      (Expr.As_Attribute_Ref.F_Prefix));
            when others =>
               return Eval.Is_Elaboration_Stable (Expr);
         end case;
      end Fixed;

      Variable : Unbounded_String;
      Low      : Unbounded_String;
      High     : Unbounded_String;
   begin
      if Libadalang.Analysis.Is_Null (Iteration)
        or else Libadalang.Analysis.Is_Null (Parameter)
      then
         return State;
      end if;

      if Iteration.Kind = Libadalang.Common.Ada_Attribute_Ref
        and then Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
          (Adalang_Analyzer.Ada_Text.Node_Text
             (Iteration.As_Attribute_Ref.F_Attribute)) = "range"
        and then Attribute_Dimension (Iteration.As_Attribute_Ref) /= 0
        and then not Libadalang.Analysis.Is_Null
          (Array_Object_Key (Context, Iteration.As_Attribute_Ref.F_Prefix))
      then
         Low :=
           Array_Attribute_Term
             (Iteration.As_Attribute_Ref.F_Prefix, "first", Iteration,
              Context, Attribute_Dimension (Iteration.As_Attribute_Ref));
         High :=
           Array_Attribute_Term
             (Iteration.As_Attribute_Ref.F_Prefix, "last", Iteration,
              Context, Attribute_Dimension (Iteration.As_Attribute_Ref));
      elsif Iteration.Kind in Libadalang.Common.Ada_Bin_Op_Range
        and then Iteration.As_Bin_Op.F_Op =
          Libadalang.Common.Ada_Op_Double_Dot
        and then Fixed (Iteration.As_Bin_Op.F_Left)
        and then Fixed (Iteration.As_Bin_Op.F_Right)
      then
         Low := Integer_Term (Iteration.As_Bin_Op.F_Left, Context);
         High := Integer_Term (Iteration.As_Bin_Op.F_Right, Context);
      else
         return State;
      end if;

      if Context.Supported and then Length (Low) > 0 and then Length (High) > 0
      then
         Variable :=
           To_Unbounded_String
             (Symbol_For (Context, Plain_Key (Parameter), Integer_Sort));
      end if;
      if not Context.Supported or else Length (Variable) = 0 then
         return State;
      end if;

      Context.Symbols.Assumptions.Append
        (To_Unbounded_String
           ("(and (<= " & To_String (Low) & " " & To_String (Variable) &
            ") (<= " & To_String (Variable) & " " & To_String (High) & "))"));
      return Context.Symbols;
   exception
      when others =>
         return State;
   end Assume_Loop_Range;

   function Join_On_Range
     (True_Side, False_Side : Symbolic_State;
      Pre_Fork_Side          : Symbolic_State;
      Selector                : Libadalang.Analysis.Expr'Class;
      Bounds                  : Domain.Abstract_Range;
      Flow                    : Domain.Flow_State;
      Merge_Tag               : Positive) return Symbolic_State
   is
      Context : Translation_Context :=
        (State => Flow, Symbols => Pre_Fork_Side, others => <>);
      Term  : constant Unbounded_String := Integer_Term (Selector, Context);
      Goal_OK : constant Boolean :=
        Context.Supported and then Length (Term) > 0
        and then (Bounds.Has_Low or else Bounds.Has_High);
      Sel         : Unbounded_String;
      Extra_Roots : Symbolic_State := Empty_Symbolic_State;
   begin
      if not True_Side.Supported or else not False_Side.Supported
        or else not Pre_Fork_Side.Supported
      then
         return Havoc;
      end if;

      if Goal_OK then
         for Item of Context.Symbols.Roots loop
            Include_Root (Extra_Roots, Item);
         end loop;
         Sel := Range_Goal (Term, Bounds);
      else
         --  Selector doesn't translate, or Bounds is empty (an
         --  unresolved case choice): mint one anonymous, totally
         --  unconstrained boolean symbol, keyed to Selector's own source
         --  location, to stand in for "this alternative was taken" --
         --  the same sound-but-imprecise fallback Join_On_Condition uses
         --  for an untranslatable boolean condition.
         declare
            Key  : constant Symbol_Key :=
              Plain_Key (Libadalang.Analysis.Ada_Node (Selector));
            Name : constant String :=
              Root_Name (Key, "jr" & Natural_Image (Merge_Tag) & "_");
         begin
            Add_Root (Extra_Roots, Name, Key, Boolean_Sort, Flow);
            Sel := To_Unbounded_String (Name);
         end;
      end if;

      return Join_On_Selector
        (True_Side, False_Side, Extra_Roots, Sel, Flow, Merge_Tag);
   exception
      when others =>
         return Havoc;
   end Join_On_Range;

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

      --  An unsupported RHS translation upstream (e.g. VC.Assign's Havoc
      --  fallback) can leave Before_Term and After_Term as the literal
      --  same unconstrained placeholder symbol even though both sides
      --  independently reported success -- turning "cannot judge
      --  progress" into a tautological (> X X)/(< X X) goal that the
      --  solver correctly reports UNSAT, which reads as a *proven*
      --  variant violation instead of the translation gap it is (FP-061).
      if Before_Term = After_Term then
         Mark_Unsupported (After_Context, Value, Translation_Error);
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
         when Branch_Budget_Exceeded =>
            return "branch-budget-exceeded";
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
         when Branch_Budget_Exceeded =>
            return "the loop path has more independent conditionals than " &
              "the branch budget folds";
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
