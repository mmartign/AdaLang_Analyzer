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

with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;    use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Config;      use Adalang_Analyzer.Config;
with Adalang_Analyzer.Proof_Obligations;
with Adalang_Analyzer.SPARK_Readiness;
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
            return No
              (Name & " is a generic formal subprogram, whose actual is " &
               "not known here");

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

   --  True when SPARK requires Subprogram to terminate: a function, or a
   --  procedure that has the aspect Always_Terminates or is declared in a
   --  package that has it, unless the aspect is given as False.
   function Must_Terminate
     (Subprogram : Libadalang.Analysis.Base_Subp_Body'Class) return Boolean
   is
      function Says_So
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
      end Says_So;

      Ancestor : Libadalang.Analysis.Ada_Node := Subprogram.Parent;
   begin
      if Is_Function (Subprogram.F_Subp_Spec) or else Says_So (Subprogram)
      then
         return True;
      end if;

      while not Libadalang.Analysis.Is_Null (Ancestor) loop
         if Ancestor.Kind in Libadalang.Common.Ada_Package_Body
              | Libadalang.Common.Ada_Package_Decl
              | Libadalang.Common.Ada_Generic_Package_Internal
           and then Says_So (Ancestor.As_Basic_Decl)
         then
            return True;
         end if;
         Ancestor := Ancestor.Parent;
      end loop;
      return False;
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
