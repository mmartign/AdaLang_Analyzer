--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Langkit_Support.Slocs;
with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;    use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.SPARK_Readiness;
with Adalang_Analyzer.Subprogram_Summaries;
with Adalang_Analyzer.Text_Utils;  use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Termination is

   package Proof renames Adalang_Analyzer.Proof_Obligations;

   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Call_Expr_Kind;

   --  What is known of one subprogram body. In_Progress while its callees
   --  are being looked at: meeting it again then is a recursion.
   type Verdict_Kind is (In_Progress, Terminates, Not_Shown);

   type Verdict (Kind : Verdict_Kind := Not_Shown) is record
      case Kind is
         when Not_Shown =>
            Reason : Unbounded_String;
         when others =>
            null;
      end case;
   end record;

   Shown : constant Verdict := (Kind => Terminates);

   function No (Reason : String) return Verdict
   is (Kind => Not_Shown, Reason => To_Unbounded_String (Reason));

   package Verdict_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Verdict,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   Known : Verdict_Maps.Map;

   procedure Reset is
   begin
      Known.Clear;
   end Reset;

   function Text_Of
     (Text : Langkit_Support.Text.Text_Type) return String
   is (Langkit_Support.Text.To_UTF8 (Text));

   function Unique_Name
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return String is
   begin
      return Text_Of (Decl.P_Unique_Identifying_Name);
   exception
      when others =>
         return "";
   end Unique_Name;

   function Display_Name
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return String is
   begin
      return Node_Text (Decl.P_Defining_Name);
   exception
      when others =>
         return "a subprogram";
   end Display_Name;

   --  True when Decl is declared in a unit of the language-defined
   --  library or of the GNAT one.
   function Is_Library_Unit_Entity
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Name : constant String :=
        Normalize_Rule_Name
          (Text_Of
             (Decl.P_Enclosing_Compilation_Unit.P_Decl
                .P_Fully_Qualified_Name));

      function Starts_With (Prefix : String) return Boolean
      is (Name = Prefix
          or else
            (Name'Length > Prefix'Length
             and then Name (Name'First .. Name'First + Prefix'Length) =
               Prefix & "."));
   begin
      return Starts_With ("ada")
        or else Starts_With ("interfaces")
        or else Starts_With ("system")
        or else Starts_With ("gnat");
   exception
      when others =>
         return False;
   end Is_Library_Unit_Entity;

   function Has_Aspect
     (Decl : Libadalang.Analysis.Basic_Decl'Class;
      Name : String) return Libadalang.Analysis.Aspect
   is (Decl.P_Get_Aspect
         (Langkit_Support.Text.To_Unbounded_Text
            (Langkit_Support.Text.To_Text (Name))));

   function Is_Intrinsic
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Convention : constant Libadalang.Analysis.Aspect :=
        Has_Aspect (Decl, "Convention");
   begin
      return Libadalang.Analysis.Exists (Convention)
        and then not Libadalang.Analysis.Is_Null
                       (Libadalang.Analysis.Value (Convention))
        and then Normalize_Rule_Name
                   (Node_Text (Libadalang.Analysis.Value (Convention))) =
                 "intrinsic";
   exception
      when others =>
         return False;
   end Is_Intrinsic;

   function Is_Function
     (Spec : Libadalang.Analysis.Base_Subp_Spec'Class) return Boolean
   is (not Libadalang.Analysis.Is_Null (Spec)
       and then not Libadalang.Analysis.Is_Null (Spec.P_Returns));

   function Body_Verdict
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class) return Verdict;

   --  A call to the generic formal subprogram Formal returns when the
   --  subprogram each instantiation in this run gives it returns (a null
   --  default does).
   function Formal_Verdict
     (Formal : Libadalang.Analysis.Basic_Decl'Class;
      Depth  : Natural) return Verdict;

   --  Whether a call to Decl returns, as far as its declaration and its
   --  body, when there is one to look at, show.
   function Callee_Verdict
     (Decl  : Libadalang.Analysis.Basic_Decl'Class;
      Depth : Natural := 0) return Verdict
   is
      Max_Renamings : constant := 8;
      Name          : constant String := Display_Name (Decl);

      --  The verdict on the body of the callee, said of the call: the
      --  reason names the callee and, when the callee fails through a
      --  call of its own, stops there.
      function Through (Callee : Verdict) return Verdict is
      begin
         if Callee.Kind /= Not_Shown then
            return Callee;
         end if;

         declare
            Reason : constant String := To_String (Callee.Reason);
            Stop   : constant Natural :=
              (if Reason'Length > 6
                 and then Reason (Reason'First .. Reason'First + 5) =
                   "calls "
               then Ada.Strings.Fixed.Index (Reason, ": ")
               else 0);
         begin
            return No
              ("calls " & Name & ", not shown to return: " &
               (if Stop = 0 then Reason
                else Reason (Reason'First .. Stop - 1)));
         end;
      end Through;

      function Of_Body
        (Next : Libadalang.Analysis.Ada_Node'Class) return Verdict is
      begin
         if Libadalang.Analysis.Is_Null (Next) then
            return No ("the body of " & Name & " was not found");
         end if;

         case Next.Kind is
            when Libadalang.Common.Ada_Subp_Body
               | Libadalang.Common.Ada_Expr_Function =>
               return Through (Body_Verdict (Next.As_Base_Subp_Body));
            when Libadalang.Common.Ada_Null_Subp_Decl =>
               return Shown;
            when Libadalang.Common.Ada_Subp_Renaming_Decl
               | Libadalang.Common.Ada_Subp_Body_Stub =>
               return Callee_Verdict (Next.As_Basic_Decl, Depth + 1);
            when others =>
               return No ("the body of " & Name & " was not found");
         end case;
      end Of_Body;
   begin
      if Libadalang.Analysis.Is_Null (Decl) or else Depth > Max_Renamings
      then
         return No ("a call was not resolved");
      end if;

      case Decl.Kind is
         when Libadalang.Common.Ada_Enum_Literal_Decl
            | Libadalang.Common.Ada_Synthetic_Subp_Decl
            | Libadalang.Common.Ada_Null_Subp_Decl =>
            --  A literal, a predefined operation, a null procedure.
            return Shown;

         when Libadalang.Common.Ada_Subp_Body
            | Libadalang.Common.Ada_Expr_Function =>
            return Through (Body_Verdict (Decl.As_Base_Subp_Body));

         when Libadalang.Common.Ada_Subp_Decl
            | Libadalang.Common.Ada_Generic_Subp_Internal =>
            if Is_Intrinsic (Decl) then
               return Shown;
            elsif Is_Library_Unit_Entity (Decl) then
               --  The bodies of the run-time library are not followed. Its
               --  functions return; a procedure of it may wait for ever.
               if Is_Function (Decl.As_Basic_Subp_Decl.P_Subp_Decl_Spec) then
                  return Shown;
               end if;
               return No
                 (Name & " is a library procedure not known to terminate");
            elsif Decl.P_Is_Imported then
               return No (Name & " is imported and has no body to look at");
            end if;
            return Of_Body (Decl.P_Body_Part_For_Decl);

         when Libadalang.Common.Ada_Subp_Body_Stub =>
            return Of_Body (Decl.P_Next_Part_For_Decl);

         when Libadalang.Common.Ada_Subp_Renaming_Decl =>
            declare
               Renamed : constant Libadalang.Analysis.Name :=
                 Decl.As_Subp_Renaming_Decl.F_Renames.F_Renamed_Object;
            begin
               if Renamed.Kind = Libadalang.Common.Ada_Attribute_Ref then
                  --  A predefined attribute used as a subprogram.
                  return Shown;
               end if;
               return Callee_Verdict (Renamed.P_Referenced_Decl, Depth + 1);
            end;

         when Libadalang.Common.Ada_Generic_Subp_Instantiation =>
            declare
               Generic_Name : constant String :=
                 Normalize_Rule_Name
                   (Text_Of
                      (Decl.As_Generic_Subp_Instantiation
                         .P_Designated_Generic_Decl
                         .P_Fully_Qualified_Name));
            begin
               if Generic_Name in "ada.unchecked_conversion"
                    | "ada.unchecked_deallocation"
                    | "unchecked_conversion"
                    | "unchecked_deallocation"
               then
                  return Shown;
               end if;
               return Of_Body
                 (Decl.As_Generic_Subp_Instantiation
                    .P_Designated_Generic_Decl.P_Body_Part_For_Decl);
            end;

         when Libadalang.Common.Ada_Abstract_Subp_Decl =>
            return No (Name & " is abstract: the call dispatches");

         when Libadalang.Common.Ada_Formal_Subp_Decl =>
            return Formal_Verdict (Decl, Depth + 1);

         when Libadalang.Common.Ada_Entry_Decl =>
            return No ("the entry call to " & Name & " may wait for ever");

         when others =>
            return No ("the call to " & Name & " was not resolved to a " &
                       "subprogram");
      end case;
   exception
      when Exc : others =>
         return No
           ("the call to " & Name & " was not resolved: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Callee_Verdict;

   --  True for "in" over a discrete range or subtype, and for "of" over
   --  an array: iterations that end by themselves. Any other iteration
   --  calls the operations of an iterator.
   function Is_Bounded_Iteration
     (Spec : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Spec)
        or else Spec.Kind /= Libadalang.Common.Ada_For_Loop_Spec
      then
         return False;
      end if;

      declare
         Loop_Spec : constant Libadalang.Analysis.For_Loop_Spec :=
           Spec.As_For_Loop_Spec;
         Domain    : constant Libadalang.Analysis.Ada_Node :=
           Loop_Spec.F_Iter_Expr;
      begin
         if Loop_Spec.F_Loop_Type.Kind = Libadalang.Common.Ada_Iter_Type_Of
         then
            declare
               Typ : constant Libadalang.Analysis.Base_Type_Decl :=
                 Domain.As_Expr.P_Expression_Type;
            begin
               return not Libadalang.Analysis.Is_Null (Typ)
                 and then Typ.P_Is_Array_Type;
            end;
         end if;

         case Domain.Kind is
            when Libadalang.Common.Ada_Bin_Op =>
               return Domain.As_Bin_Op.F_Op.Kind =
                 Libadalang.Common.Ada_Op_Double_Dot;
            when Libadalang.Common.Ada_Subtype_Indication_Range =>
               return True;
            when Libadalang.Common.Ada_Attribute_Ref =>
               return Normalize_Rule_Name
                 (Node_Text (Domain.As_Attribute_Ref.F_Attribute)) = "range";
            when Libadalang.Common.Ada_Identifier
               | Libadalang.Common.Ada_Dotted_Name =>
               declare
                  Decl : constant Libadalang.Analysis.Basic_Decl :=
                    Domain.As_Name.P_Referenced_Decl;
               begin
                  return not Libadalang.Analysis.Is_Null (Decl)
                    and then Decl.Kind in
                      Libadalang.Common.Ada_Base_Type_Decl;
               end;
            when others =>
               return False;
         end case;
      end;
   exception
      when others =>
         return False;
   end Is_Bounded_Iteration;

   --  What Node, a part of a subprogram being looked at, and all under it
   --  show: Shown unless something in it may not return.
   function Part_Verdict
     (Node : Libadalang.Analysis.Ada_Node'Class) return Verdict
   is
      function Children_From (First : Positive) return Verdict is
      begin
         for Index in First .. Node.Children_Count loop
            declare
               Result : constant Verdict := Part_Verdict (Node.Child (Index));
            begin
               if Result.Kind /= Terminates then
                  return Result;
               end if;
            end;
         end loop;
         return Shown;
      end Children_From;

      --  The verdict on the subprogram Name denotes, when it denotes one.
      function Reference_Verdict
        (Name : Libadalang.Analysis.Name'Class) return Verdict
      is
         Decl : constant Libadalang.Analysis.Basic_Decl :=
           Name.P_Referenced_Decl;
      begin
         if Libadalang.Analysis.Is_Null (Decl)
           or else Decl.Kind not in Libadalang.Common.Ada_Basic_Subp_Decl
             | Libadalang.Common.Ada_Base_Subp_Body
             | Libadalang.Common.Ada_Subp_Body_Stub
             | Libadalang.Common.Ada_Generic_Subp_Instantiation
             | Libadalang.Common.Ada_Entry_Decl
         then
            return Shown;
         elsif Name.P_Is_Dispatching_Call then
            return No
              ("the call to " & Display_Name (Decl) & " dispatches");
         end if;
         return Callee_Verdict (Decl);
      end Reference_Verdict;
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Shown;
      end if;

      case Node.Kind is
         --  What is declared here and runs only when called is looked at
         --  where it is called.
         when Libadalang.Common.Ada_Subp_Body
            | Libadalang.Common.Ada_Expr_Function
            | Libadalang.Common.Ada_Subp_Decl
            | Libadalang.Common.Ada_Null_Subp_Decl
            | Libadalang.Common.Ada_Abstract_Subp_Decl
            | Libadalang.Common.Ada_Subp_Renaming_Decl
            | Libadalang.Common.Ada_Subp_Body_Stub
            | Libadalang.Common.Ada_Generic_Subp_Decl
            | Libadalang.Common.Ada_Generic_Subp_Instantiation
            | Libadalang.Common.Ada_Generic_Package_Decl
            | Libadalang.Common.Ada_Defining_Name
            | Libadalang.Common.Ada_End_Name
            | Libadalang.Common.Ada_Pragma_Argument_Assoc =>
            if Node.Kind = Libadalang.Common.Ada_Pragma_Argument_Assoc then
               --  The condition of an assertion is evaluated; the name a
               --  pragma such as Inline or Unreferenced is given is not.
               declare
                  Owner : constant Libadalang.Analysis.Ada_Node :=
                    Node.Parent.Parent;
               begin
                  if Owner.Kind = Libadalang.Common.Ada_Pragma_Node
                    and then Normalize_Rule_Name
                               (Node_Text (Owner.As_Pragma_Node.F_Id)) in
                      "assert" | "assume" | "assert-and-cut"
                        | "loop-invariant" | "loop-variant" | "check"
                  then
                     return Children_From (1);
                  end if;
               end;
            end if;
            return Shown;

         when Libadalang.Common.Ada_Loop_Stmt
            | Libadalang.Common.Ada_While_Loop_Stmt =>
            return No ("a loop that is not a for loop is not shown to end");

         when Libadalang.Common.Ada_For_Loop_Stmt =>
            if not Is_Bounded_Iteration (Node.As_For_Loop_Stmt.F_Spec) then
               return No
                 ("a for loop over something other than a discrete range " &
                  "or an array is not shown to end");
            end if;
            return Children_From (1);

         when Libadalang.Common.Ada_Quantified_Expr =>
            if not Is_Bounded_Iteration (Node.As_Quantified_Expr.F_Loop_Spec)
            then
               return No
                 ("a quantified expression over something other than a " &
                  "discrete range or an array is not shown to end");
            end if;
            return Children_From (1);

         when Libadalang.Common.Ada_Goto_Stmt =>
            return No ("a goto may form a loop");

         when Libadalang.Common.Ada_Delay_Stmt
            | Libadalang.Common.Ada_Accept_Stmt
            | Libadalang.Common.Ada_Accept_Stmt_With_Stmts
            | Libadalang.Common.Ada_Select_Stmt
            | Libadalang.Common.Ada_Requeue_Stmt
            | Libadalang.Common.Ada_Abort_Stmt
            | Libadalang.Common.Ada_Task_Body
            | Libadalang.Common.Ada_Single_Task_Decl
            | Libadalang.Common.Ada_Task_Type_Decl
            | Libadalang.Common.Ada_Protected_Body
            | Libadalang.Common.Ada_Single_Protected_Decl
            | Libadalang.Common.Ada_Protected_Type_Decl =>
            return No ("tasking and delays are not followed");

         when Libadalang.Common.Ada_Generic_Package_Instantiation =>
            return No
              ("the elaboration of a package instance is not followed");

         when Libadalang.Common.Ada_Attribute_Ref =>
            declare
               Attribute : constant String :=
                 Normalize_Rule_Name
                   (Node_Text (Node.As_Attribute_Ref.F_Attribute));
            begin
               if Attribute in "read" | "write" | "input" | "output"
                    | "put-image"
               then
                  return No
                    ("a stream or image attribute may call a user " &
                     "subprogram");
               elsif Attribute in "result" | "access" | "unchecked-access"
                       | "unrestricted-access" | "address"
               then
                  --  The prefix names a subprogram without calling it.
                  return Shown;
               end if;
               return Children_From (1);
            end;

         when Libadalang.Common.Ada_Call_Expr =>
            declare
               Call   : constant Libadalang.Analysis.Call_Expr :=
                 Node.As_Call_Expr;
               Kind   : constant Libadalang.Common.Call_Expr_Kind :=
                 Call.P_Kind;
               Prefix : constant Libadalang.Analysis.Base_Type_Decl :=
                 (if Kind = Libadalang.Common.Array_Index
                  then Call.F_Name.P_Expression_Type
                  else Libadalang.Analysis.No_Base_Type_Decl);
            begin
               if Kind = Libadalang.Common.Call then
                  if Call.F_Name.Kind = Libadalang.Common.Ada_Explicit_Deref
                  then
                     return No ("a call through an access value");
                  end if;

                  declare
                     Decl : constant Libadalang.Analysis.Basic_Decl :=
                       Call.F_Name.P_Referenced_Decl;
                  begin
                     if Libadalang.Analysis.Is_Null (Decl)
                       or else Decl.Kind not in
                         Libadalang.Common.Ada_Basic_Subp_Decl
                           | Libadalang.Common.Ada_Base_Subp_Body
                           | Libadalang.Common.Ada_Subp_Body_Stub
                           | Libadalang.Common.Ada_Generic_Subp_Instantiation
                           | Libadalang.Common.Ada_Entry_Decl
                           | Libadalang.Common.Ada_Enum_Literal_Decl
                     then
                        return No
                          ("the call " & Node_Text (Call.F_Name) &
                           " is not to a subprogram that was resolved");
                     end if;
                  end;
               elsif Kind = Libadalang.Common.Array_Index
                 and then
                   (Libadalang.Analysis.Is_Null (Prefix)
                    or else
                      (not Prefix.P_Is_Array_Type
                       and then not Prefix.P_Is_Access_Type))
               then
                  return No
                    ("indexing of something other than an array calls a " &
                     "user subprogram");
               end if;
               return Children_From (1);
            end;

         when Libadalang.Common.Ada_Dotted_Name =>
            declare
               Result : constant Verdict :=
                 Reference_Verdict (Node.As_Dotted_Name);
            begin
               if Result.Kind /= Terminates then
                  return Result;
               end if;
               --  The prefix may itself hold a call; the selector is the
               --  name just looked at.
               return Part_Verdict (Node.As_Dotted_Name.F_Prefix);
            end;

         when Libadalang.Common.Ada_Identifier
            | Libadalang.Common.Ada_String_Literal =>
            if Node.Kind = Libadalang.Common.Ada_String_Literal
              and then
                (Libadalang.Analysis.Is_Null (Node.Parent)
                 or else Node.Parent.Kind /= Libadalang.Common.Ada_Call_Expr)
            then
               return Shown;
            end if;
            return Reference_Verdict (Node.As_Name);

         when Libadalang.Common.Ada_Bin_Op
            | Libadalang.Common.Ada_Relation_Op
            | Libadalang.Common.Ada_Concat_Operand
            | Libadalang.Common.Ada_Un_Op =>
            --  A user-defined operator is a call as any other.
            declare
               Operator : constant Libadalang.Analysis.Name :=
                 (case Node.Kind is
                     when Libadalang.Common.Ada_Un_Op =>
                       Node.As_Un_Op.F_Op.As_Name,
                     when Libadalang.Common.Ada_Concat_Operand =>
                       Node.As_Concat_Operand.F_Operator.As_Name,
                     when others => Node.As_Bin_Op.F_Op.As_Name);
               Result   : constant Verdict :=
                 (if Libadalang.Analysis.Is_Null (Operator) then Shown
                  else Reference_Verdict (Operator));
            begin
               if Result.Kind /= Terminates then
                  return Result;
               end if;
               return Children_From (1);
            end;

         when others =>
            return Children_From (1);
      end case;
   exception
      when Exc : others =>
         return No
           ("a part of the body was not resolved: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Part_Verdict;

   function Body_Verdict
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class) return Verdict
   is
      Key : constant String := Unique_Name (Subprogram);
   begin
      if Key = "" then
         return No ("a subprogram could not be identified");
      elsif Known.Contains (Key) then
         declare
            Earlier : constant Verdict := Known.Element (Key);
         begin
            if Earlier.Kind = In_Progress then
               return No
                 ("recursion through " & Display_Name (Subprogram));
            end if;
            return Earlier;
         end;
      end if;

      Known.Insert (Key, (Kind => In_Progress));

      declare
         Result : Verdict := Shown;
      begin
         --  The parts that run when the subprogram is called: what it
         --  declares, what it does, and the contracts checked around it.
         --  The profile is not one of them.
         for Index in 1 .. Subprogram.Children_Count loop
            if not Libadalang.Analysis.Is_Null (Subprogram.Child (Index))
              and then Subprogram.Child (Index).Kind not in
                Libadalang.Common.Ada_Subp_Spec
                  | Libadalang.Common.Ada_Overriding_Node
                  | Libadalang.Common.Ada_End_Name
            then
               Result := Part_Verdict (Subprogram.Child (Index));
               exit when Result.Kind /= Terminates;
            end if;
         end loop;

         Known.Replace (Key, Result);
         return Result;
      end;
   exception
      when Exc : others =>
         declare
            Result : constant Verdict :=
              No ("the body was not analyzed: " &
                  Ada.Exceptions.Exception_Message (Exc));
         begin
            if Known.Contains (Key) then
               Known.Replace (Key, Result);
            end if;
            return Result;
         end;
   end Body_Verdict;

   --  True when Decl has the aspect Always_Terminates, not given as False.
   function Says_Terminates
     (Decl : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Aspect : constant Libadalang.Analysis.Aspect :=
        Has_Aspect (Decl, "Always_Terminates");
   begin
      return Libadalang.Analysis.Exists (Aspect)
        and then
          (Libadalang.Analysis.Is_Null
             (Libadalang.Analysis.Value (Aspect))
           or else Normalize_Rule_Name
                     (Node_Text (Libadalang.Analysis.Value (Aspect))) /=
                   "false");
   exception
      when others =>
         return False;
   end Says_Terminates;

   --  True when a package around Node (its declaration, or that of the
   --  body Node is in) has Always_Terminates, or when Node is in a generic
   --  unit that has not and some instantiation of it in this run is in
   --  such a place: GNATprove then requires termination of the instance.
   function Context_Terminates
     (Node  : Libadalang.Analysis.Ada_Node'Class;
      Depth : Natural) return Boolean
   is
      Max_Depth : constant := 6;
      Ancestor  : Libadalang.Analysis.Ada_Node := Node.Parent;
      Spec      : Libadalang.Analysis.Basic_Decl;
   begin
      if Depth > Max_Depth then
         return False;
      end if;
      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         Spec := Libadalang.Analysis.No_Basic_Decl;
         case Ancestor.Kind is
            when Libadalang.Common.Ada_Package_Decl
               | Libadalang.Common.Ada_Generic_Package_Internal =>
               Spec := Ancestor.As_Basic_Decl;
            when Libadalang.Common.Ada_Package_Body =>
               begin
                  Spec := Ancestor.As_Package_Body.P_Decl_Part;
               exception
                  when others =>
                     Spec := Libadalang.Analysis.No_Basic_Decl;
               end;
            when others =>
               null;
         end case;
         if not Libadalang.Analysis.Is_Null (Spec)
           and then Spec.Kind = Libadalang.Common.Ada_Generic_Package_Decl
         then
            Spec := Spec.As_Generic_Package_Decl.F_Package_Decl.As_Basic_Decl;
         end if;
         if not Libadalang.Analysis.Is_Null (Spec) then
            if Says_Terminates (Spec) then
               return True;
            elsif Spec.Kind = Libadalang.Common.Ada_Generic_Package_Internal
            then
               declare
                  Key  : constant String :=
                    Subprogram_Summaries.Generic_Unit_Key (Spec);
                  Any  : Boolean := False;
                  Lost : Boolean;

                  procedure Visit
                    (Instance : Libadalang.Analysis.Generic_Instantiation) is
                  begin
                     if not Any
                       and then Context_Terminates (Instance, Depth + 1)
                     then
                        Any := True;
                     end if;
                  end Visit;
               begin
                  if Key /= "" then
                     Subprogram_Summaries.For_Each_Instantiation
                       (Key, Node, Visit'Access, Lost);
                     if Any then
                        return True;
                     end if;
                  end if;
               end;
            end if;
         end if;
         Ancestor := Ancestor.Parent;
      end loop;
      return False;
   exception
      when others =>
         return False;
   end Context_Terminates;

   function Given_In
     (Instance : Libadalang.Analysis.Generic_Instantiation'Class;
      Actual   : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      use type Langkit_Support.Slocs.Relative_Position;
   begin
      return not Libadalang.Analysis.Is_Null (Actual)
        and then Actual.Unit.Get_Filename = Instance.Unit.Get_Filename
        and then Langkit_Support.Slocs.Compare
                   (Instance.Sloc_Range,
                    Langkit_Support.Slocs.Start_Sloc (Actual.Sloc_Range)) =
                 Langkit_Support.Slocs.Inside;
   exception
      when others =>
         return False;
   end Given_In;

   --  The equality of Typ is that of scalars: no user-defined "=" can be
   --  composed into it.
   function Plain_Equality
     (Typ   : Libadalang.Analysis.Base_Type_Decl'Class;
      Depth : Natural) return Boolean
   is
      Full : Libadalang.Analysis.Base_Type_Decl;
   begin
      if Libadalang.Analysis.Is_Null (Typ) or else Depth > 3 then
         return False;
      end if;
      --  A private type: its full view.
      Full := Typ.P_Full_View;
      if Libadalang.Analysis.Is_Null (Full) then
         Full := Libadalang.Analysis.Base_Type_Decl (Typ);
      end if;
      if Full.P_Is_Scalar_Type or else Full.P_Is_Access_Type then
         return True;
      elsif Full.P_Is_Array_Type then
         return Plain_Equality (Full.P_Comp_Type, Depth + 1);
      elsif not Full.P_Is_Record_Type then
         return False;
      end if;
      if Libadalang.Analysis.Is_Null (Full)
        or else Full.Kind /= Libadalang.Common.Ada_Concrete_Type_Decl
        or else Full.As_Concrete_Type_Decl.F_Type_Def.Kind /=
                Libadalang.Common.Ada_Record_Type_Def
      then
         return False;
      end if;
      declare
         Def : constant Libadalang.Analysis.Base_Record_Def :=
           Full.As_Concrete_Type_Decl.F_Type_Def.As_Record_Type_Def
             .F_Record_Def;
      begin
         if not Libadalang.Analysis.Is_Null (Def.F_Components.F_Variant_Part)
         then
            return False;
         end if;
         for Item of Def.F_Components.F_Components loop
            if Item.Kind = Libadalang.Common.Ada_Component_Decl then
               if not Plain_Equality
                 (Item.As_Component_Decl.F_Component_Def.F_Type_Expr
                    .P_Designated_Type_Decl, Depth + 1)
               then
                  return False;
               end if;
            elsif Item.Kind not in Libadalang.Common.Ada_Pragma_Node
                                 | Libadalang.Common.Ada_Null_Component_Decl
            then
               return False;
            end if;
         end loop;
      end;
      return True;
   exception
      when others =>
         return False;
   end Plain_Equality;

   --  Where the first part of Decl is declared: tells two declarations, or
   --  two parts of one, apart.
   function Place_Of (Decl : Libadalang.Analysis.Basic_Decl'Class) return String
   is
      First : Libadalang.Analysis.Basic_Decl := Decl.P_Canonical_Part;
   begin
      if Libadalang.Analysis.Is_Null (First) then
         First := Libadalang.Analysis.Basic_Decl (Decl);
      end if;
      return First.Unit.Get_Filename & ":" &
        Langkit_Support.Slocs.Image (First.P_Defining_Name.Sloc_Range);
   exception
      when others =>
         return "";
   end Place_Of;

   --  Place_Of the type Typ is a subtype of.
   function Type_Place
     (Typ : Libadalang.Analysis.Base_Type_Decl'Class) return String
   is
      Base : Libadalang.Analysis.Base_Type_Decl :=
        Libadalang.Analysis.Base_Type_Decl (Typ);
   begin
      if Libadalang.Analysis.Is_Null (Base) then
         return "";
      elsif Base.Kind = Libadalang.Common.Ada_Subtype_Decl then
         Base := Base.P_Base_Subtype;
      end if;
      return Place_Of (Base);
   exception
      when others =>
         return "";
   end Type_Place;

   --  True when a subprogram or entry named Name with Arity parameters,
   --  other than Chosen, could be visible at Instance with a first
   --  parameter of type Typ: declared in a declarative region around
   --  Instance, in the generic formal part of one, in a parent unit, or in
   --  a package or among the primitives of a type that a use clause there
   --  names. The <> default of a formal subprogram could then take it.
   --  Anything not understood counts as one.
   function Other_Homograph
     (Instance : Libadalang.Analysis.Generic_Instantiation'Class;
      Name     : String;
      Arity    : Natural;
      Typ      : Libadalang.Analysis.Base_Type_Decl'Class;
      Chosen   : Libadalang.Analysis.Basic_Decl'Class) return Boolean
   is
      Max_Units    : constant := 16;
      Wanted_Type  : constant String := Type_Place (Typ);
      Chosen_Place : constant String :=
        (if Libadalang.Analysis.Is_Null (Chosen) then ""
         else Place_Of (Chosen));
      Found        : Boolean := False;
      Units        : Natural := 0;

      --  A package around Instance: its private part and its use clauses
      --  count. A package a use clause names: its visible part alone. An
      --  instance a use clause names: the same, a formal type there being
      --  its actual, any type.
      type Scan_Mode is (Enclosing, Used, Used_Instance);

      --  Decl, if a subprogram or an entry, could be taken.
      procedure Check
        (Decl : Libadalang.Analysis.Basic_Decl'Class;
         Mode : Scan_Mode) is
         Spec  : Libadalang.Analysis.Base_Subp_Spec;
         Count : Natural := 0;
         First : Libadalang.Analysis.Base_Type_Decl;
      begin
         if Found
           or else Decl.Kind not in
             Libadalang.Common.Ada_Basic_Subp_Decl
             | Libadalang.Common.Ada_Base_Subp_Body
             | Libadalang.Common.Ada_Subp_Body_Stub
             | Libadalang.Common.Ada_Generic_Subp_Instantiation
         then
            return;
         end if;
         declare
            Full : constant String :=
              Normalize_Rule_Name (Node_Text (Decl.P_Defining_Name));
            Dot  : constant Natural :=
              Ada.Strings.Fixed.Index (Full, ".", Ada.Strings.Backward);
         begin
            if (if Dot = 0 or else Full (Full'First) = '"' then Full
                else Full (Dot + 1 .. Full'Last)) /= Name
            then
               return;
            end if;
         end;
         if Chosen_Place /= "" and then Place_Of (Decl) = Chosen_Place then
            return;
         end if;
         Spec := Decl.P_Subp_Spec_Or_Null;
         if Libadalang.Analysis.Is_Null (Spec) then
            Found := True;
            return;
         end if;
         for Param of Spec.P_Params loop
            Count := Count + Param.F_Ids.Children_Count;
            if Libadalang.Analysis.Is_Null (First) then
               First := Param.F_Type_Expr.P_Designated_Type_Decl;
            end if;
         end loop;
         if Count /= Arity then
            return;
         end if;
         --  A formal type of an enclosing generic unit is a type of its
         --  own, there being resolved once for all instances; in an
         --  instance that a use clause names, it is its actual.
         Found := Libadalang.Analysis.Is_Null (First)
           or else (Mode = Used_Instance
                    and then First.Kind =
                             Libadalang.Common.Ada_Formal_Type_Decl)
           or else Type_Place (First) = Wanted_Type;
      exception
         when others =>
            Found := True;
      end Check;

      procedure Scan_Package
        (Decl : Libadalang.Analysis.Basic_Decl'Class;
         Mode : Scan_Mode);

      --  A package a use clause names, or the primitives of a type.
      procedure Scan_Use (Clause : Libadalang.Analysis.Ada_Node'Class) is
      begin
         if Clause.Kind = Libadalang.Common.Ada_Use_Package_Clause then
            for Named of Clause.As_Use_Package_Clause.F_Packages loop
               Scan_Package (Named.As_Name.P_Referenced_Decl, Used);
            end loop;
         elsif Clause.Kind = Libadalang.Common.Ada_Use_Type_Clause then
            for Named of Clause.As_Use_Type_Clause.F_Types loop
               declare
                  Target : constant Libadalang.Analysis.Basic_Decl :=
                    Named.As_Name.P_Referenced_Decl;
               begin
                  if Libadalang.Analysis.Is_Null (Target)
                    or else Target.Kind not in
                      Libadalang.Common.Ada_Base_Type_Decl
                  then
                     Found := True;
                  else
                     for Prim of Target.As_Base_Type_Decl.P_Get_Primitives
                     loop
                        Check (Prim, Used);
                     end loop;
                  end if;
               end;
            end loop;
         end if;
      exception
         when others =>
            Found := True;
      end Scan_Use;

      --  A declaration of a region: a generic formal, or another.
      procedure Check_Item
        (Item : Libadalang.Analysis.Ada_Node'Class;
         Mode : Scan_Mode) is
      begin
         if Item.Kind in Libadalang.Common.Ada_Generic_Formal then
            Check (Item.As_Generic_Formal.F_Decl, Mode);
         elsif Item.Kind in Libadalang.Common.Ada_Basic_Decl then
            Check (Item.As_Basic_Decl, Mode);
         end if;
      end Check_Item;

      procedure Scan_List
        (List : Libadalang.Analysis.Ada_Node'Class;
         Mode : Scan_Mode) is
      begin
         if Libadalang.Analysis.Is_Null (List) then
            return;
         end if;
         for Item of List.Children loop
            exit when Found;
            if not Libadalang.Analysis.Is_Null (Item) then
               if Item.Kind not in Libadalang.Common.Ada_Use_Clause then
                  Check_Item (Item, Mode);
               elsif Mode = Enclosing then
                  Scan_Use (Item);
               end if;
            end if;
         end loop;
      end Scan_List;

      procedure Scan_Package
        (Decl : Libadalang.Analysis.Basic_Decl'Class;
         Mode : Scan_Mode) is
      begin
         if Libadalang.Analysis.Is_Null (Decl) then
            Found := True;
            return;
         end if;
         case Decl.Kind is
            when Libadalang.Common.Ada_Base_Package_Decl =>
               declare
                  Pkg : constant Libadalang.Analysis.Base_Package_Decl :=
                    Decl.As_Base_Package_Decl;
               begin
                  Scan_List (Pkg.F_Public_Part.F_Decls, Mode);
                  if Mode = Enclosing
                    and then not Libadalang.Analysis.Is_Null
                                   (Pkg.F_Private_Part)
                  then
                     Scan_List (Pkg.F_Private_Part.F_Decls, Mode);
                  end if;
                  if Pkg.Kind = Libadalang.Common.Ada_Generic_Package_Internal
                  then
                     Scan_List
                       (Pkg.Parent.As_Generic_Decl.F_Formal_Part.F_Decls,
                        Mode);
                  end if;
               end;
            when Libadalang.Common.Ada_Generic_Package_Decl =>
               Scan_Package
                 (Decl.As_Generic_Package_Decl.F_Package_Decl,
                  Mode);
            when Libadalang.Common.Ada_Package_Renaming_Decl =>
               Scan_Package
                 (Decl.As_Package_Renaming_Decl.P_Final_Renamed_Package,
                  Mode);
            when Libadalang.Common.Ada_Generic_Package_Instantiation =>
               --  The instance's visible part: its formals, as renamings
               --  of the actuals, and the generic's public part.
               Scan_Package
                 (Decl.As_Generic_Instantiation.P_Designated_Generic_Decl,
                  Used_Instance);
            when others =>
               Found := True;
         end case;
      exception
         when others =>
            Found := True;
      end Scan_Package;

      --  The context clause of Unit, that of its declaration when it is a
      --  body, and its parent units with theirs.
      procedure Scan_Unit (Unit : Libadalang.Analysis.Compilation_Unit) is
         Item : Libadalang.Analysis.Basic_Decl;
         Spec : Libadalang.Analysis.Basic_Decl;
         Unit_Name : Libadalang.Analysis.Name;
      begin
         Units := Units + 1;
         if Libadalang.Analysis.Is_Null (Unit) or else Units > Max_Units
           or else Unit.F_Body.Kind = Libadalang.Common.Ada_Subunit
         then
            Found := True;
            return;
         end if;
         Scan_List (Unit.F_Prelude, Enclosing);
         Item := Unit.P_Decl;
         if Libadalang.Analysis.Is_Null (Item) then
            Found := True;
            return;
         end if;
         if Item.Kind in Libadalang.Common.Ada_Body_Node then
            Spec := Item.As_Body_Node.P_Decl_Part;
            if not Libadalang.Analysis.Is_Null (Spec)
              and then Spec.Unit.Get_Filename /= Item.Unit.Get_Filename
            then
               Scan_Unit (Spec.P_Enclosing_Compilation_Unit);
            end if;
         end if;
         Unit_Name := Item.P_Defining_Name.F_Name;
         if Unit_Name.Kind = Libadalang.Common.Ada_Dotted_Name then
            declare
               Parent_Unit : constant Libadalang.Analysis.Basic_Decl :=
                 Unit_Name.As_Dotted_Name.F_Prefix.P_Referenced_Decl;
            begin
               Scan_Package (Parent_Unit, Enclosing);
               if not Found then
                  Scan_Unit (Parent_Unit.P_Enclosing_Compilation_Unit);
               end if;
            end;
         end if;
      exception
         when others =>
            Found := True;
      end Scan_Unit;

      Node : Libadalang.Analysis.Ada_Node := Instance.Parent;
   begin
      if Wanted_Type = ""
        or else Typ.Kind = Libadalang.Common.Ada_Anonymous_Type_Decl
      then
         return True;
      end if;
      while not Found and then not Libadalang.Analysis.Is_Null (Node) loop
         case Node.Kind is
            when Libadalang.Common.Ada_Declarative_Part_Range =>
               Scan_List (Node.As_Declarative_Part.F_Decls, Enclosing);
            when Libadalang.Common.Ada_Base_Package_Decl
               | Libadalang.Common.Ada_Generic_Package_Decl =>
               Scan_Package (Node.As_Basic_Decl, Enclosing);
            when Libadalang.Common.Ada_Generic_Subp_Decl =>
               Scan_List
                 (Node.As_Generic_Decl.F_Formal_Part.F_Decls, Enclosing);
            when Libadalang.Common.Ada_Package_Body =>
               Scan_Package (Node.As_Package_Body.P_Decl_Part, Enclosing);
            when Libadalang.Common.Ada_Base_Subp_Body =>
               --  The subprogram itself, and the formals of its generic
               --  declaration.
               Check (Node.As_Basic_Decl, Enclosing);
               declare
                  Spec : constant Libadalang.Analysis.Basic_Decl :=
                    Node.As_Base_Subp_Body.P_Decl_Part;
               begin
                  if not Libadalang.Analysis.Is_Null (Spec)
                    and then not Libadalang.Analysis.Is_Null (Spec.Parent)
                    and then Spec.Parent.Kind =
                             Libadalang.Common.Ada_Generic_Subp_Decl
                  then
                     Scan_List
                       (Spec.Parent.As_Generic_Decl.F_Formal_Part.F_Decls,
                        Enclosing);
                  end if;
               end;
            when Libadalang.Common.Ada_Task_Body
               | Libadalang.Common.Ada_Protected_Body
               | Libadalang.Common.Ada_Entry_Body
               | Libadalang.Common.Ada_Task_Type_Decl
               | Libadalang.Common.Ada_Single_Task_Decl
               | Libadalang.Common.Ada_Protected_Type_Decl
               | Libadalang.Common.Ada_Single_Protected_Decl =>
               Found := True;
            when Libadalang.Common.Ada_Compilation_Unit =>
               Scan_Unit (Node.As_Compilation_Unit);
               exit;
            when others =>
               null;
         end case;
         Node := Node.Parent;
      end loop;
      return Found;
   exception
      when others =>
         return True;
   end Other_Homograph;

   procedure Resolve_Box
     (Instance   : Libadalang.Analysis.Generic_Instantiation'Class;
      Formal     : Libadalang.Analysis.Basic_Decl'Class;
      Decl       : out Libadalang.Analysis.Basic_Decl;
      Predefined : out Boolean)
   is
      Spec  : Libadalang.Analysis.Subp_Spec;
      Name  : Unbounded_String;
      Arity : Natural := 0;
      First : Libadalang.Analysis.Base_Type_Decl;
      Found : Natural := 0;
   begin
      Decl := Libadalang.Analysis.No_Basic_Decl;
      Predefined := False;
      if Formal.Kind not in Libadalang.Common.Ada_Formal_Subp_Decl
        or else Libadalang.Analysis.Is_Null
                  (Formal.As_Formal_Subp_Decl.F_Default_Expr)
        or else Formal.As_Formal_Subp_Decl.F_Default_Expr.Kind /=
                Libadalang.Common.Ada_Box_Expr
      then
         return;
      end if;
      Spec := Formal.As_Formal_Subp_Decl.F_Subp_Spec;
      Name := To_Unbounded_String
        (Normalize_Rule_Name (Node_Text (Formal.P_Defining_Name)));
      if Libadalang.Analysis.Is_Null (Spec.F_Subp_Params) then
         return;
      end if;
      for Param of Spec.F_Subp_Params.F_Params loop
         Arity := Arity + Param.F_Ids.Children_Count;
         if Libadalang.Analysis.Is_Null (First) then
            First := Param.F_Type_Expr.P_Designated_Type_Decl;
         end if;
      end loop;
      if Libadalang.Analysis.Is_Null (First) then
         return;
      end if;

      --  A formal type of the unit, or of a unit it is nested in: its
      --  actual in Instance, or in the instance its name is given through.
      if First.Kind = Libadalang.Common.Ada_Formal_Type_Decl then
         declare
            Wanted : constant String :=
              First.P_Defining_Name.Unit.Get_Filename & ":" &
              Langkit_Support.Slocs.Image (First.P_Defining_Name.Sloc_Range);
            Given  : Libadalang.Analysis.Base_Type_Decl;
            Where  : Libadalang.Analysis.Generic_Instantiation :=
              Instance.As_Generic_Instantiation;
         begin
            for Level in 1 .. 4 loop
               for Pair of Where.P_Inst_Params loop
                  declare
                     Formal_Name : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Param (Pair).As_Ada_Node;
                     Actual      : constant Libadalang.Analysis.Ada_Node :=
                       Libadalang.Analysis.Actual (Pair).As_Ada_Node;
                     Place       : constant String :=
                       Formal_Name.Unit.Get_Filename & ":" &
                       Langkit_Support.Slocs.Image (Formal_Name.Sloc_Range);
                  begin
                     if Place = Wanted
                       and then not Libadalang.Analysis.Is_Null (Actual)
                       and then Actual.Kind in Libadalang.Common.Ada_Name
                     then
                        declare
                           Target : constant Libadalang.Analysis.Basic_Decl :=
                             Actual.As_Name.P_Referenced_Decl;
                        begin
                           if not Libadalang.Analysis.Is_Null (Target)
                             and then Target.Kind in
                               Libadalang.Common.Ada_Base_Type_Decl
                           then
                              Given := Target.As_Base_Type_Decl;
                           end if;
                        end;
                     end if;
                  end;
               end loop;
               exit when not Libadalang.Analysis.Is_Null (Given);
               --  Prefix.G, Prefix an instance of the unit G is nested in.
               declare
                  Name : constant Libadalang.Analysis.Name :=
                    (if Where.Kind =
                          Libadalang.Common.Ada_Generic_Package_Instantiation
                     then Where.As_Generic_Package_Instantiation
                            .F_Generic_Pkg_Name
                     else Where.As_Generic_Subp_Instantiation
                            .F_Generic_Subp_Name);
                  Outer : Libadalang.Analysis.Basic_Decl;
               begin
                  exit when Name.Kind /= Libadalang.Common.Ada_Dotted_Name;
                  Outer := Name.As_Dotted_Name.F_Prefix.P_Referenced_Decl;
                  exit when Libadalang.Analysis.Is_Null (Outer)
                    or else Outer.Kind not in
                      Libadalang.Common.Ada_Generic_Instantiation;
                  Where := Outer.As_Generic_Instantiation;
               end;
            end loop;
            if Libadalang.Analysis.Is_Null (Given)
              or else Given.Kind = Libadalang.Common.Ada_Formal_Type_Decl
            then
               return;
            end if;
            First := Given;
            if First.Kind = Libadalang.Common.Ada_Subtype_Decl then
               First := First.P_Base_Subtype;
            end if;
         end;
      end if;

      for Prim of First.P_Get_Primitives loop
         declare
            Count     : Natural := 0;
            Prim_Spec : constant Libadalang.Analysis.Base_Subp_Spec :=
              Prim.P_Subp_Spec_Or_Null;
         begin
            if Normalize_Rule_Name (Node_Text (Prim.P_Defining_Name)) =
                 To_String (Name)
              and then not Libadalang.Analysis.Is_Null (Prim_Spec)
            then
               for Param of Prim_Spec.P_Params loop
                  Count := Count + Param.F_Ids.Children_Count;
               end loop;
               if Count = Arity then
                  Found := Found + 1;
                  Decl := Prim;
               end if;
            end if;
         end;
      end loop;
      if Found /= 1 then
         Decl := Libadalang.Analysis.No_Basic_Decl;
      end if;
      if Found = 0 then
         declare
            Op : constant String := To_String (Name);
         begin
            if Op = """=""" or else Op = """/=""" then
               Predefined := not First.P_Is_Limited_Type
                 and then Plain_Equality (First, 0);
            elsif Op = """<""" or else Op = """<=""" or else Op = """>"""
              or else Op = """>="""
            then
               Predefined := First.P_Is_Scalar_Type
                 or else (First.P_Is_Array_Type
                          and then First.P_Comp_Type.P_Is_Discrete_Type);
            end if;
         end;
      end if;

      --  Another subprogram of the name could be the one visible.
      if (Predefined or else not Libadalang.Analysis.Is_Null (Decl))
        and then Other_Homograph
                   (Instance, To_String (Name), Arity, First, Decl)
      then
         Decl := Libadalang.Analysis.No_Basic_Decl;
         Predefined := False;
      end if;
   exception
      when others =>
         Decl := Libadalang.Analysis.No_Basic_Decl;
         Predefined := False;
   end Resolve_Box;

   function Formal_Verdict
     (Formal : Libadalang.Analysis.Basic_Decl'Class;
      Depth  : Natural) return Verdict
   is
      Max_Depth : constant := 8;
      Name      : constant String := Display_Name (Formal);
      Key       : constant String :=
        Subprogram_Summaries.Generic_Unit_Key (Formal);
      Wanted    : constant Libadalang.Analysis.Defining_Name :=
        Formal.P_Defining_Name;
      Found     : Boolean := False;
      Lost      : Boolean := False;
      Result    : Verdict := Shown;

      function Same
        (Left, Right : Libadalang.Analysis.Ada_Node'Class) return Boolean
      is
         Left_Place  : constant String :=
           Left.Unit.Get_Filename & ":" &
           Langkit_Support.Slocs.Image (Left.Sloc_Range);
         Right_Place : constant String :=
           Right.Unit.Get_Filename & ":" &
           Langkit_Support.Slocs.Image (Right.Sloc_Range);
      begin
         return Left_Place = Right_Place;
      end Same;

      procedure Visit (Instance : Libadalang.Analysis.Generic_Instantiation)
      is
         Default : constant Libadalang.Analysis.Expr :=
           Formal.As_Formal_Subp_Decl.F_Default_Expr;
         Actual  : Libadalang.Analysis.Expr;
         Given   : Verdict;
      begin
         if Result.Kind /= Terminates then
            return;
         end if;
         Found := True;
         for Pair of Instance.P_Inst_Params loop
            if Same (Libadalang.Analysis.Param (Pair), Wanted) then
               Actual := Libadalang.Analysis.Actual (Pair).As_Expr;
            end if;
         end loop;
         if not Given_In (Instance, Actual) then
            --  None is written: the default.
            Actual := Default;
         end if;
         if Libadalang.Analysis.Is_Null (Actual) then
            Given := No ("no subprogram is given to " & Name);
         elsif Actual.Kind = Libadalang.Common.Ada_Box_Expr then
            declare
               Decl       : Libadalang.Analysis.Basic_Decl;
               Predefined : Boolean;
            begin
               Resolve_Box (Instance, Formal, Decl, Predefined);
               if Predefined then
                  Given := Shown;
               elsif Libadalang.Analysis.Is_Null (Decl) then
                  Given := No ("the subprogram " & Name &
                               " takes by <> was not found");
               else
                  Given := Callee_Verdict (Decl, Depth + 1);
               end if;
            end;
         elsif Actual.Kind = Libadalang.Common.Ada_Null_Literal then
            Given := Shown;
         elsif Actual.Kind in Libadalang.Common.Ada_Name
           and then Actual.Kind /= Libadalang.Common.Ada_Attribute_Ref
         then
            Given := Callee_Verdict
              (Actual.As_Name.P_Referenced_Decl, Depth + 1);
         else
            Given := No ("the subprogram given to " & Name &
                         " is not named");
         end if;
         if Given.Kind /= Terminates then
            Result := No
              ("the actual of " & Name & " in the instantiation at " &
               Langkit_Support.Slocs.Image
                 (Langkit_Support.Slocs.Start_Sloc (Instance.Sloc_Range)) &
               " is not shown to return" &
               (if Given.Kind = Not_Shown
                then ": " & To_String (Given.Reason) else ""));
         end if;
      exception
         when others =>
            Result := No ("the actual of " & Name & " was not resolved");
      end Visit;
   begin
      if Depth > Max_Depth or else Key = "" then
         return No (Name & " is a generic formal subprogram, whose actual " &
                    "is not known here");
      end if;
      Subprogram_Summaries.For_Each_Instantiation
        (Key, Formal, Visit'Access, Lost);
      if Result.Kind /= Terminates then
         return Result;
      elsif not Found or else Lost then
         return No (Name & " is a generic formal subprogram not given a " &
                    "subprogram by an instantiation in this run");
      end if;
      return Shown;
   exception
      when others =>
         return No (Name & " is a generic formal subprogram, whose actual " &
                    "is not known here");
   end Formal_Verdict;

   --  True when SPARK requires Subprogram to terminate: a function, or a
   --  procedure that has the aspect Always_Terminates or is declared in a
   --  package that has it, unless the aspect is given as False, or in a
   --  generic package instantiated in such a package.
   function Must_Terminate
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class) return Boolean
   is
      Ancestor : Libadalang.Analysis.Ada_Node := Subprogram.Parent;
   begin
      if Is_Function (Subprogram.F_Subp_Spec) or else Says_Terminates (Subprogram)
      then
         return True;
      end if;

      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         if Ancestor.Kind in Libadalang.Common.Ada_Package_Body
              | Libadalang.Common.Ada_Package_Decl
              | Libadalang.Common.Ada_Generic_Package_Internal
           and then Says_Terminates (Ancestor.As_Basic_Decl)
         then
            return True;
         end if;
         Ancestor := Ancestor.Parent;
      end loop;
      return Context_Terminates (Subprogram, 0);
   exception
      when others =>
         return False;
   end Must_Terminate;

   --  Raises the termination obligation of Subprogram when SPARK requires
   --  it to terminate.
   procedure Verify_Subprogram
     (Unit       : Libadalang.Analysis.Analysis_Unit;
      Subprogram : Libadalang.Analysis.Base_Subp_Body'Class)
   is
      --  The name in the first declaration, where a caller reads it.
      First  : constant Libadalang.Analysis.Basic_Decl :=
        Subprogram.P_Canonical_Part;
      Anchor : constant Libadalang.Analysis.Defining_Name :=
        (if Libadalang.Analysis.Is_Null (First)
         then Subprogram.P_Defining_Name
         else First.P_Defining_Name);
   begin
      if not Must_Terminate (Subprogram)
        or else not SPARK_Readiness.Effective_SPARK_Enabled (Subprogram)
      then
         return;
      end if;

      declare
         Result : constant Verdict := Body_Verdict (Subprogram);
      begin
         if Result.Kind = Terminates then
            Proof.Register_At
              (Unit             => Unit,
               Node             => Anchor,
               Kind             => Proof.Termination_Check,
               Status           => Proof.Proved_Safe,
               Method           => Proof.Flow_Analysis,
               Abstract_State   =>
                 "no unbounded loop, no recursion, every callee terminates",
               Explanation      =>
                 "the subprogram returns: its loops are bounded, it is " &
                 "not recursive and what it calls returns",
               Configuration_Id => Assurance_Profile_Name,
               Final            => True);
         else
            Proof.Register_At
              (Unit               => Unit,
               Node               => Anchor,
               Kind               => Proof.Termination_Check,
               Status             => Proof.Unproved,
               Method             => Proof.Flow_Analysis,
               Explanation        =>
                 "the subprogram is not shown to return",
               Imprecision_Source =>
                 (if Result.Kind = Not_Shown then To_String (Result.Reason)
                  else "recursion"),
               Configuration_Id   => Assurance_Profile_Name,
               Final              => True);
         end if;
      end;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("termination not checked for a subprogram: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Verify_Subprogram;

   --  A generic formal procedure with a null default, in a generic package
   --  that must terminate: GNATprove checks the termination of the null
   --  procedure an instantiation takes, which returns.
   procedure Verify_Formal
     (Unit   : Libadalang.Analysis.Analysis_Unit;
      Formal : Libadalang.Analysis.Formal_Subp_Decl'Class)
   is
      Default : constant Libadalang.Analysis.Expr := Formal.F_Default_Expr;
      Key     : constant String :=
        Subprogram_Summaries.Generic_Unit_Key (Formal);
      Wanted  : constant String :=
        Langkit_Support.Slocs.Image (Formal.P_Defining_Name.Sloc_Range);
      Taken   : Boolean := False;
      Lost    : Boolean;
      Gen     : Libadalang.Analysis.Ada_Node := Formal.Parent;

      procedure Visit (Instance : Libadalang.Analysis.Generic_Instantiation)
      is
         Named : Boolean := False;
      begin
         for Pair of Instance.P_Inst_Params loop
            if Langkit_Support.Slocs.Image
                 (Libadalang.Analysis.Param (Pair).Sloc_Range) = Wanted
              and then Libadalang.Analysis.Param (Pair).Unit.Get_Filename =
                       Formal.Unit.Get_Filename
            then
               Named := True;
               declare
                  Actual : constant Libadalang.Analysis.Ada_Node :=
                    Libadalang.Analysis.Actual (Pair).As_Ada_Node;
               begin
                  if Libadalang.Analysis.Is_Null (Actual)
                    or else Actual.Kind = Libadalang.Common.Ada_Null_Literal
                  then
                     Taken := True;
                  end if;
               end;
            end if;
         end loop;
         if not Named then
            Taken := True;
         end if;
      exception
         when Exc : others =>
            Log_Verbose_Once
              ("an instantiation was not matched with a formal subprogram: " &
               Ada.Exceptions.Exception_Message (Exc));
      end Visit;
   begin
      if Libadalang.Analysis.Is_Null (Default)
        or else Default.Kind /= Libadalang.Common.Ada_Null_Literal
        or else Is_Function (Formal.F_Subp_Spec)
        or else Key = ""
      then
         return;
      end if;
      while not Libadalang.Analysis.Is_Null (Gen)
        and then Gen.Kind /= Libadalang.Common.Ada_Generic_Package_Decl
      loop
         Gen := Gen.Parent;
      end loop;
      if Libadalang.Analysis.Is_Null (Gen)
        or else not SPARK_Readiness.Effective_SPARK_Enabled
                      (Gen.As_Basic_Decl)
      then
         return;
      end if;
      declare
         Inner : constant Libadalang.Analysis.Generic_Package_Internal :=
           Gen.As_Generic_Package_Decl.F_Package_Decl;
      begin
         if not Says_Terminates (Inner)
           and then not Context_Terminates (Inner.F_Public_Part, 0)
         then
            return;
         end if;
      end;
      Subprogram_Summaries.For_Each_Instantiation
        (Key, Formal, Visit'Access, Lost);
      if Taken then
         Proof.Register_At
           (Unit             => Unit,
            Node             => Formal.P_Defining_Name,
            Kind             => Proof.Termination_Check,
            Status           => Proof.Proved_Safe,
            Method           => Proof.Flow_Analysis,
            Abstract_State   => "the null procedure of the default",
            Explanation      =>
              "an instantiation takes the null default, which returns",
            Configuration_Id => Assurance_Profile_Name,
            Final            => True);
      end if;
   exception
      when Exc : others =>
         Log_Verbose_Once
           ("termination not checked for a formal subprogram: " &
            Ada.Exceptions.Exception_Message (Exc));
   end Verify_Formal;

   procedure Verify_Unit (Unit : Libadalang.Analysis.Analysis_Unit) is
      --  Every body in the unit, at any depth: a nested function has the
      --  obligation as well.
      procedure Visit (Node : Libadalang.Analysis.Ada_Node'Class) is
      begin
         for Index in 1 .. Node.Children_Count loop
            declare
               Child : constant Libadalang.Analysis.Ada_Node :=
                 Node.Child (Index);
            begin
               if not Libadalang.Analysis.Is_Null (Child) then
                  if Child.Kind in Libadalang.Common.Ada_Subp_Body
                       | Libadalang.Common.Ada_Expr_Function
                  then
                     Verify_Subprogram (Unit, Child.As_Base_Subp_Body);
                  elsif Child.Kind in Libadalang.Common.Ada_Formal_Subp_Decl
                  then
                     Verify_Formal (Unit, Child.As_Formal_Subp_Decl);
                  end if;
                  Visit (Child);
               end if;
            end;
         end loop;
      end Visit;
   begin
      if not Libadalang.Analysis.Is_Null (Unit.Root) then
         Visit (Unit.Root);
      end if;
   end Verify_Unit;

end Adalang_Analyzer.Termination;
