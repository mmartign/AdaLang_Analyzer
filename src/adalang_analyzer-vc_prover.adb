--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Flow_Eval;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.VC_Prover is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Adalang_Analyzer.Flow_Domain.Abstract_Bool;
   use type Ada.Containers.Count_Type;
   use type GNAT.OS_Lib.File_Descriptor;
   use type GNAT.OS_Lib.String_Access;

   package Domain renames Adalang_Analyzer.Flow_Domain;
   package Eval renames Adalang_Analyzer.Flow_Eval;

   type Translation_Context is record
      State     : Domain.Flow_State;
      Symbols   : Symbolic_State := Empty_Symbolic_State;
      Supported : Boolean := True;
   end record;

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

   function Root_Name
     (Key    : Libadalang.Analysis.Ada_Node;
      Prefix : String := "b") return String
   is
     (Prefix & Natural_Image (Natural (Key.Sloc_Range.Start_Line)) & "_" &
        Natural_Image (Natural (Key.Sloc_Range.Start_Column)));

   function Binding_Index
     (State : Symbolic_State;
      Key   : Libadalang.Analysis.Ada_Node) return Natural
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
     (State  : in out Symbolic_State;
      Name   : String;
      Key    : Libadalang.Analysis.Ada_Node;
      Sort   : Scalar_Sort;
      Flow   : Domain.Flow_State)
   is
      Range_Value : constant Domain.Abstract_Range :=
        Domain.Flow_Range_Lookup (Flow, Key);
   begin
      if Root_Index (State, Name) /= 0 then
         return;
      end if;

      State.Roots.Append
        ((Name     => To_Unbounded_String (Name),
          Key      => Key,
          Sort     => Sort,
          Has_Low  => Sort = Integer_Sort and then Range_Value.Has_Low,
          Low      => Range_Value.Low,
          Has_High => Sort = Integer_Sort and then Range_Value.Has_High,
          High     => Range_Value.High));
   end Add_Root;

   function Symbol_For
     (Context : in out Translation_Context;
      Key     : Libadalang.Analysis.Ada_Node;
      Sort    : Scalar_Sort) return String
   is
      Binding : constant Natural := Binding_Index (Context.Symbols, Key);
   begin
      if Libadalang.Analysis.Is_Null (Key) then
         Context.Supported := False;
         return "";
      elsif Binding /= 0 then
         if Context.Symbols.Bindings.Element (Binding).Sort /= Sort then
            Context.Supported := False;
            return "";
         end if;
         return To_String (Context.Symbols.Bindings.Element (Binding).Term);
      end if;

      declare
         Name : constant String := Root_Name (Key);
      begin
         Add_Root (Context.Symbols, Name, Key, Sort, Context.State);
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

   function Integer_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String;

   function Boolean_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String;

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
         Context.Supported := False;
         return Null_Unbounded_String;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Int_Literal =>
            declare
               Value : constant Domain.Abstract_Int := Eval.Integer_Value (Node);
            begin
               if not Value.Known then
                  Context.Supported := False;
                  return Null_Unbounded_String;
               end if;
               return To_Unbounded_String (SMT_Integer (Value.Value));
            end;

         when Libadalang.Common.Ada_Identifier =>
            declare
               Key   : constant Libadalang.Analysis.Ada_Node :=
                 Referenced_Key (Node);
               Value : constant Domain.Abstract_Int :=
                 Domain.Flow_Lookup (Context.State, Key);
               Bool_Value : constant Domain.Abstract_Bool :=
                 Domain.Flow_Bool_Lookup (Context.State, Key);
            begin
               if Domain.Flow_Initialization (Context.State, Key) /=
                 Domain.Bool_True
                 or else Bool_Value /= Domain.Bool_Unknown
               then
                  Context.Supported := False;
                  return Null_Unbounded_String;
               elsif Value.Known then
                  return To_Unbounded_String (SMT_Integer (Value.Value));
               else
                  return To_Unbounded_String
                    (Symbol_For (Context, Key, Integer_Sort));
               end if;
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
                     return To_Unbounded_String
                       ("(ite (>= " & To_String (Item) & " 0) " &
                          To_String (Item) & " (- " & To_String (Item) & "))");
                  when others =>
                     Context.Supported := False;
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
                  when others =>
                     --  Ada division/remainder and exponentiation are not
                     --  mapped to SMT until their exact language semantics
                     --  and run-time checks are encoded.
                     Context.Supported := False;
                     return Null_Unbounded_String;
               end case;
            end;

         when others =>
            Context.Supported := False;
            return Null_Unbounded_String;
      end case;
   exception
      when others =>
         Context.Supported := False;
         return Null_Unbounded_String;
   end Integer_Term;

   function Boolean_Term
     (Node    : Libadalang.Analysis.Ada_Node'Class;
      Context : in out Translation_Context) return Unbounded_String
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         Context.Supported := False;
         return Null_Unbounded_String;
      end if;

      if Node.Kind = Libadalang.Common.Ada_Identifier then
         declare
            Text : constant String :=
              Adalang_Analyzer.Text_Utils.Normalize_Rule_Name
                (Adalang_Analyzer.Ada_Text.Node_Text (Node));
            Key : Libadalang.Analysis.Ada_Node;
            Value : Domain.Abstract_Bool;
         begin
            if Text = "true" or else Text = "false" then
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
               Context.Supported := False;
               return Null_Unbounded_String;
            elsif Value = Domain.Bool_True then
               return To_Unbounded_String ("true");
            elsif Value = Domain.Bool_False then
               return To_Unbounded_String ("false");
            else
               return To_Unbounded_String
                 (Symbol_For (Context, Key, Boolean_Sort));
            end if;
         end;
      elsif Node.Kind = Libadalang.Common.Ada_Paren_Expr then
         return Boolean_Term (Node.As_Paren_Expr.F_Expr, Context);
      elsif Node.Kind = Libadalang.Common.Ada_Un_Op then
         declare
            Expr : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
         begin
            if Expr.F_Op = Libadalang.Common.Ada_Op_Not then
               return To_Unbounded_String
                 ("(not " & To_String
                    (Boolean_Term (Expr.F_Expr, Context)) & ")");
            end if;
            Context.Supported := False;
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
                  Context.Supported := False;
                  return Null_Unbounded_String;
            end case;
         end;
      end if;

      Context.Supported := False;
      return Null_Unbounded_String;
   exception
      when others =>
         Context.Supported := False;
         return Null_Unbounded_String;
   end Boolean_Term;

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
      Boolean_Context : Translation_Context :=
        (State => Flow, Symbols => State, Supported => State.Supported);
      Boolean_Value : constant Unbounded_String :=
        Boolean_Term (Value, Boolean_Context);
   begin
      if Libadalang.Analysis.Is_Null (Destination)
        or else Libadalang.Analysis.Is_Null (Value)
      then
         return Havoc;
      elsif Boolean_Context.Supported and then Length (Boolean_Value) > 0 then
         Set_Binding
           (Boolean_Context.Symbols,
            (Key => Destination, Sort => Boolean_Sort, Term => Boolean_Value));
         return Boolean_Context.Symbols;
      end if;

      declare
         Integer_Context : Translation_Context :=
           (State => Flow, Symbols => State, Supported => State.Supported);
         Integer_Value : constant Unbounded_String :=
           Integer_Term (Value, Integer_Context);
      begin
         if not Integer_Context.Supported or else Length (Integer_Value) = 0
         then
            return Havoc;
         end if;
         Set_Binding
           (Integer_Context.Symbols,
            (Key => Destination, Sort => Integer_Sort, Term => Integer_Value));
         return Integer_Context.Symbols;
      end;
   exception
      when others =>
         return Havoc;
   end Assign;

   function Assume
     (State     : Symbolic_State;
      Condition : Libadalang.Analysis.Expr;
      Truth     : Boolean;
      Flow      : Domain.Flow_State) return Symbolic_State
   is
      Context : Translation_Context :=
        (State => Flow, Symbols => State, Supported => State.Supported);
      Term : constant Unbounded_String := Boolean_Term (Condition, Context);
   begin
      if not Context.Supported or else Length (Term) = 0 then
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
        (Key : Libadalang.Analysis.Ada_Node) return Natural is
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
            Set_Binding (Result, Item);
         else
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
                 (if Item.Sort = Integer_Sort then "Int" else "Bool") &
                 ")" & ASCII.LF);
            if Item.Sort = Integer_Sort then
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
      Deleted    : Boolean;
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
            GNAT.OS_Lib.Free (Input_Name);
         end if;
         return Solver_Unknown;
   end Query;

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Domain.Flow_State) return VC_Result
   is
   begin
      return Decide (Condition, State, Empty_Symbolic_State);
   end Decide;

   function Decide
     (Condition : Libadalang.Analysis.Expr;
      State     : Domain.Flow_State;
      Symbols   : Symbolic_State) return VC_Result
   is
      Context : Translation_Context :=
        (State => State, Symbols => Symbols, Supported => Symbols.Supported);
      Goal    : constant Unbounded_String :=
        Boolean_Term (Condition, Context);
      Formula : Unbounded_String;
      Negated : Solver_Answer;
      Direct  : Solver_Answer;
   begin
      if not Context.Supported or else Length (Goal) = 0 then
         return VC_Unsupported;
      end if;

      Formula := Constraints (Context);
      Append
        (Formula,
         "(define-fun goal () Bool " & To_String (Goal) & ")" & ASCII.LF);
      Negated := Query (To_String (Formula), Negate => True);
      if Negated = Solver_Unavailable then
         return VC_Unavailable;
      elsif Negated = Solver_Unsat then
         return VC_Proved;
      end if;

      Direct := Query (To_String (Formula), Negate => False);
      if Direct = Solver_Unavailable then
         return VC_Unavailable;
      elsif Direct = Solver_Unsat then
         return VC_Refuted;
      else
         return VC_Unknown;
      end if;
   exception
      when others =>
         return VC_Unknown;
   end Decide;

   function Evidence return String is
     ("SMT-LIB scalar VC; CVC5 and Z3 agreement required");

end Adalang_Analyzer.VC_Prover;
