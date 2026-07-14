--
--  Copyright (C) 2024, AdaCore
--
--  SPDX-License-Identifier: GPL-3.0-or-later
--

with Ada.Command_Line;
with Ada.Characters.Latin_1;
with Ada.Containers.Indefinite_Vectors;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings;

with Libadalang.Analysis;
with Libadalang.Common;
with Langkit_Support.Text;

procedure Adalang_Analyzer is
   use Ada.Strings.Unbounded;
   use type Libadalang.Common.Ada_Node_Kind_Type;

   type Rule_State is (Disabled, Enabled);

   type Rule_Kind is (
      No_Goto,
      No_Abort,
      No_Raise,
      No_Exit,
      No_Label,
      No_Pragma,
      No_Access_To_Subp_Def,
      Constant_Condition,
      Unreachable_Code,
      Division_By_Zero,
      Reversed_Range,
      Self_Assignment,
      Same_Operand,
      Duplicate_Condition,
      Null_Statement,
      Empty_Exception_Handler,
      Unreachable_Branch,
      Contradictory_Condition,
      Identical_Branches,
      Repeated_Statement,
      Ineffective_Operation,
      Constant_Result_Operation,
      Empty_Loop
   );

   type Rule_Info is record
      Name        : Ada.Strings.Unbounded.Unbounded_String;
      Description : Ada.Strings.Unbounded.Unbounded_String;
      Guidance    : Ada.Strings.Unbounded.Unbounded_String;
   end record;

   type Rule_Info_Array is array (Rule_Kind) of Rule_Info;
   Rule_Infos : constant Rule_Info_Array := ( --
      No_Goto =>
        (Name        => To_Unbounded_String ("No_Goto"),
         Description => To_Unbounded_String
           ("Avoid goto statements because they make control flow " &
            "difficult to follow and verify."),
         Guidance    => To_Unbounded_String
           ("Replace the jump with structured control flow such as a " &
            "loop condition, if statement, return, or a small local " &
            "subprogram.")),
      No_Abort =>
        (Name        => To_Unbounded_String ("No_Abort"),
         Description => To_Unbounded_String
           ("Avoid abort statements because asynchronous task termination " &
            "can leave shared state and cleanup paths unclear."),
         Guidance    => To_Unbounded_String
           ("Prefer cooperative cancellation, protected objects, or an " &
            "explicit task shutdown protocol.")),
      No_Raise =>
        (Name        => To_Unbounded_String ("No_Raise"),
         Description => To_Unbounded_String
           ("Avoid explicit raise statements when the code base expects " &
            "errors to be handled through regular control flow."),
         Guidance    => To_Unbounded_String
           ("Return a status/result value where possible, or centralize " &
            "exception raising at a documented boundary.")),
      No_Exit =>
        (Name        => To_Unbounded_String ("No_Exit"),
         Description => To_Unbounded_String
           ("Avoid exit statements that make loop termination depend on " &
            "hidden branches inside the loop body."),
         Guidance    => To_Unbounded_String
           ("Move the termination condition into the loop condition or " &
            "split the loop so the exit case is explicit.")),
      No_Label =>
        (Name        => To_Unbounded_String ("No_Label"),
         Description => To_Unbounded_String
           ("Avoid labels because they are normally only needed to support " &
            "unstructured jumps."),
         Guidance    => To_Unbounded_String
           ("Remove the label or replace the surrounding flow with " &
            "structured statements.")), --
      No_Pragma =>
        (Name        => To_Unbounded_String ("No_Pragma"),
         Description => To_Unbounded_String
           ("Avoid pragmas that may change compiler behavior, runtime " &
            "behavior, portability, or verification assumptions."),
         Guidance    => To_Unbounded_String
           ("Keep only required pragmas, document the reason, and isolate " &
            "compiler-specific pragmas behind project policy.")),
      No_Access_To_Subp_Def =>
        (Name        => To_Unbounded_String ("No_Access_To_Subp_Def"),
         Description => To_Unbounded_String
           ("Avoid access-to-subprogram type definitions because indirect " &
            "calls make call relationships harder to analyze."),
         Guidance    => To_Unbounded_String
           ("Prefer explicit subprogram parameters, generics, or a small " &
            "dispatching abstraction with a clear ownership boundary.")),
      Constant_Condition =>
        (Name        => To_Unbounded_String ("Constant_Condition"),
         Description => To_Unbounded_String
           ("Find conditions that are statically known to be always true " &
            "or always false."),
         Guidance    => To_Unbounded_String
           ("Remove dead branches, simplify the condition, or replace " &
            "temporary debug logic with an explicit configuration guard.")),
      Unreachable_Code =>
        (Name        => To_Unbounded_String ("Unreachable_Code"),
         Description => To_Unbounded_String
           ("Find statements that cannot execute after an unconditional " &
            "return, raise, goto, or loop exit in the same statement list."),
         Guidance    => To_Unbounded_String
           ("Move the statement before the terminating statement, remove it, " &
            "or make the terminating statement conditional.")),
      Division_By_Zero =>
        (Name        => To_Unbounded_String ("Division_By_Zero"),
         Description => To_Unbounded_String
           ("Find division, mod, and rem operations whose right operand is " &
            "statically zero."),
         Guidance    => To_Unbounded_String
           ("Guard the operation, change the divisor, or make the exceptional " &
            "case explicit before evaluating the operation.")),
      Reversed_Range =>
        (Name        => To_Unbounded_String ("Reversed_Range"),
         Description => To_Unbounded_String
           ("Find static ranges whose lower bound is greater than their " &
            "upper bound."),
         Guidance    => To_Unbounded_String
           ("Swap the bounds, use a reverse iteration form, or document an " &
            "intentional null range with a clearer condition.")),
      Self_Assignment =>
        (Name        => To_Unbounded_String ("Self_Assignment"),
         Description => To_Unbounded_String
           ("Find assignments where the target and value are the same " &
            "syntactic expression."),
         Guidance    => To_Unbounded_String
           ("Remove the assignment or replace the right-hand side with the " &
            "value that was intended to update the object.")),
      Same_Operand =>
        (Name        => To_Unbounded_String ("Same_Operand"),
         Description => To_Unbounded_String
           ("Find suspicious binary expressions that use the same expression " &
            "on both sides."),
         Guidance    => To_Unbounded_String
           ("Check for a copied operand, simplify the expression, or add an " &
            "explicit comment if the repetition is intentional.")),
      Duplicate_Condition =>
        (Name        => To_Unbounded_String ("Duplicate_Condition"),
         Description => To_Unbounded_String
           ("Find repeated conditions in the same if/elsif chain."),
         Guidance    => To_Unbounded_String
           ("Replace the repeated condition with the missing case or remove " &
            "the unreachable branch.")),
      Null_Statement =>
        (Name        => To_Unbounded_String ("Null_Statement"),
         Description => To_Unbounded_String
           ("Find null statements in executable code."),
         Guidance    => To_Unbounded_String
           ("Remove the placeholder or replace it with explicit handling so " &
            "the empty action is intentional.")),
      Empty_Exception_Handler =>
        (Name        => To_Unbounded_String ("Empty_Exception_Handler"),
         Description => To_Unbounded_String
           ("Find exception handlers that only contain null statements or " &
            "pragmas."),
         Guidance    => To_Unbounded_String
           ("Handle, log, re-raise, or narrowly document the exception instead " &
            "of silently swallowing it.")),
      Unreachable_Branch =>
        (Name        => To_Unbounded_String ("Unreachable_Branch"),
         Description => To_Unbounded_String
           ("Find if/elsif/else branches made unreachable by static " &
            "conditions earlier in the chain."),
         Guidance    => To_Unbounded_String
           ("Remove the branch or change the condition sequence so each branch " &
            "can be selected.")),
      Contradictory_Condition =>
        (Name        => To_Unbounded_String ("Contradictory_Condition"),
         Description => To_Unbounded_String
           ("Find boolean expressions of the form X and not X or X or not X."),
         Guidance    => To_Unbounded_String
           ("Correct the copied or negated operand, or replace the expression " &
            "with the intended constant value.")),
      Identical_Branches =>
        (Name        => To_Unbounded_String ("Identical_Branches"),
         Description => To_Unbounded_String
           ("Find adjacent if, elsif, or else branches with identical bodies."),
         Guidance    => To_Unbounded_String
           ("Merge the conditions or restore the branch-specific operation " &
            "that was probably lost during editing.")),
      Repeated_Statement =>
        (Name        => To_Unbounded_String ("Repeated_Statement"),
         Description => To_Unbounded_String
           ("Find identical assignments repeated consecutively."),
         Guidance    => To_Unbounded_String
           ("Remove the duplicate or correct the operand that should differ " &
            "in the second statement.")),
      Ineffective_Operation =>
        (Name        => To_Unbounded_String ("Ineffective_Operation"),
         Description => To_Unbounded_String
           ("Find arithmetic or boolean operations whose identity operand " &
            "cannot affect the result."),
         Guidance    => To_Unbounded_String
           ("Remove the ineffective operation or correct a constant or operand " &
            "that was entered incorrectly.")),
      Constant_Result_Operation =>
        (Name        => To_Unbounded_String ("Constant_Result_Operation"),
         Description => To_Unbounded_String
           ("Find operations forced to a constant result by zero, one, or a " &
            "boolean absorbing operand."),
         Guidance    => To_Unbounded_String
           ("Replace the expression with the constant when intentional, or " &
            "correct the operand that unexpectedly forces the result.")),
      Empty_Loop =>
        (Name        => To_Unbounded_String ("Empty_Loop"),
         Description => To_Unbounded_String
           ("Find loops whose bodies contain only null statements or pragmas."),
         Guidance    => To_Unbounded_String
           ("Implement the missing loop body or remove the loop; an intentional " &
            "wait should use an explicit delay or synchronization operation."))
   );

   Rule_States       : array (Rule_Kind) of Rule_State := (others => Disabled);
   Verbose_Mode      : Boolean := False;
   Quiet_Mode        : Boolean := False;
   Show_Help_Flag    : Boolean := False;
   Show_Version      : Boolean := False;
   List_Checks_Only  : Boolean := False;
   Invalid_Options   : Boolean := False;
   Source_File_Count : Natural := 0;
   Violations        : Natural := 0;
   Rule_Violations   : array (Rule_Kind) of Natural := (others => 0);

   procedure Log_Verbose (Message : String) is
   begin
      if Verbose_Mode and then not Quiet_Mode then
         Ada.Text_IO.Put_Line ("adalang-analyzer [INFO]: " & Message);
      end if;
   end Log_Verbose;

   function To_Decimal (N : Natural) return String is
      Result : String := Natural'Image (N);
   begin
      return Ada.Strings.Fixed.Trim (Result, Ada.Strings.Both);
   end To_Decimal;

   function Normalize_Rule_Name (Name : String) return String is
      Result : String (Name'Range) := Name;
   begin
      for I in Result'Range loop
         if Result (I) in 'A' .. 'Z' then
            Result (I) := Character'Val (Character'Pos (Result (I)) + 32);
         elsif Result (I) = '_' then
            Result (I) := '-';
         end if;
      end loop;
      return Result;
   end Normalize_Rule_Name;

   function Lookup_Rule_Kind (Name : String; Found : out Boolean) return Rule_Kind is
      Normalized : constant String := Normalize_Rule_Name (Name);
   begin
      for R in Rule_Kind loop
         if Normalize_Rule_Name
              (Ada.Strings.Unbounded.To_String (Rule_Infos (R).Name)) =
            Normalized
         then
            Found := True;
            return R;
         end if;
      end loop;
      Found := False;
      return No_Goto;
   end Lookup_Rule_Kind;

   function Repeat_Char (Char : Character; Count : Natural) return String is
   begin
      if Count = 0 then
         return "";
      end if;

      declare
         Result : constant String (1 .. Count) := (others => Char);
      begin
         return Result;
      end;
   end Repeat_Char;

   function Source_Line (Filename : String; Line_Number : Natural) return String is
      File         : Ada.Text_IO.File_Type;
      Current_Line : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);

      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            Current_Line := Current_Line + 1;

            if Current_Line = Line_Number then
               Ada.Text_IO.Close (File);
               return Line;
            end if;
         end;
      end loop;

      Ada.Text_IO.Close (File);
      return "";

   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;

         return "";
   end Source_Line;

   function Highlight_Width
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Start_Line   : constant Natural := Natural (Node.Sloc_Range.Start_Line);
      End_Line     : constant Natural := Natural (Node.Sloc_Range.End_Line);
      Start_Column : constant Natural := Natural (Node.Sloc_Range.Start_Column);
      End_Column   : constant Natural := Natural (Node.Sloc_Range.End_Column);
      Width        : Natural := 1;
   begin
      if Start_Line = End_Line and then End_Column > Start_Column then
         Width := End_Column - Start_Column;
      end if;

      if Width > 120 then
         return 120;
      else
         return Width;
      end if;
   end Highlight_Width;

   procedure Report_Rule_Violation (Unit : Libadalang.Analysis.Analysis_Unit;
                                   Node : Libadalang.Analysis.Ada_Node'Class;
                                   Rule : Rule_Kind;
                                   Message : String) is
      Filename     : constant String := Unit.Get_Filename;
      Line_Number  : constant Natural := Natural (Node.Sloc_Range.Start_Line);
      Column       : constant Natural := Natural (Node.Sloc_Range.Start_Column);
      Rule_Name    : constant String :=
        Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Name);
      Source_Text  : constant String := Source_Line (Filename, Line_Number);
      Caret_Width  : constant Natural := Highlight_Width (Node);
   begin
      Violations := Violations + 1;
      Rule_Violations (Rule) := Rule_Violations (Rule) + 1;

      if not Quiet_Mode then
         Ada.Text_IO.Put_Line (Filename & ":" &
                   To_Decimal (Line_Number) & ":" &
                   To_Decimal (Column) &
                   ": warning: " & Message & " [" &
                   Rule_Name & "]");
         Ada.Text_IO.Put_Line ("  rule: " &
                   Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Description));
         Ada.Text_IO.Put_Line ("  advice: " &
                   Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Guidance));

         if Source_Text /= "" then
            Ada.Text_IO.Put_Line ("  source:");
            Ada.Text_IO.Put_Line ("    " & Source_Text);

            if Column > 0 then
               Ada.Text_IO.Put_Line
                 ("    " & Repeat_Char (' ', Column - 1) &
                  Repeat_Char ('^', Caret_Width));
            end if;
         end if;
      end if;
   end Report_Rule_Violation;

   procedure Show_Help is
   begin
      Ada.Text_IO.Put_Line ("Usage: adalang-analyzer [options] <source_files>");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("A clang-tidy analyzer for Ada based on Libadalang.");
      Ada.Text_IO.Put_Line ("");
      Ada.Text_IO.Put_Line ("Options:");
      Ada.Text_IO.Put_Line ("  -h, --help            Show this help and exit");
      Ada.Text_IO.Put_Line ("  -version              Show version and exit");
      Ada.Text_IO.Put_Line ("  -checks=<list>        Enable/disable checks");
      Ada.Text_IO.Put_Line ("  -list-checks          List available checks");
      Ada.Text_IO.Put_Line ("  -v, -verbose          Enable verbose output");
      Ada.Text_IO.Put_Line ("  -q, -quiet            Suppress summary output");
      Ada.Text_IO.Put_Line ("  --                    Treat items as files");
   end Show_Help;

   procedure Print_Version is
   begin
      Ada.Text_IO.Put_Line ("adalang-analyzer version 0.1.0-dev");
   end Print_Version;

   procedure Print_Check_List is
   begin
      Ada.Text_IO.Put_Line ("Available checks:");
      for Rule in Rule_Kind loop
         Ada.Text_IO.Put_Line ("  " & Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Name) & " - " &
                               Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Description));
         Ada.Text_IO.Put_Line ("    " &
                               Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Guidance));
      end loop;
   end Print_Check_List;

   procedure Process_Command_Switch (Switch : String) is
      procedure Apply (Name : String; Mode : Rule_State) is
         Found : Boolean;
         Kind  : Rule_Kind;
      begin
         Kind := Lookup_Rule_Kind (Name, Found);
         if Found then
            Rule_States (Kind) := Mode;
         else
            Ada.Text_IO.Put_Line ("adalang-analyzer: unknown check '" & Name & "'");
            Invalid_Options := True;
         end if;
      end Apply;
   begin
      if Switch'Length < 3 then
         return;
      end if;

      if Switch (Switch'First) = '-' and then Switch (Switch'First + 1) = 'R' then
         Apply (Switch (Switch'First + 2 .. Switch'Last), Disabled);
      elsif Switch (Switch'First) = '+' and then Switch (Switch'First + 1) = 'R' then
         Apply (Switch (Switch'First + 2 .. Switch'Last), Enabled);
      end if;
   end Process_Command_Switch;

   procedure Parse_Checks_Option (Option : String) is
      List_Text : constant String := Option (Option'First + 8 .. Option'Last);

      procedure Apply_Check_Item (Item_Untrimmed : String) is
         Item   : constant String :=
           Ada.Strings.Fixed.Trim (Item_Untrimmed, Ada.Strings.Both);
         Kind   : Rule_Kind;
         Found  : Boolean;
         Action : Rule_State := Enabled;
         First  : Positive;
      begin
         if Item = "" then
            null;
         elsif Item = "*" then
            for R in Rule_Kind loop
               Rule_States (R) := Enabled;
            end loop;
         elsif Item = "-*" then
            for R in Rule_Kind loop
               Rule_States (R) := Disabled;
            end loop;
         else
            First := Item'First;
            Action := Enabled;

            if Item (First) = '+' then
               First := First + 1;
            elsif Item (First) = '-' then
               Action := Disabled;
               First := First + 1;
            end if;

            if First > Item'Last then
               Ada.Text_IO.Put_Line ("adalang-analyzer: empty check name");
               Invalid_Options := True;
            else
               declare
                  Name : constant String := Item (First .. Item'Last);
               begin
                  Kind := Lookup_Rule_Kind (Name, Found);
                  if Found then
                     Rule_States (Kind) := Action;
                  else
                     Ada.Text_IO.Put_Line
                       ("adalang-analyzer: unknown check '" & Name & "'");
                     Invalid_Options := True;
                  end if;
               end;
            end if;
         end if;
      end Apply_Check_Item;

      Start : Positive := List_Text'First;
   begin
      for Index in List_Text'Range loop
         if List_Text (Index) = ',' then
            Apply_Check_Item (List_Text (Start .. Index - 1));
            Start := Index + 1;
         end if;
      end loop;

      if Start <= List_Text'Last then
         Apply_Check_Item (List_Text (Start .. List_Text'Last));
      end if;
   end Parse_Checks_Option;

   type Abstract_Bool is (Bool_Unknown, Bool_False, Bool_True);

   function Bool_Name (Value : Abstract_Bool) return String is
   begin
      case Value is
         when Bool_False =>
            return "false";
         when Bool_True =>
            return "true";
         when Bool_Unknown =>
            return "unknown";
      end case;
   end Bool_Name;

   function Not_Bool (Value : Abstract_Bool) return Abstract_Bool is
   begin
      case Value is
         when Bool_False =>
            return Bool_True;
         when Bool_True =>
            return Bool_False;
         when Bool_Unknown =>
            return Bool_Unknown;
      end case;
   end Not_Bool;

   function And_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_False or else Right = Bool_False then
         return Bool_False;
      elsif Left = Bool_True and then Right = Bool_True then
         return Bool_True;
      else
         return Bool_Unknown;
      end if;
   end And_Bool;

   function Or_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_True or else Right = Bool_True then
         return Bool_True;
      elsif Left = Bool_False and then Right = Bool_False then
         return Bool_False;
      else
         return Bool_Unknown;
      end if;
   end Or_Bool;

   function Eq_Bool
     (Left : Abstract_Bool; Right : Abstract_Bool) return Abstract_Bool
   is
   begin
      if Left = Bool_Unknown or else Right = Bool_Unknown then
         return Bool_Unknown;
      elsif Left = Right then
         return Bool_True;
      else
         return Bool_False;
      end if;
   end Eq_Bool;

   function Bool_From (Value : Boolean) return Abstract_Bool is
   begin
      if Value then
         return Bool_True;
      else
         return Bool_False;
      end if;
   end Bool_From;

   type Abstract_Int is record
      Known : Boolean := False;
      Value : Long_Long_Integer := 0;
   end record;

   Unknown_Int : constant Abstract_Int := (Known => False, Value => 0);

   function Known_Int (Value : Long_Long_Integer) return Abstract_Int is
   begin
      return (Known => True, Value => Value);
   end Known_Int;

   function Lower_Char (Char : Character) return Character is
   begin
      if Char in 'A' .. 'Z' then
         return Character'Val (Character'Pos (Char) + 32);
      else
         return Char;
      end if;
   end Lower_Char;

   function Node_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return "";
      else
         return Langkit_Support.Text.To_UTF8
           (Libadalang.Analysis.Text (Node));
      end if;
   end Node_Text;

   function Canonical_Text
     (Node : Libadalang.Analysis.Ada_Node'Class) return String
   is
      Text      : constant String := Node_Text (Node);
      Result    : Unbounded_String;
      Index     : Natural := Text'First;
      In_String : Boolean := False;
   begin
      while Index <= Text'Last loop
         if Text (Index) = '"' then
            Append (Result, Text (Index));
            if In_String and then Index < Text'Last
              and then Text (Index + 1) = '"'
            then
               --  Two quotes encode one quote inside an Ada string literal.
               Append (Result, Text (Index + 1));
               Index := Index + 2;
            else
               In_String := not In_String;
               Index := Index + 1;
            end if;
         elsif In_String then
            Append (Result, Text (Index));
            Index := Index + 1;
         elsif Text (Index) = Character'Val (39)
           and then Index + 2 <= Text'Last
           and then Text (Index + 2) = Character'Val (39)
         then
            --  Preserve the spelling and case of character literals.
            Append (Result, Text (Index .. Index + 2));
            Index := Index + 3;
         elsif Text (Index) not in ' '
           | Ada.Characters.Latin_1.HT
           | Ada.Characters.Latin_1.LF
           | Ada.Characters.Latin_1.CR
         then
            Append (Result, Lower_Char (Text (Index)));
            Index := Index + 1;
         else
            Index := Index + 1;
         end if;
      end loop;

      return To_String (Result);
   end Canonical_Text;

   function Strip_Underscores (Text : String) return String is
      Result : Unbounded_String;
   begin
      for Char of Text loop
         if Char /= '_' then
            Append (Result, Lower_Char (Char));
         end if;
      end loop;

      return To_String (Result);
   end Strip_Underscores;

   function Find_Char
     (Text : String; Char : Character; From : Positive) return Natural
   is
   begin
      if Text = "" or else From > Text'Last then
         return 0;
      end if;

      for Index in From .. Text'Last loop
         if Text (Index) = Char then
            return Index;
         end if;
      end loop;

      return 0;
   end Find_Char;

   function Digit_Value (Char : Character) return Natural is
   begin
      if Char in '0' .. '9' then
         return Character'Pos (Char) - Character'Pos ('0');
      elsif Char in 'a' .. 'f' then
         return 10 + Character'Pos (Char) - Character'Pos ('a');
      else
         return 36;
      end if;
   end Digit_Value;

   function Parse_Unsigned
     (Text : String; Base : Positive; Value : out Long_Long_Integer)
      return Boolean
   is
      Result : Long_Long_Integer := 0;
   begin
      if Text = "" then
         return False;
      end if;

      for Char of Text loop
         declare
            Digit : constant Natural := Digit_Value (Char);
         begin
            if Digit >= Base then
               return False;
            end if;

            if Result >
              (Long_Long_Integer'Last - Long_Long_Integer (Digit)) /
              Long_Long_Integer (Base)
            then
               return False;
            end if;

            Result := Result * Long_Long_Integer (Base) +
              Long_Long_Integer (Digit);
         end;
      end loop;

      Value := Result;
      return True;
   end Parse_Unsigned;

   function Parse_Exponent
     (Text : String; Value : out Natural) return Boolean
   is
      Start  : Positive := Text'First;
      Parsed : Long_Long_Integer;
   begin
      if Text = "" then
         Value := 0;
         return True;
      end if;

      if Text (Start) = '+' then
         Start := Start + 1;
      elsif Text (Start) = '-' then
         return False;
      end if;

      if Start > Text'Last then
         return False;
      end if;

      if not Parse_Unsigned (Text (Start .. Text'Last), 10, Parsed) then
         return False;
      elsif Parsed > Long_Long_Integer (Natural'Last) then
         return False;
      else
         Value := Natural (Parsed);
         return True;
      end if;
   end Parse_Exponent;

   function Multiply_By_Power
     (Value : Long_Long_Integer; Base : Positive; Exponent : Natural;
      Result : out Long_Long_Integer) return Boolean
   is
      Current : Long_Long_Integer := Value;
   begin
      if Exponent > 63 then
         return False;
      end if;

      for Count in 1 .. Exponent loop
         if Current >
           Long_Long_Integer'Last / Long_Long_Integer (Base)
         then
            return False;
         end if;

         Current := Current * Long_Long_Integer (Base);
      end loop;

      Result := Current;
      return True;
   end Multiply_By_Power;

   function Parse_Integer_Text
     (Raw_Text : String; Value : out Long_Long_Integer) return Boolean
   is
      Text       : constant String := Strip_Underscores (Raw_Text);
      Hash_1     : Natural;
      Hash_2     : Natural;
      Exp_Index  : Natural;
      Base_Value : Long_Long_Integer;
      Number     : Long_Long_Integer;
      Exponent   : Natural := 0;
   begin
      if Text = "" then
         return False;
      end if;

      Hash_1 := Find_Char (Text, '#', Text'First);

      if Hash_1 /= 0 then
         if Hash_1 = Text'First then
            return False;
         end if;

         Hash_2 := Find_Char (Text, '#', Hash_1 + 1);

         if Hash_2 = 0 or else Hash_2 = Hash_1 + 1 then
            return False;
         end if;

         if not Parse_Unsigned
           (Text (Text'First .. Hash_1 - 1), 10, Base_Value)
           or else Base_Value < 2
           or else Base_Value > 16
         then
            return False;
         end if;

         if not Parse_Unsigned
           (Text (Hash_1 + 1 .. Hash_2 - 1), Positive (Base_Value), Number)
         then
            return False;
         end if;

         if Hash_2 < Text'Last then
            if Text (Hash_2 + 1) /= 'e' then
               return False;
            end if;

            if not Parse_Exponent
              (Text (Hash_2 + 2 .. Text'Last), Exponent)
            then
               return False;
            end if;
         end if;

         return Multiply_By_Power
           (Number, Positive (Base_Value), Exponent, Value);
      end if;

      Exp_Index := Find_Char (Text, 'e', Text'First);

      if Exp_Index = 0 then
         return Parse_Unsigned (Text, 10, Value);
      elsif Exp_Index = Text'First then
         return False;
      else
         if not Parse_Unsigned
           (Text (Text'First .. Exp_Index - 1), 10, Number)
         then
            return False;
         end if;

         if not Parse_Exponent
           (Text (Exp_Index + 1 .. Text'Last), Exponent)
         then
            return False;
         end if;

         return Multiply_By_Power (Number, 10, Exponent, Value);
      end if;
   end Parse_Integer_Text;

   function Safe_Add
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left + Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Add;

   function Safe_Sub
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left - Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Sub;

   function Safe_Mul
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
   begin
      return Known_Int (Left * Right);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Mul;

   function Safe_Pow
     (Left : Long_Long_Integer; Right : Long_Long_Integer) return Abstract_Int
   is
      Result : Long_Long_Integer := 1;
   begin
      if Right < 0 or else Right > 63 then
         return Unknown_Int;
      end if;

      for Count in 1 .. Right loop
         Result := Result * Left;
      end loop;

      return Known_Int (Result);
   exception
      when Constraint_Error =>
         return Unknown_Int;
   end Safe_Pow;

   function Integer_Value
     (Node : Libadalang.Analysis.Ada_Node'Class) return Abstract_Int
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Unknown_Int;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Int_Literal =>
            declare
               Parsed : Long_Long_Integer;
            begin
               if Parse_Integer_Text (Node_Text (Node), Parsed) then
                  return Known_Int (Parsed);
               else
                  return Unknown_Int;
               end if;
            end;

         when Libadalang.Common.Ada_Paren_Expr =>
            return Integer_Value (Node.As_Paren_Expr.F_Expr);

         when Libadalang.Common.Ada_Qual_Expr =>
            return Integer_Value (Node.As_Qual_Expr.F_Suffix);

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Expr  : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
               Value : constant Abstract_Int := Integer_Value (Expr.F_Expr);
            begin
               if not Value.Known then
                  return Unknown_Int;
               end if;

               case Expr.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Value;
                  when Libadalang.Common.Ada_Op_Minus =>
                     if Value.Value = Long_Long_Integer'First then
                        return Unknown_Int;
                     else
                        return Known_Int (-Value.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Abs =>
                     if Value.Value = Long_Long_Integer'First then
                        return Unknown_Int;
                     elsif Value.Value < 0 then
                        return Known_Int (-Value.Value);
                     else
                        return Value;
                     end if;
                  when others =>
                     return Unknown_Int;
               end case;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               Left  : constant Abstract_Int := Integer_Value (Expr.F_Left);
               Right : constant Abstract_Int := Integer_Value (Expr.F_Right);
            begin
               if not Left.Known or else not Right.Known then
                  return Unknown_Int;
               end if;

               case Expr.F_Op is
                  when Libadalang.Common.Ada_Op_Plus =>
                     return Safe_Add (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Minus =>
                     return Safe_Sub (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Mult =>
                     return Safe_Mul (Left.Value, Right.Value);
                  when Libadalang.Common.Ada_Op_Div =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value / Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Mod =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value mod Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Rem =>
                     if Right.Value = 0 then
                        return Unknown_Int;
                     else
                        return Known_Int (Left.Value rem Right.Value);
                     end if;
                  when Libadalang.Common.Ada_Op_Pow =>
                     return Safe_Pow (Left.Value, Right.Value);
                  when others =>
                     return Unknown_Int;
               end case;
            end;

         when others =>
            return Unknown_Int;
      end case;
   exception
      when others =>
         return Unknown_Int;
   end Integer_Value;

   function Is_Static_Zero
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Int_Value : constant Abstract_Int := Integer_Value (Node);
   begin
      if Int_Value.Known then
         return Int_Value.Value = 0;
      end if;

      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Real_Literal =>
            declare
               Value : constant Long_Long_Float :=
                 Long_Long_Float'Value (Strip_Underscores (Node_Text (Node)));
            begin
               return Value = 0.0;
            exception
               when others =>
                  return False;
            end;

         when Libadalang.Common.Ada_Paren_Expr =>
            return Is_Static_Zero (Node.As_Paren_Expr.F_Expr);

         when Libadalang.Common.Ada_Qual_Expr =>
            return Is_Static_Zero (Node.As_Qual_Expr.F_Suffix);

         when Libadalang.Common.Ada_Un_Op =>
            return Is_Static_Zero (Node.As_Un_Op.F_Expr);

         when others =>
            return False;
      end case;
   end Is_Static_Zero;

   function Is_Static_One
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Value : constant Abstract_Int := Integer_Value (Node);
   begin
      return Value.Known and then Value.Value = 1;
   end Is_Static_One;

   function Is_Null_Literal
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Null_Literal =>
            return True;
         when Libadalang.Common.Ada_Paren_Expr =>
            return Is_Null_Literal (Node.As_Paren_Expr.F_Expr);
         when Libadalang.Common.Ada_Qual_Expr =>
            return Is_Null_Literal (Node.As_Qual_Expr.F_Suffix);
         when others =>
            return False;
      end case;
   end Is_Null_Literal;

   function Compare_Integers
     (Op : Libadalang.Common.Ada_Node_Kind_Type;
      Left : Abstract_Int; Right : Abstract_Int) return Abstract_Bool
   is
   begin
      if not Left.Known or else not Right.Known then
         return Bool_Unknown;
      end if;

      case Op is
         when Libadalang.Common.Ada_Op_Eq =>
            return Bool_From (Left.Value = Right.Value);
         when Libadalang.Common.Ada_Op_Neq =>
            return Bool_From (Left.Value /= Right.Value);
         when Libadalang.Common.Ada_Op_Lt =>
            return Bool_From (Left.Value < Right.Value);
         when Libadalang.Common.Ada_Op_Lte =>
            return Bool_From (Left.Value <= Right.Value);
         when Libadalang.Common.Ada_Op_Gt =>
            return Bool_From (Left.Value > Right.Value);
         when Libadalang.Common.Ada_Op_Gte =>
            return Bool_From (Left.Value >= Right.Value);
         when others =>
            return Bool_Unknown;
      end case;
   end Compare_Integers;

   function Boolean_Value
     (Node : Libadalang.Analysis.Ada_Node'Class) return Abstract_Bool
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return Bool_Unknown;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Identifier =>
            declare
               Text : constant String :=
                 Normalize_Rule_Name
                   (Langkit_Support.Text.To_UTF8
                      (Libadalang.Analysis.Text (Node)));
            begin
               if Text = "true" then
                  return Bool_True;
               elsif Text = "false" then
                  return Bool_False;
               else
                  return Bool_Unknown;
               end if;
            end;

         when Libadalang.Common.Ada_Paren_Expr =>
            return Boolean_Value (Node.As_Paren_Expr.F_Expr);

         when Libadalang.Common.Ada_Un_Op =>
            declare
               Expr : constant Libadalang.Analysis.Un_Op := Node.As_Un_Op;
            begin
               if Expr.F_Op = Libadalang.Common.Ada_Op_Not then
                  return Not_Bool (Boolean_Value (Expr.F_Expr));
               else
                  return Bool_Unknown;
               end if;
            end;

         when Libadalang.Common.Ada_Bin_Op_Range =>
            declare
               Expr  : constant Libadalang.Analysis.Bin_Op := Node.As_Bin_Op;
               Left  : constant Abstract_Bool := Boolean_Value (Expr.F_Left);
               Right : constant Abstract_Bool := Boolean_Value (Expr.F_Right);
               Op    : constant Libadalang.Common.Ada_Node_Kind_Type :=
                 Expr.F_Op;
            begin
               case Op is
                  when Libadalang.Common.Ada_Op_And
                     | Libadalang.Common.Ada_Op_And_Then =>
                     return And_Bool (Left, Right);
                  when Libadalang.Common.Ada_Op_Or
                     | Libadalang.Common.Ada_Op_Or_Else =>
                     return Or_Bool (Left, Right);
                  when Libadalang.Common.Ada_Op_Eq =>
                     declare
                        Bool_Result : constant Abstract_Bool :=
                          Eq_Bool (Left, Right);
                        Int_Result  : constant Abstract_Bool :=
                          Compare_Integers
                            (Op, Integer_Value (Expr.F_Left),
                             Integer_Value (Expr.F_Right));
                     begin
                        if Bool_Result /= Bool_Unknown then
                           return Bool_Result;
                        elsif Int_Result /= Bool_Unknown then
                           return Int_Result;
                        elsif Is_Null_Literal (Expr.F_Left)
                          and then Is_Null_Literal (Expr.F_Right)
                        then
                           return Bool_True;
                        else
                           return Bool_Unknown;
                        end if;
                     end;
                  when Libadalang.Common.Ada_Op_Neq =>
                     declare
                        Bool_Result : constant Abstract_Bool :=
                          Not_Bool (Eq_Bool (Left, Right));
                        Int_Result  : constant Abstract_Bool :=
                          Compare_Integers
                            (Op, Integer_Value (Expr.F_Left),
                             Integer_Value (Expr.F_Right));
                     begin
                        if Bool_Result /= Bool_Unknown then
                           return Bool_Result;
                        elsif Int_Result /= Bool_Unknown then
                           return Int_Result;
                        elsif Is_Null_Literal (Expr.F_Left)
                          and then Is_Null_Literal (Expr.F_Right)
                        then
                           return Bool_False;
                        else
                           return Bool_Unknown;
                        end if;
                     end;
                  when Libadalang.Common.Ada_Op_Xor =>
                     return Not_Bool (Eq_Bool (Left, Right));
                  when Libadalang.Common.Ada_Op_Lt
                     | Libadalang.Common.Ada_Op_Lte
                     | Libadalang.Common.Ada_Op_Gt
                     | Libadalang.Common.Ada_Op_Gte =>
                     return Compare_Integers
                       (Op, Integer_Value (Expr.F_Left),
                        Integer_Value (Expr.F_Right));
                  when others =>
                     return Bool_Unknown;
               end case;
            end;

         when Libadalang.Common.Ada_Membership_Expr =>
            declare
               Expr      : constant Libadalang.Analysis.Membership_Expr :=
                 Node.As_Membership_Expr;
               Subject   : constant Abstract_Int :=
                 Integer_Value (Expr.F_Expr);
               Known_All : Boolean := True;
               Matches   : Boolean := False;
            begin
               if not Subject.Known then
                  return Bool_Unknown;
               end if;

               for I in 1 .. Expr.F_Membership_Exprs.Children_Count loop
                  declare
                     Alternative : constant Libadalang.Analysis.Ada_Node :=
                       Expr.F_Membership_Exprs.Child (I);
                  begin
                     if Alternative.Kind in Libadalang.Common.Ada_Bin_Op_Range
                       and then Alternative.As_Bin_Op.F_Op =
                         Libadalang.Common.Ada_Op_Double_Dot
                     then
                        declare
                           Left_Bound  : constant Abstract_Int :=
                             Integer_Value (Alternative.As_Bin_Op.F_Left);
                           Right_Bound : constant Abstract_Int :=
                             Integer_Value (Alternative.As_Bin_Op.F_Right);
                        begin
                           if Left_Bound.Known and then Right_Bound.Known then
                              Matches := Matches or else
                                (Subject.Value >= Left_Bound.Value
                                 and then Subject.Value <= Right_Bound.Value);
                           else
                              Known_All := False;
                           end if;
                        end;
                     else
                        declare
                           Value : constant Abstract_Int :=
                             Integer_Value (Alternative);
                        begin
                           if Value.Known then
                              Matches := Matches or else
                                Subject.Value = Value.Value;
                           else
                              Known_All := False;
                           end if;
                        end;
                     end if;
                  end;
               end loop;

               if not Known_All then
                  return Bool_Unknown;
               elsif Expr.F_Op = Libadalang.Common.Ada_Op_In then
                  return Bool_From (Matches);
               else
                  return Bool_From (not Matches);
               end if;
            end;

         when others =>
            return Bool_Unknown;
      end case;
   end Boolean_Value;

   procedure Report_Constant_Condition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Cond : Libadalang.Analysis.Ada_Node'Class)
   is
      Value : constant Abstract_Bool := Boolean_Value (Cond);
   begin
      if Rule_States (Constant_Condition) = Enabled
        and then Value /= Bool_Unknown
      then
         Report_Rule_Violation
           (Unit, Cond, Constant_Condition,
            "condition is always " & Bool_Name (Value));
      end if;
   end Report_Constant_Condition;

   function Terminates_Statement
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return False;
      end if;

      case Node.Kind is
         when Libadalang.Common.Ada_Return_Stmt
            | Libadalang.Common.Ada_Extended_Return_Stmt
            | Libadalang.Common.Ada_Raise_Stmt
            | Libadalang.Common.Ada_Goto_Stmt =>
            return True;

         when Libadalang.Common.Ada_Exit_Stmt =>
            return Libadalang.Analysis.Is_Null
              (Node.As_Exit_Stmt.F_Cond_Expr);

         when others =>
            return False;
      end case;
   end Terminates_Statement;

   procedure Analyze_Statement_List
     (Unit : Libadalang.Analysis.Analysis_Unit;
      List : Libadalang.Analysis.Ada_Node'Class)
   is
      Previous_Terminates : Boolean := False;
      Previous_Assignment : Unbounded_String;
   begin
      if Rule_States (Unreachable_Code) /= Enabled
        and then Rule_States (Repeated_Statement) /= Enabled
      then
         return;
      end if;

      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if not Libadalang.Analysis.Is_Null (Stmt) then
               if Previous_Terminates
                 and then Stmt.Kind = Libadalang.Common.Ada_Label
               then
                  --  A label is a possible entry point, so statements from
                  --  this point onward are reachable again.
                  Previous_Terminates := False;
               elsif Previous_Terminates
                 and then Stmt.Kind in Libadalang.Common.Ada_Stmt
               then
                  Report_Rule_Violation
                    (Unit, Stmt, Unreachable_Code,
                     "statement is unreachable");
               end if;

               if Rule_States (Repeated_Statement) = Enabled
                 and then Stmt.Kind = Libadalang.Common.Ada_Assign_Stmt
               then
                  declare
                     Current : constant String := Canonical_Text (Stmt);
                  begin
                     if Current /= ""
                       and then Current = To_String (Previous_Assignment)
                     then
                        Report_Rule_Violation
                          (Unit, Stmt, Repeated_Statement,
                           "assignment duplicates the preceding assignment");
                     end if;
                     Previous_Assignment := To_Unbounded_String (Current);
                  end;
               else
                  Previous_Assignment := Null_Unbounded_String;
               end if;

               if Terminates_Statement (Stmt) then
                  Previous_Terminates := True;
               end if;
            end if;
         end;
      end loop;
   end Analyze_Statement_List;

   function Is_Negation_Of
     (Possible_Not : Libadalang.Analysis.Ada_Node'Class;
      Other        : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
   begin
      return not Libadalang.Analysis.Is_Null (Possible_Not)
        and then Possible_Not.Kind = Libadalang.Common.Ada_Un_Op
        and then Possible_Not.As_Un_Op.F_Op = Libadalang.Common.Ada_Op_Not
        and then Canonical_Text (Possible_Not.As_Un_Op.F_Expr) /= ""
        and then Canonical_Text (Possible_Not.As_Un_Op.F_Expr) =
          Canonical_Text (Other);
   end Is_Negation_Of;

   function Interesting_Same_Operand_Op
     (Op : Libadalang.Common.Ada_Node_Kind_Type) return Boolean is
   begin
      case Op is
         when Libadalang.Common.Ada_Op_And
            | Libadalang.Common.Ada_Op_And_Then
            | Libadalang.Common.Ada_Op_Or
            | Libadalang.Common.Ada_Op_Or_Else
            | Libadalang.Common.Ada_Op_Xor
            | Libadalang.Common.Ada_Op_Eq
            | Libadalang.Common.Ada_Op_Neq
            | Libadalang.Common.Ada_Op_Lt
            | Libadalang.Common.Ada_Op_Lte
            | Libadalang.Common.Ada_Op_Gt
            | Libadalang.Common.Ada_Op_Gte
            | Libadalang.Common.Ada_Op_Minus
            | Libadalang.Common.Ada_Op_Div
            | Libadalang.Common.Ada_Op_Mod
            | Libadalang.Common.Ada_Op_Rem =>
            return True;
         when others =>
            return False;
      end case;
   end Interesting_Same_Operand_Op;

   procedure Analyze_Binary_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.Bin_Op)
   is
      Op         : constant Libadalang.Common.Ada_Node_Kind_Type :=
        Expr.F_Op;
      Left_Text  : constant String := Canonical_Text (Expr.F_Left);
      Right_Text : constant String := Canonical_Text (Expr.F_Right);
      Left_Int   : constant Abstract_Int := Integer_Value (Expr.F_Left);
      Right_Int  : constant Abstract_Int := Integer_Value (Expr.F_Right);
   begin
      if Rule_States (Division_By_Zero) = Enabled
        and then Op in Libadalang.Common.Ada_Op_Div
          | Libadalang.Common.Ada_Op_Mod
          | Libadalang.Common.Ada_Op_Rem
        and then Is_Static_Zero (Expr.F_Right)
      then
         Report_Rule_Violation
           (Unit, Expr.F_Right, Division_By_Zero,
            "right operand is statically zero");
      end if;

      if Rule_States (Reversed_Range) = Enabled
        and then Op = Libadalang.Common.Ada_Op_Double_Dot
        and then Left_Int.Known
        and then Right_Int.Known
        and then Left_Int.Value > Right_Int.Value
      then
         Report_Rule_Violation
           (Unit, Expr, Reversed_Range,
            "range lower bound is greater than upper bound");
      end if;

      if Rule_States (Same_Operand) = Enabled
        and then Interesting_Same_Operand_Op (Op)
        and then Left_Text /= ""
        and then Left_Text = Right_Text
      then
         Report_Rule_Violation
           (Unit, Expr, Same_Operand,
            "same expression appears on both sides of the operator");
      end if;

      if Rule_States (Contradictory_Condition) = Enabled
        and then Op in Libadalang.Common.Ada_Op_And
          | Libadalang.Common.Ada_Op_And_Then
          | Libadalang.Common.Ada_Op_Or
          | Libadalang.Common.Ada_Op_Or_Else
        and then (Is_Negation_Of (Expr.F_Left, Expr.F_Right)
                  or else Is_Negation_Of (Expr.F_Right, Expr.F_Left))
      then
         Report_Rule_Violation
           (Unit, Expr, Contradictory_Condition,
            (if Op in Libadalang.Common.Ada_Op_And
               | Libadalang.Common.Ada_Op_And_Then
             then "condition is always false because it combines X and not X"
             else "condition is always true because it combines X or not X"));
      end if;

      if Rule_States (Ineffective_Operation) = Enabled then
         if (Op = Libadalang.Common.Ada_Op_Plus
             and then (Is_Static_Zero (Expr.F_Left)
                       or else Is_Static_Zero (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Minus
                    and then Is_Static_Zero (Expr.F_Right))
           or else (Op = Libadalang.Common.Ada_Op_Mult
                    and then (Is_Static_One (Expr.F_Left)
                              or else Is_Static_One (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Div
                    and then Is_Static_One (Expr.F_Right))
           or else (Op = Libadalang.Common.Ada_Op_Pow
                    and then Is_Static_One (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_And
                      | Libadalang.Common.Ada_Op_And_Then
                    and then (Boolean_Value (Expr.F_Left) = Bool_True
                              or else Boolean_Value (Expr.F_Right) = Bool_True))
           or else (Op in Libadalang.Common.Ada_Op_Or
                      | Libadalang.Common.Ada_Op_Or_Else
                    and then (Boolean_Value (Expr.F_Left) = Bool_False
                              or else Boolean_Value (Expr.F_Right) = Bool_False))
         then
            Report_Rule_Violation
              (Unit, Expr, Ineffective_Operation,
               "identity operand has no effect on the expression result");
         end if;
      end if;

      if Rule_States (Constant_Result_Operation) = Enabled then
         if (Op = Libadalang.Common.Ada_Op_Mult
             and then (Is_Static_Zero (Expr.F_Left)
                       or else Is_Static_Zero (Expr.F_Right)))
           or else (Op = Libadalang.Common.Ada_Op_Pow
                    and then Is_Static_Zero (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_Mod
                      | Libadalang.Common.Ada_Op_Rem
                    and then Is_Static_One (Expr.F_Right))
           or else (Op in Libadalang.Common.Ada_Op_And
                      | Libadalang.Common.Ada_Op_And_Then
                    and then (Boolean_Value (Expr.F_Left) = Bool_False
                              or else Boolean_Value (Expr.F_Right) = Bool_False))
           or else (Op in Libadalang.Common.Ada_Op_Or
                      | Libadalang.Common.Ada_Op_Or_Else
                    and then (Boolean_Value (Expr.F_Left) = Bool_True
                              or else Boolean_Value (Expr.F_Right) = Bool_True))
         then
            Report_Rule_Violation
              (Unit, Expr, Constant_Result_Operation,
               "an absorbing operand forces this expression to a constant");
         end if;
      end if;
   end Analyze_Binary_Expression;

   procedure Analyze_Assignment
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.Assign_Stmt)
   is
      Target_Text : constant String := Canonical_Text (Stmt.F_Dest);
      Value_Text  : constant String := Canonical_Text (Stmt.F_Expr);
   begin
      if Rule_States (Self_Assignment) = Enabled
        and then Target_Text /= ""
        and then Target_Text = Value_Text
      then
         Report_Rule_Violation
           (Unit, Stmt, Self_Assignment,
            "assignment stores an expression back into itself");
      end if;
   end Analyze_Assignment;

   procedure Report_Unreachable_Branch
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class;
      Message : String) is
   begin
      if Rule_States (Unreachable_Branch) = Enabled
        and then not Libadalang.Analysis.Is_Null (Node)
      then
         Report_Rule_Violation (Unit, Node, Unreachable_Branch, Message);
      end if;
   end Report_Unreachable_Branch;

   procedure Report_Duplicate_Condition
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Cond : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Rule_States (Duplicate_Condition) = Enabled then
         Report_Rule_Violation
           (Unit, Cond, Duplicate_Condition,
            "condition duplicates an earlier condition in this chain");
      end if;
   end Report_Duplicate_Condition;

   procedure Report_Identical_Statement_Branches
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.If_Stmt)
   is
      Previous : Unbounded_String :=
        To_Unbounded_String (Canonical_Text (Stmt.F_Then_Stmts));
   begin
      if Rule_States (Identical_Branches) /= Enabled then
         return;
      end if;

      for Alt of Stmt.F_Alternatives loop
         declare
            Current : constant String := Canonical_Text (Alt.F_Stmts);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Alt.F_Stmts, Identical_Branches,
                  "branch body is identical to the preceding branch");
            end if;
            Previous := To_Unbounded_String (Current);
         end;
      end loop;

      if not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part) then
         declare
            Else_Stmts : constant Libadalang.Analysis.Stmt_List :=
              Stmt.F_Else_Part.F_Stmts;
            Current : constant String := Canonical_Text (Else_Stmts);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Else_Stmts, Identical_Branches,
                  "else body is identical to the preceding branch");
            end if;
         end;
      end if;
   end Report_Identical_Statement_Branches;

   procedure Report_Identical_Expression_Branches
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.If_Expr)
   is
      Previous : Unbounded_String :=
        To_Unbounded_String (Canonical_Text (Expr.F_Then_Expr));
   begin
      if Rule_States (Identical_Branches) /= Enabled then
         return;
      end if;

      for Alt of Expr.F_Alternatives loop
         declare
            Current : constant String := Canonical_Text (Alt.F_Then_Expr);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Alt.F_Then_Expr, Identical_Branches,
                  "conditional expression is identical to the preceding one");
            end if;
            Previous := To_Unbounded_String (Current);
         end;
      end loop;

      if not Libadalang.Analysis.Is_Null (Expr.F_Else_Expr) then
         declare
            Current : constant String := Canonical_Text (Expr.F_Else_Expr);
         begin
            if Current /= "" and then Current = To_String (Previous) then
               Report_Rule_Violation
                 (Unit, Expr.F_Else_Expr, Identical_Branches,
                  "else expression is identical to the preceding expression");
            end if;
         end;
      end if;
   end Report_Identical_Expression_Branches;

   procedure Analyze_If_Statement
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Stmt : Libadalang.Analysis.If_Stmt)
   is
      First_Cond          : constant Libadalang.Analysis.Expr :=
        Stmt.F_Cond_Expr;
      First_Text          : constant String := Canonical_Text (First_Cond);
      First_Value         : constant Abstract_Bool :=
        Boolean_Value (First_Cond);
      Alternatives        : constant Libadalang.Analysis.Elsif_Stmt_Part_List :=
        Stmt.F_Alternatives;
      Previous_Always_True : Boolean := First_Value = Bool_True;
   begin
      if First_Value = Bool_False then
         Report_Unreachable_Branch
           (Unit, Stmt.F_Then_Stmts,
            "then branch is unreachable because its condition is always false");
      end if;

      for I in 1 .. Alternatives.Children_Count loop
         declare
            Alt_Node : constant Libadalang.Analysis.Ada_Node :=
              Alternatives.Child (I);
            Alt      : constant Libadalang.Analysis.Elsif_Stmt_Part :=
              Alt_Node.As_Elsif_Stmt_Part;
            Cond     : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
            Cond_Text : constant String := Canonical_Text (Cond);
            Value    : constant Abstract_Bool := Boolean_Value (Cond);
         begin
            if Cond_Text /= "" and then Cond_Text = First_Text then
               Report_Duplicate_Condition (Unit, Cond);
            else
               for J in 1 .. I - 1 loop
                  declare
                     Previous : constant Libadalang.Analysis.Ada_Node :=
                       Alternatives.Child (J);
                  begin
                     if Cond_Text /= ""
                       and then Cond_Text =
                         Canonical_Text
                           (Previous.As_Elsif_Stmt_Part.F_Cond_Expr)
                     then
                        Report_Duplicate_Condition (Unit, Cond);
                        exit;
                     end if;
                  end;
               end loop;
            end if;

            if Previous_Always_True then
               Report_Unreachable_Branch
                 (Unit, Alt,
                  "elsif branch is unreachable because an earlier condition "
                  & "is always true");
            elsif Value = Bool_False then
               Report_Unreachable_Branch
                 (Unit, Alt.F_Stmts,
                  "elsif branch is unreachable because its condition is "
                  & "always false");
            elsif Value = Bool_True then
               Previous_Always_True := True;
            end if;
         end;
      end loop;

      if Previous_Always_True
        and then not Libadalang.Analysis.Is_Null (Stmt.F_Else_Part)
      then
         Report_Unreachable_Branch
           (Unit, Stmt.F_Else_Part,
            "else branch is unreachable because an earlier condition is "
           & "always true");
      end if;

      Report_Identical_Statement_Branches (Unit, Stmt);
   end Analyze_If_Statement;

   procedure Analyze_If_Expression
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Expr : Libadalang.Analysis.If_Expr)
   is
      First_Cond          : constant Libadalang.Analysis.Expr :=
        Expr.F_Cond_Expr;
      First_Text          : constant String := Canonical_Text (First_Cond);
      First_Value         : constant Abstract_Bool :=
        Boolean_Value (First_Cond);
      Alternatives        : constant Libadalang.Analysis.Elsif_Expr_Part_List :=
        Expr.F_Alternatives;
      Previous_Always_True : Boolean := First_Value = Bool_True;
   begin
      if First_Value = Bool_False then
         Report_Unreachable_Branch
           (Unit, Expr.F_Then_Expr,
            "then expression is unreachable because its condition is always "
            & "false");
      end if;

      for I in 1 .. Alternatives.Children_Count loop
         declare
            Alt_Node : constant Libadalang.Analysis.Ada_Node :=
              Alternatives.Child (I);
            Alt      : constant Libadalang.Analysis.Elsif_Expr_Part :=
              Alt_Node.As_Elsif_Expr_Part;
            Cond     : constant Libadalang.Analysis.Expr := Alt.F_Cond_Expr;
            Cond_Text : constant String := Canonical_Text (Cond);
            Value    : constant Abstract_Bool := Boolean_Value (Cond);
         begin
            if Cond_Text /= "" and then Cond_Text = First_Text then
               Report_Duplicate_Condition (Unit, Cond);
            else
               for J in 1 .. I - 1 loop
                  declare
                     Previous : constant Libadalang.Analysis.Ada_Node :=
                       Alternatives.Child (J);
                  begin
                     if Cond_Text /= ""
                       and then Cond_Text =
                         Canonical_Text
                           (Previous.As_Elsif_Expr_Part.F_Cond_Expr)
                     then
                        Report_Duplicate_Condition (Unit, Cond);
                        exit;
                     end if;
                  end;
               end loop;
            end if;

            if Previous_Always_True then
               Report_Unreachable_Branch
                 (Unit, Alt,
                  "elsif expression is unreachable because an earlier "
                  & "condition is always true");
            elsif Value = Bool_False then
               Report_Unreachable_Branch
                 (Unit, Alt.F_Then_Expr,
                  "elsif expression is unreachable because its condition is "
                  & "always false");
            elsif Value = Bool_True then
               Previous_Always_True := True;
            end if;
         end;
      end loop;

      if Previous_Always_True
        and then not Libadalang.Analysis.Is_Null (Expr.F_Else_Expr)
      then
         Report_Unreachable_Branch
           (Unit, Expr.F_Else_Expr,
            "else expression is unreachable because an earlier condition is "
            & "always true");
      end if;

      Report_Identical_Expression_Branches (Unit, Expr);
   end Analyze_If_Expression;

   function Has_Substantive_Statement
     (List : Libadalang.Analysis.Stmt_List) return Boolean is
   begin
      for I in 1 .. List.Children_Count loop
         declare
            Stmt : constant Libadalang.Analysis.Ada_Node := List.Child (I);
         begin
            if Libadalang.Analysis.Is_Null (Stmt)
              or else Stmt.Kind = Libadalang.Common.Ada_Pragma_Node
              or else Stmt.Kind = Libadalang.Common.Ada_Null_Stmt
            then
               null;
            else
               return True;
            end if;
         end;
      end loop;

      return False;
   end Has_Substantive_Statement;

   procedure Analyze_Exception_Handler
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Handler : Libadalang.Analysis.Exception_Handler) is
   begin
      if Rule_States (Empty_Exception_Handler) = Enabled
        and then not Has_Substantive_Statement (Handler.F_Stmts)
      then
         Report_Rule_Violation
           (Unit, Handler, Empty_Exception_Handler,
            "exception handler contains no substantive statements");
      end if;
   end Analyze_Exception_Handler;

   procedure Analyze_Bug_Finding_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
   begin
      case Node.Kind is
         when Libadalang.Common.Ada_Stmt_List =>
            Analyze_Statement_List (Unit, Node);

         when Libadalang.Common.Ada_Bin_Op_Range =>
            Analyze_Binary_Expression (Unit, Node.As_Bin_Op);

         when Libadalang.Common.Ada_Assign_Stmt =>
            Analyze_Assignment (Unit, Node.As_Assign_Stmt);

         when Libadalang.Common.Ada_If_Stmt =>
            Report_Constant_Condition
              (Unit, Node.As_If_Stmt.F_Cond_Expr);
            Analyze_If_Statement (Unit, Node.As_If_Stmt);

         when Libadalang.Common.Ada_Elsif_Stmt_Part =>
            Report_Constant_Condition
              (Unit, Node.As_Elsif_Stmt_Part.F_Cond_Expr);

         when Libadalang.Common.Ada_If_Expr =>
            Report_Constant_Condition
              (Unit, Node.As_If_Expr.F_Cond_Expr);
            Analyze_If_Expression (Unit, Node.As_If_Expr);

         when Libadalang.Common.Ada_Elsif_Expr_Part =>
            Report_Constant_Condition
              (Unit, Node.As_Elsif_Expr_Part.F_Cond_Expr);

         when Libadalang.Common.Ada_While_Loop_Stmt =>
            declare
               Spec : constant Libadalang.Analysis.Loop_Spec :=
                 Node.As_While_Loop_Stmt.F_Spec;
            begin
               if not Libadalang.Analysis.Is_Null (Spec) then
                  Report_Constant_Condition
                    (Unit, Spec.As_While_Loop_Spec.F_Expr);
               end if;
               if Rule_States (Empty_Loop) = Enabled
                 and then not Has_Substantive_Statement
                   (Node.As_Base_Loop_Stmt.F_Stmts)
               then
                  Report_Rule_Violation
                    (Unit, Node, Empty_Loop,
                     "loop body contains no substantive statements");
               end if;
            end;

         when Libadalang.Common.Ada_Exit_Stmt =>
            declare
               Cond : constant Libadalang.Analysis.Expr :=
                 Node.As_Exit_Stmt.F_Cond_Expr;
            begin
               if not Libadalang.Analysis.Is_Null (Cond) then
                  Report_Constant_Condition (Unit, Cond);
               end if;
            end;

         when Libadalang.Common.Ada_Null_Stmt =>
            if Rule_States (Null_Statement) = Enabled then
               Report_Rule_Violation
                 (Unit, Node, Null_Statement,
                  "null statement has no executable effect");
            end if;

         when Libadalang.Common.Ada_Exception_Handler =>
            Analyze_Exception_Handler (Unit, Node.As_Exception_Handler);

         when Libadalang.Common.Ada_For_Loop_Stmt
            | Libadalang.Common.Ada_Loop_Stmt =>
            if Rule_States (Empty_Loop) = Enabled
              and then not Has_Substantive_Statement
                (Node.As_Base_Loop_Stmt.F_Stmts)
            then
               Report_Rule_Violation
                 (Unit, Node, Empty_Loop,
                  "loop body contains no substantive statements");
            end if;

         when others =>
            null;
      end case;
   end Analyze_Bug_Finding_Node;

   procedure Evaluate_Node (Unit : Libadalang.Analysis.Analysis_Unit;
                           Node : Libadalang.Analysis.Ada_Node'Class) is
   begin
      if Libadalang.Analysis.Is_Null (Node) then
         return;
      end if;

      if Rule_States (No_Goto) = Enabled and then Node.Kind = Libadalang.Common.Ada_Goto_Stmt then
         Report_Rule_Violation (Unit, Node, No_Goto, "goto statement used");
      end if;
      if Rule_States (No_Abort) = Enabled and then Node.Kind = Libadalang.Common.Ada_Abort_Stmt then
         Report_Rule_Violation (Unit, Node, No_Abort, "abort statement used");
      end if;
      if Rule_States (No_Raise) = Enabled and then Node.Kind = Libadalang.Common.Ada_Raise_Stmt then
         Report_Rule_Violation (Unit, Node, No_Raise, "raise statement used");
      end if;
      if Rule_States (No_Exit) = Enabled and then Node.Kind = Libadalang.Common.Ada_Exit_Stmt then
         Report_Rule_Violation (Unit, Node, No_Exit, "exit statement used");
      end if;
      if Rule_States (No_Label) = Enabled and then Node.Kind = Libadalang.Common.Ada_Label then
         Report_Rule_Violation (Unit, Node, No_Label, "label used");
      end if;
      if Rule_States (No_Pragma) = Enabled and then Node.Kind = Libadalang.Common.Ada_Pragma_Node then
         Report_Rule_Violation (Unit, Node, No_Pragma, "pragma used");
      end if;
      if Rule_States (No_Access_To_Subp_Def) = Enabled and then Node.Kind = Libadalang.Common.Ada_Access_To_Subp_Def then
         Report_Rule_Violation (Unit, Node, No_Access_To_Subp_Def,
                                "access-to-subprogram type definition used");
      end if;

      Analyze_Bug_Finding_Node (Unit, Node);

      for I in 1 .. Node.Children_Count loop
         Evaluate_Node (Unit, Node.Child (I));
      end loop;
   end Evaluate_Node;

   procedure Process_File (Filename : String; Ctx : Libadalang.Analysis.Analysis_Context) is
      Unit : Libadalang.Analysis.Analysis_Unit;
   begin
      if not Ada.Directories.Exists (Filename) then
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "adalang-analyzer: File not found: " & Filename);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Source_File_Count := Source_File_Count + 1;
      Log_Verbose ("Parsing: " & Filename);

      Unit := Ctx.Get_From_File (Filename);

      if Unit.Has_Diagnostics then
         for Diagnostic of Libadalang.Analysis.Diagnostics (Unit) loop
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               Libadalang.Analysis.Format_GNU_Diagnostic
                 (Unit, Diagnostic));
         end loop;
      else
         Evaluate_Node (Unit, Unit.Root);
      end if;

   exception
      when Exc : others =>
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "Error processing " & Filename & ": " & Ada.Exceptions.Exception_Message (Exc));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Process_File;

   package File_Name_Vectors is new Ada.Containers.Indefinite_Vectors
     (Index_Type   => Positive,
      Element_Type => String);

   Files_To_Process : File_Name_Vectors.Vector;
   Argument_Count   : Natural := Ada.Command_Line.Argument_Count;
   Current_Arg      : Natural := 1;
   Options_Ended    : Boolean := False;
   Ctx              : Libadalang.Analysis.Analysis_Context;

begin
   while Current_Arg <= Argument_Count loop
      declare
         Arg : constant String := Ada.Command_Line.Argument (Current_Arg);
      begin
         if not Options_Ended then
            if Arg = "--" then
               Options_Ended := True;
            elsif Arg = "-h" or else Arg = "--help" or else Arg = "-help" then
               Show_Help_Flag := True;
            elsif Arg = "-version" then
               Show_Version := True;
            elsif Arg = "-list-checks" or else Arg = "-list-rules" then
               List_Checks_Only := True;
            elsif Arg = "-q" or else Arg = "-quiet" then
               Quiet_Mode := True;
            elsif Arg = "-v" or else Arg = "-verbose" then
               Verbose_Mode := True;
            elsif Arg = "-checks" then
               if Current_Arg = Argument_Count then
                  Ada.Text_IO.Put_Line ("adalang-analyzer: expected argument for -checks");
                  Invalid_Options := True;
               else
                  Parse_Checks_Option
                    ("-checks="
                     & Ada.Command_Line.Argument (Current_Arg + 1));
                  Current_Arg := Current_Arg + 1;
               end if;
            elsif Arg'Length > 8 and then Arg (Arg'First .. Arg'First + 7) = "-checks=" then
               Parse_Checks_Option (Arg);
            elsif Arg (Arg'First) = '+' or else Arg (Arg'First) = '-' then
               if Arg'Length > 2 and then Arg (Arg'First + 1) = 'R' then
                  Process_Command_Switch (Arg);
               else
                  Ada.Text_IO.Put_Line ("adalang-analyzer: unknown option '" & Arg & "'");
                  Invalid_Options := True;
               end if;
            else
               File_Name_Vectors.Append (Files_To_Process, Arg);
            end if;
         else
            File_Name_Vectors.Append (Files_To_Process, Arg);
         end if;
      end;
      Current_Arg := Current_Arg + 1;
   end loop;

   if Show_Help_Flag then
      Show_Help;
      return;
   elsif Show_Version then
      Print_Version;
      return;
   elsif Invalid_Options then
      Show_Help;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   elsif List_Checks_Only then
      Print_Check_List;
      return;
   elsif File_Name_Vectors.Is_Empty (Files_To_Process) then
      if Argument_Count > 0 then
         -- Options were provided, but no files
         null;
      else
         Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                               "adalang-analyzer: error: no source files provided.");
         Show_Help;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
      return;
   end if;

   Ctx := Libadalang.Analysis.Create_Context;

   for F of Files_To_Process loop
      Process_File (F, Ctx);
   end loop;

   if not Quiet_Mode then
      Ada.Text_IO.New_Line;
      Ada.Text_IO.Put_Line ("Files scanned : " & To_Decimal (Source_File_Count));
      Ada.Text_IO.Put_Line ("Violations    : " & To_Decimal (Violations));

      if Violations > 0 then
         Ada.Text_IO.Put_Line ("");
         Ada.Text_IO.Put_Line ("Violations by check:");

         for Rule in Rule_Kind loop
            if Rule_Violations (Rule) > 0 then
               Ada.Text_IO.Put_Line
                 ("  " & Ada.Strings.Unbounded.To_String (Rule_Infos (Rule).Name) &
                  " : " & To_Decimal (Rule_Violations (Rule)));
            end if;
         end loop;
      end if;
   end if;

   if Violations > 0 then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end if;

exception
   when E : others =>
      Ada.Text_IO.Put_Line (Ada.Text_IO.Standard_Error,
                            "Internal error: " & Ada.Exceptions.Exception_Information (E));
      Ada.Command_Line.Set_Exit_Status (2);
end Adalang_Analyzer;
