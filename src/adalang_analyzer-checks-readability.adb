--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Characters.Latin_1;
with Ada.Strings.Fixed;

with Langkit_Support.Slocs;
with Langkit_Support.Text;
with Libadalang.Common;

with Adalang_Analyzer.Ada_Text;   use Adalang_Analyzer.Ada_Text;
with Adalang_Analyzer.Checks.Policy_Support;
use Adalang_Analyzer.Checks.Policy_Support;
with Adalang_Analyzer.Config;     use Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;     use Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Checks.Readability is

   use type Libadalang.Analysis.Ada_Node;
   use type Libadalang.Common.Ada_Node_Kind_Type;
   use type Libadalang.Common.Token_Kind;
   use type Libadalang.Common.Token_Reference;

   subtype Token is Libadalang.Common.Token_Reference;

   function Kind_Of (T : Token) return Libadalang.Common.Token_Kind
   is (Libadalang.Common.Kind (Libadalang.Common.Data (T)));

   function Span
     (T : Token) return Langkit_Support.Slocs.Source_Location_Range
   is (Libadalang.Common.Sloc_Range (Libadalang.Common.Data (T)));

   function Start_Line (T : Token) return Natural
   is (Natural (Span (T).Start_Line));

   function End_Line (T : Token) return Natural
   is (Natural (Span (T).End_Line));

   function Token_Text (T : Token) return String
   is (Langkit_Support.Text.To_UTF8 (Libadalang.Common.Text (T)));

   procedure Report_At_Token
     (Unit    : Libadalang.Analysis.Analysis_Unit;
      T       : Token;
      Rule    : Rule_Kind;
      Message : String)
   is
      Where : constant Langkit_Support.Slocs.Source_Location_Range := Span (T);
   begin
      Report_Line_Violation
        (Filename    => Safe_Filename (Unit),
         Line_Number => Natural (Where.Start_Line),
         Column      => Natural (Where.Start_Column),
         Caret_Width =>
           (if Natural (Where.End_Line) = Natural (Where.Start_Line)
              and then Natural (Where.End_Column) >
                         Natural (Where.Start_Column)
            then Natural (Where.End_Column) - Natural (Where.Start_Column)
            else 1),
         Rule        => Rule,
         Message     => Message);
   end Report_At_Token;

   --  The line on which the code before T ends: 0 at the start of the
   --  unit, and never T's own line when what precedes it is a comment.
   function Previous_Code_Line (T : Token) return Natural is
      P : Token := Libadalang.Common.Previous (T);
   begin
      loop
         if P = Libadalang.Common.No_Token
           or else Kind_Of (P) = Libadalang.Common.Ada_Termination
         then
            return 0;
         elsif Kind_Of (P) = Libadalang.Common.Ada_Comment then
            return Start_Line (P) - 1;
         elsif Kind_Of (P) /= Libadalang.Common.Ada_Whitespace then
            return End_Line (P);
         end if;
         P := Libadalang.Common.Previous (P);
      end loop;
   end Previous_Code_Line;

   --  The line on which the code after T starts: 0 at the end of the
   --  unit, and never T's own line when what follows it is a comment.
   function Next_Code_Line (T : Token) return Natural is
      N : Token := Libadalang.Common.Next (T);
   begin
      loop
         if N = Libadalang.Common.No_Token
           or else Kind_Of (N) = Libadalang.Common.Ada_Termination
         then
            return 0;
         elsif Kind_Of (N) = Libadalang.Common.Ada_Comment then
            return Start_Line (N) + 1;
         elsif Kind_Of (N) /= Libadalang.Common.Ada_Whitespace then
            return Start_Line (N);
         end if;
         N := Libadalang.Common.Next (N);
      end loop;
   end Next_Code_Line;

   function Has_Prefix (Text : String; Prefix : String) return Boolean
   is (Text'Length >= Prefix'Length
       and then Text (Text'First .. Text'First + Prefix'Length - 1) = Prefix);

   function Is_Reserved_Word (Word : String) return Boolean is
      Words : constant String :=
        " abort abs abstract accept access aliased all and array at begin"
        & " body case constant declare delay delta digits do else elsif end"
        & " entry exception exit for function generic goto if in interface"
        & " is limited loop mod new not null of or others out overriding"
        & " package pragma private procedure protected raise range record"
        & " rem renames requeue return reverse select separate some subtype"
        & " synchronized tagged task terminate then type until use when"
        & " while with xor ";
   begin
      return Word'Length > 0
        and then Ada.Strings.Fixed.Index (Words, " " & Word & " ") > 0;
   end Is_Reserved_Word;

   --  Applies Process to each comma-separated, trimmed, non-empty item.
   procedure For_Each_Item
     (List    : String;
      Process : not null access procedure (Item : String))
   is
      Start : Positive := List'First;
   begin
      for I in List'First .. List'Last + 1 loop
         if I > List'Last or else List (I) = ',' then
            declare
               Item : constant String := Ada.Strings.Fixed.Trim
                 (List (Start .. I - 1), Ada.Strings.Both);
            begin
               if Item /= "" then
                  Process (Item);
               end if;
            end;
            Start := I + 1;
         end if;
      end loop;
   end For_Each_Item;

   --  True when the comment text Comment carries one of the annotation
   --  markers in Markers: the marker's first character directly after
   --  "--", and the rest of the marker after any blanks that follow.
   function Is_Annotated_Comment
     (Comment : String; Markers : String) return Boolean  --  adalang-analyzer: ignore Swappable_Parameters
   is
      Found : Boolean := False;

      procedure Try (Marker : String) is
         Rest_Start : Natural := Comment'First + 3;
      begin
         if Comment'Length < 3
           or else Comment (Comment'First + 2) /= Marker (Marker'First)
         then
            return;
         end if;

         while Rest_Start <= Comment'Last
           and then Comment (Rest_Start) in ' ' | Ada.Characters.Latin_1.HT
         loop
            Rest_Start := Rest_Start + 1;
         end loop;

         if Has_Prefix
              (Comment (Rest_Start .. Comment'Last),
               Marker (Marker'First + 1 .. Marker'Last))
         then
            Found := True;
         end if;
      end Try;
   begin
      For_Each_Item (Markers, Try'Access);
      return Found;
   end Is_Annotated_Comment;

   procedure Analyze_Header (Unit : Libadalang.Analysis.Analysis_Unit) is
      Raw    : constant String := Rule_Parameter (Missing_Header, "header", "");
      Header : String (1 .. Raw'Length);
      Last   : Natural := 0;
      I      : Positive := Raw'First;
   begin
      if Raw = "" then
         return;
      end if;

      --  "\n" in the parameter stands for a line break.
      while I <= Raw'Last loop
         Last := Last + 1;
         if Raw (I) = '\' and then I < Raw'Last and then Raw (I + 1) = 'n' then
            Header (Last) := Ada.Characters.Latin_1.LF;
            I := I + 2;
         else
            Header (Last) := Raw (I);
            I := I + 1;
         end if;
      end loop;

      if not Has_Prefix
               (Langkit_Support.Text.To_UTF8 (Unit.Text), Header (1 .. Last))
      then
         Report_Line_Violation
           (Filename    => Safe_Filename (Unit),
            Line_Number => 1,
            Column      => 1,
            Caret_Width => 1,
            Rule        => Missing_Header,
            Message     => "compilation unit does not start with the header");
      end if;
   end Analyze_Header;

   procedure Analyze_Tokens (Unit : Libadalang.Analysis.Analysis_Unit) is
      Markers : constant String := Rule_Parameter (Annotated_Comment, "s", "");
      T       : Token := Unit.First_Token;
      Previous_Kind : Libadalang.Common.Token_Kind :=
        Libadalang.Common.Ada_Termination;
   begin
      while T /= Libadalang.Common.No_Token loop
         declare
            Kind : constant Libadalang.Common.Token_Kind := Kind_Of (T);
            Wide : constant Langkit_Support.Text.Text_Type :=
              Libadalang.Common.Text (T);
         begin
            if Rule_States (Printable_ASCII) = Enabled then
               for C of Wide loop
                  if C not in ' ' .. '~'
                    and then C /= Wide_Wide_Character'Val (10)
                    and then C /= Wide_Wide_Character'Val (13)
                  then
                     Report_At_Token
                       (Unit, T, Printable_ASCII,
                        "character outside printable ASCII");
                     exit;
                  end if;
               end loop;
            end if;

            if Kind = Libadalang.Common.Ada_Comment then
               if Rule_States (End_Of_Line_Comment) = Enabled
                 and then Previous_Code_Line (T) = Start_Line (T)
               then
                  Report_At_Token
                    (Unit, T, End_Of_Line_Comment, "end of line comment");
               end if;

               if Rule_States (Annotated_Comment) = Enabled
                 and then Markers /= ""
                 and then Is_Annotated_Comment (Token_Text (T), Markers)
               then
                  Report_At_Token
                    (Unit, T, Annotated_Comment, "annotated comment");
               end if;
            elsif Rule_States (Lowercase_Keyword) = Enabled
              and then Kind /= Libadalang.Common.Ada_Whitespace
              and then Previous_Kind /= Libadalang.Common.Ada_Tick
            then
               declare
                  Text : constant String := Token_Text (T);
                  Low  : constant String :=
                    Ada.Characters.Handling.To_Lower (Text);
               begin
                  if Text /= Low and then Is_Reserved_Word (Low) then
                     Report_At_Token
                       (Unit, T, Lowercase_Keyword,
                        "reserved word " & Low & " is not in lower case");
                  end if;
               end;
            end if;

            Previous_Kind := Kind;
         end;
         T := Libadalang.Common.Next (T);
      end loop;
   end Analyze_Tokens;

   procedure Analyze_Unit (Unit : Libadalang.Analysis.Analysis_Unit) is
   begin
      if Rule_States (Missing_Header) = Enabled then
         Analyze_Header (Unit);
      end if;

      if Rule_States (Maximum_Lines) = Enabled then
         declare
            Limit : constant Natural :=
              Rule_Parameter (Maximum_Lines, "n", 10_000);
            Last  : Token := Unit.Last_Token;
         begin
            --  Report on the last token of the text, not the end marker.
            if Last /= Libadalang.Common.No_Token
              and then Kind_Of (Last) = Libadalang.Common.Ada_Termination
            then
               Last := Libadalang.Common.Previous (Last);
            end if;

            if Last /= Libadalang.Common.No_Token
              and then End_Line (Last) > Limit
            then
               Report_At_Token
                 (Unit, Last, Maximum_Lines,
                  "file has " & To_Decimal (End_Line (Last))
                  & " lines, more than " & To_Decimal (Limit));
            end if;
         end;
      end if;

      if Rule_States (Printable_ASCII) = Enabled
        or else Rule_States (End_Of_Line_Comment) = Enabled
        or else Rule_States (Annotated_Comment) = Enabled
        or else Rule_States (Lowercase_Keyword) = Enabled
      then
         Analyze_Tokens (Unit);
      end if;
   exception
      when Exc : others =>
         Note_Skipped_Check (Unit.Root, Exc);
   end Analyze_Unit;

   --  True when Digit_Text is digits from Valid in groups of Group
   --  separated by underscores, the first group holding 1 .. Group digits.
   function Is_Grouped
     (Digit_Text : String; Group : Positive; Hexadecimal : Boolean)
      return Boolean
   is
      Run   : Natural := 0;
      First : Boolean := True;
   begin
      if Digit_Text = "" then
         return False;
      end if;

      for C of Digit_Text loop
         if C = '_' then
            if (First and then Run not in 1 .. Group)
              or else (not First and then Run /= Group)
            then
               return False;
            end if;
            First := False;
            Run := 0;
         elsif C in '0' .. '9' or else (Hexadecimal and then C in 'A' .. 'Z')
         then
            Run := Run + 1;
         else
            return False;
         end if;
      end loop;

      return (if First then Run in 1 .. Group else Run = Group);
   end Is_Grouped;

   --  True when Text is "E", an optional sign and decimal digits, or empty.
   function Is_Exponent (Text : String) return Boolean is
      First : Positive;
   begin
      if Text = "" then
         return True;
      elsif Text (Text'First) /= 'E' or else Text'Length < 2 then
         return False;
      end if;

      First := Text'First + 1;
      if Text (First) in '+' | '-' then
         First := First + 1;
      end if;

      if First > Text'Last then
         return False;
      end if;

      for C of Text (First .. Text'Last) loop
         if C not in '0' .. '9' then
            return False;
         end if;
      end loop;
      return True;
   end Is_Exponent;

   --  True when the mantissa Text (with an optional fraction) is grouped.
   function Is_Grouped_Number
     (Text : String; Group : Positive; Hexadecimal : Boolean) return Boolean
   is
      Point : constant Natural := Ada.Strings.Fixed.Index (Text, ".");
   begin
      if Point = 0 then
         return Is_Grouped (Text, Group, Hexadecimal);
      else
         return Is_Grouped (Text (Text'First .. Point - 1), Group, Hexadecimal)
           and then Is_Grouped
                      (Text (Point + 1 .. Text'Last), Group, Hexadecimal);
      end if;
   end Is_Grouped_Number;

   --  The accepted numeric literal layout: decimal and base-8/10 digits in
   --  groups of three, base-2/16 digits in groups of four, upper-case
   --  extended digits and exponent letter, no other base.
   function Is_Well_Formed_Literal (Text : String) return Boolean is
      Open : constant Natural := Ada.Strings.Fixed.Index (Text, "#");
   begin
      if Open = 0 then
         declare
            Exponent : constant Natural := Ada.Strings.Fixed.Index (Text, "E");
            Mantissa_Last : constant Natural :=
              (if Exponent = 0 then Text'Last else Exponent - 1);
         begin
            return Is_Grouped_Number
                     (Text (Text'First .. Mantissa_Last), 3, False)
              and then (Exponent = 0
                        or else Is_Exponent (Text (Exponent .. Text'Last)));
         end;
      end if;

      declare
         Base  : constant String := Text (Text'First .. Open - 1);
         Close : constant Natural :=
           Ada.Strings.Fixed.Index (Text (Open + 1 .. Text'Last), "#");
         Group : Positive;
      begin
         if Close = 0 then
            return False;
         elsif Base = "2" or else Base = "16" then
            Group := 4;
         elsif Base = "8" or else Base = "10" then
            Group := 3;
         else
            return False;
         end if;

         return Is_Grouped_Number
                  (Text (Open + 1 .. Close - 1), Group, Base = "16")
           and then Is_Exponent (Text (Close + 1 .. Text'Last));
      end;
   end Is_Well_Formed_Literal;

   --  The position a parameter should take: in, access, in out, out, and
   --  last the parameters with a default.
   function Parameter_Rank
     (Spec : Libadalang.Analysis.Param_Spec) return Positive
   is
   begin
      if not Libadalang.Analysis.Is_Null (Spec.F_Default_Expr) then
         return 5;
      end if;

      case Spec.F_Mode.Kind is
         when Libadalang.Common.Ada_Mode_Out =>
            return 4;
         when Libadalang.Common.Ada_Mode_In_Out =>
            return 3;
         when Libadalang.Common.Ada_Mode_In =>
            return 1;
         when others =>
            if Spec.F_Type_Expr.Kind = Libadalang.Common.Ada_Anonymous_Type
              and then Spec.F_Type_Expr.As_Anonymous_Type.F_Type_Decl
                         .F_Type_Def.Kind in Libadalang.Common.Ada_Access_Def
            then
               return 2;
            end if;
            return 1;
      end case;
   end Parameter_Rank;

   procedure Analyze_Parameter_Order
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Rank     : constant Positive := Parameter_Rank (Node.As_Param_Spec);
      Siblings : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Seen     : Boolean := False;
   begin
      for I in 1 .. Siblings.Children_Count loop
         declare
            Sibling : constant Libadalang.Analysis.Ada_Node :=
              Siblings.Child (I);
         begin
            if Sibling = Node.As_Ada_Node then
               Seen := True;
            elsif Seen
              and then Sibling.Kind = Libadalang.Common.Ada_Param_Spec
              and then Parameter_Rank (Sibling.As_Param_Spec) < Rank
            then
               Report_Finding
                 (Unit, Node, Parameters_Out_Of_Order,
                  "parameter out of order");
               return;
            end if;
         end;
      end loop;
   end Analyze_Parameter_Order;

   --  The number of formal parameter names in Params that satisfy Counts.
   function Count_Parameters
     (Params : Libadalang.Analysis.Params;
      Counts : not null access function
        (Spec : Libadalang.Analysis.Param_Spec) return Boolean)
      return Natural
   is
      Total : Natural := 0;
   begin
      if Libadalang.Analysis.Is_Null (Params) then
         return 0;
      end if;

      for I in 1 .. Params.F_Params.Children_Count loop
         declare
            Spec : constant Libadalang.Analysis.Param_Spec :=
              Params.F_Params.Child (I).As_Param_Spec;
         begin
            if Counts (Spec) then
               Total := Total + Spec.F_Ids.Children_Count;
            end if;
         end;
      end loop;
      return Total;
   end Count_Parameters;

   function Is_Output
     (Spec : Libadalang.Analysis.Param_Spec) return Boolean
   is (Spec.F_Mode.Kind in Libadalang.Common.Ada_Mode_Out
         | Libadalang.Common.Ada_Mode_In_Out);

   function Has_Default
     (Spec : Libadalang.Analysis.Param_Spec) return Boolean
   is (not Libadalang.Analysis.Is_Null (Spec.F_Default_Expr));

   procedure Analyze_Out_Parameter_Count
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Limit : constant Natural :=
        Rule_Parameter (Maximum_Out_Parameters, "n", 3);
      Spec  : Libadalang.Analysis.Subp_Spec;
      Total : Natural;
   begin
      if Node.Kind in Libadalang.Common.Ada_Classic_Subp_Decl then
         Spec := Node.As_Classic_Subp_Decl.F_Subp_Spec;
      elsif Node.Kind = Libadalang.Common.Ada_Subp_Body_Stub then
         Spec := Node.As_Subp_Body_Stub.F_Subp_Spec;
      else
         Spec := Node.As_Base_Subp_Body.F_Subp_Spec;
      end if;

      Total := Count_Parameters (Spec.F_Subp_Params, Is_Output'Access);
      if Total <= Limit then
         return;
      end if;

      if Node.Kind not in Libadalang.Common.Ada_Classic_Subp_Decl
        and then not Libadalang.Analysis.Is_Null
                       (Node.As_Body_Node.P_Previous_Part)
      then
         return;
      end if;

      Report_Finding
        (Unit, Node.As_Basic_Decl.P_Defining_Name, Maximum_Out_Parameters,
         "subprogram has " & To_Decimal (Total)
         & " out or in out parameters, more than " & To_Decimal (Limit));
   end Analyze_Out_Parameter_Count;

   --  True when the comment that directly follows the begin before First
   --  names the unit: "begin -- Name".
   function Begin_Is_Marked (First : Token; Name : String) return Boolean is
      T : Token := Libadalang.Common.Previous (First);
   begin
      while T /= Libadalang.Common.No_Token
        and then Kind_Of (T) /= Libadalang.Common.Ada_Begin
      loop
         if Kind_Of (T) = Libadalang.Common.Ada_Comment then
            declare
               Before : constant Token :=
                 Libadalang.Common.Previous (Libadalang.Common.Previous (T));
               Text   : constant String := Token_Text (T);
            begin
               if Before /= Libadalang.Common.No_Token
                 and then Kind_Of (Before) = Libadalang.Common.Ada_Begin
               then
                  return Has_Suffix (Text, Name)
                    and then Text'Length >= Name'Length + 2
                    and then Has_Prefix (Text, "--")
                    and then (for all C of
                                Text (Text'First + 2 ..
                                      Text'Last - Name'Length) => C = ' ');
               end if;
            end;
         end if;
         T := Libadalang.Common.Previous (T);
      end loop;
      return False;
   end Begin_Is_Marked;

   --  The begin-marking and body-length checks on a handled sequence of
   --  statements.
   procedure Analyze_Body_Statements
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Owner     : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Has_Decls : Boolean := False;
      Begin_Tok : constant Token :=
        Libadalang.Common.Previous (Node.Token_Start, Exclude_Trivia => True);
   begin
      if Libadalang.Analysis.Is_Null (Owner) then
         return;
      end if;

      if Owner.Kind = Libadalang.Common.Ada_Subp_Body
        and then Rule_States (Maximum_Subprogram_Lines) = Enabled
      then
         declare
            Limit : constant Natural :=
              Rule_Parameter (Maximum_Subprogram_Lines, "n", 1_000);
            Lines : constant Natural :=
              End_Line (Node.Token_End) - Start_Line (Node.Token_Start) + 1;
         begin
            if Lines > Limit then
               Report_At_Token
                 (Unit, Begin_Tok, Maximum_Subprogram_Lines,
                  "subprogram body has " & To_Decimal (Lines)
                  & " lines, more than " & To_Decimal (Limit));
            end if;
         end;
      end if;

      if Rule_States (Uncommented_Begin) /= Enabled
        and then Rule_States (Uncommented_Begin_In_Package_Body) /= Enabled
      then
         return;
      end if;

      case Owner.Kind is
         when Libadalang.Common.Ada_Subp_Body =>
            Has_Decls :=
              Owner.As_Subp_Body.F_Decls.F_Decls.Children_Count > 0;
         when Libadalang.Common.Ada_Package_Body =>
            Has_Decls :=
              Owner.As_Package_Body.F_Decls.F_Decls.Children_Count > 0;
         when Libadalang.Common.Ada_Entry_Body =>
            Has_Decls :=
              Owner.As_Entry_Body.F_Decls.F_Decls.Children_Count > 0;
         when Libadalang.Common.Ada_Task_Body =>
            Has_Decls :=
              Owner.As_Task_Body.F_Decls.F_Decls.Children_Count > 0;
         when others =>
            return;
      end case;

      if not Has_Decls then
         return;
      end if;

      declare
         Name : constant String :=
           Node_Text (Owner.As_Basic_Decl.P_Defining_Name);
      begin
         if Begin_Is_Marked (Node.Token_Start, Name) then
            return;
         end if;

         if Rule_States (Uncommented_Begin) = Enabled then
            Report_At_Token
              (Unit, Begin_Tok, Uncommented_Begin,
               "begin is not marked with -- " & Name);
         end if;

         if Rule_States (Uncommented_Begin_In_Package_Body) = Enabled
           and then Owner.Kind = Libadalang.Common.Ada_Package_Body
         then
            Report_At_Token
              (Unit, Begin_Tok, Uncommented_Begin_In_Package_Body,
               "begin of package body is not marked with -- " & Name);
         end if;
      end;
   end Analyze_Body_Statements;

   procedure Analyze_End_Record
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Limit    : constant Natural :=
        Rule_Parameter (Uncommented_End_Record, "n", 10);
      Last     : constant Token := Node.Token_End;
      Last_Line : constant Natural := End_Line (Last);
      T        : Token;
   begin
      if Last_Line - Start_Line (Node.Token_Start) < Limit then
         return;
      end if;

      declare
         Name : constant String := Node_Text
           (Node.P_Semantic_Parent.As_Basic_Decl.P_Defining_Name);
      begin
         T := Libadalang.Common.Next
           (Libadalang.Common.Next (Libadalang.Common.Next (Last)));
         while T /= Libadalang.Common.No_Token
           and then Kind_Of (T) = Libadalang.Common.Ada_Whitespace
         loop
            T := Libadalang.Common.Next (T);
         end loop;

         if T /= Libadalang.Common.No_Token
           and then Kind_Of (T) = Libadalang.Common.Ada_Comment
           and then Start_Line (T) = Last_Line
         then
            declare
               Text : constant String := Token_Text (T);
               From : Natural := Text'First + 2;
            begin
               while From <= Text'Last and then Text (From) = ' ' loop
                  From := From + 1;
               end loop;

               if Has_Prefix (Text (From .. Text'Last), Name)
                 and then (From + Name'Length > Text'Last
                           or else Text (From + Name'Length) in ' ' | ',')
               then
                  return;
               end if;
            end;
         end if;

         Report_At_Token
           (Unit, Last, Uncommented_End_Record,
            "end record is not marked with -- " & Name);
      end;
   end Analyze_End_Record;

   function Is_Program_Unit
     (Kind : Libadalang.Common.Ada_Node_Kind_Type) return Boolean
   is (Kind in Libadalang.Common.Ada_Subp_Decl
         | Libadalang.Common.Ada_Abstract_Subp_Decl
         | Libadalang.Common.Ada_Base_Subp_Body
         | Libadalang.Common.Ada_Base_Package_Decl
         | Libadalang.Common.Ada_Package_Body
         | Libadalang.Common.Ada_Generic_Decl
         | Libadalang.Common.Ada_Generic_Instantiation
         | Libadalang.Common.Ada_Single_Task_Decl
         | Libadalang.Common.Ada_Task_Type_Decl_Range
         | Libadalang.Common.Ada_Task_Body
         | Libadalang.Common.Ada_Body_Stub
         | Libadalang.Common.Ada_Single_Protected_Decl
         | Libadalang.Common.Ada_Protected_Type_Decl);

   procedure Analyze_Object_Order
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Siblings : constant Libadalang.Analysis.Ada_Node := Node.Parent;
      Previous : Libadalang.Analysis.Ada_Node :=
        Libadalang.Analysis.No_Ada_Node;
      Current  : Libadalang.Analysis.Ada_Node := Node.Parent;
   begin
      if Libadalang.Analysis.Is_Null (Siblings) then
         return;
      end if;

      for I in 1 .. Siblings.Children_Count loop
         exit when Siblings.Child (I) = Node.As_Ada_Node;
         Previous := Siblings.Child (I);
      end loop;

      if Libadalang.Analysis.Is_Null (Previous)
        or else not Is_Program_Unit (Previous.Kind)
      then
         return;
      end if;

      --  Only inside a library unit body: the innermost enclosing
      --  subprogram or package body must itself be the library item.
      while not Libadalang.Analysis.Is_Null (Current)
        and then Current.Kind not in Libadalang.Common.Ada_Subp_Body
                   | Libadalang.Common.Ada_Package_Body
      loop
         Current := Current.Parent;
      end loop;

      if Libadalang.Analysis.Is_Null (Current)
        or else Libadalang.Analysis.Is_Null (Current.Parent)
        or else Current.Parent.Kind /= Libadalang.Common.Ada_Library_Item
      then
         return;
      end if;

      Report_Finding
        (Unit, Node.As_Basic_Decl.P_Defining_Name,
         Object_Declaration_Out_Of_Order,
         "object declared after the program unit at line "
         & To_Decimal (Start_Line (Previous.Token_Start)));
   end Analyze_Object_Order;

   function Is_Line_Construct
     (Node : Libadalang.Analysis.Ada_Node'Class) return Boolean
   is
      Kind : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
   begin
      if Kind in Libadalang.Common.Ada_Enum_Literal_Decl
           | Libadalang.Common.Ada_Param_Spec
           | Libadalang.Common.Ada_Discriminant_Spec
           | Libadalang.Common.Ada_For_Loop_Var_Decl
           | Libadalang.Common.Ada_Entry_Index_Spec
           | Libadalang.Common.Ada_Single_Task_Type_Decl
           | Libadalang.Common.Ada_Anonymous_Type_Decl
           | Libadalang.Common.Ada_Label_Decl
           | Libadalang.Common.Ada_Generic_Subp_Internal
           | Libadalang.Common.Ada_Concrete_Formal_Subp_Decl
           | Libadalang.Common.Ada_Extended_Return_Stmt_Object_Decl
           | Libadalang.Common.Ada_Named_Stmt_Decl
           | Libadalang.Common.Ada_Accept_Stmt_Body
        or else (Kind = Libadalang.Common.Ada_Generic_Package_Instantiation
                 and then not Libadalang.Analysis.Is_Null (Node.Parent)
                 and then Node.Parent.Kind in
                            Libadalang.Common.Ada_Generic_Formal)
      then
         return False;
      elsif Kind in Libadalang.Common.Ada_Use_Clause then
         return not Node.P_Matching_With_Use_Clause;
      end if;

      return Kind in Libadalang.Common.Ada_Stmt
        | Libadalang.Common.Ada_Basic_Decl
        | Libadalang.Common.Ada_Aspect_Clause
        | Libadalang.Common.Ada_Component_Clause
        | Libadalang.Common.Ada_Pragma_Node
        | Libadalang.Common.Ada_With_Clause;
   end Is_Line_Construct;

   procedure Analyze_Line_Sharing
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      First : Token := Node.Token_Start;
      Last  : Token := Node.Token_End;
   begin
      if not Is_Line_Construct (Node) then
         return;
      end if;

      --  A "private" library item starts at its private keyword, and a
      --  with clause extends over the use clause that follows it.
      if Node.Kind in Libadalang.Common.Ada_Basic_Decl
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind = Libadalang.Common.Ada_Library_Item
        and then Node.Parent.As_Library_Item.F_Has_Private.Kind =
                   Libadalang.Common.Ada_Private_Present
      then
         First := Node.Parent.As_Library_Item.F_Has_Private.Token_Start;
      elsif Node.Kind = Libadalang.Common.Ada_With_Clause then
         declare
            Following : constant Libadalang.Analysis.Ada_Node :=
              Node.Next_Sibling;
         begin
            if not Libadalang.Analysis.Is_Null (Following)
              and then Following.Kind in Libadalang.Common.Ada_Use_Clause
            then
               Last := Following.Token_End;
            end if;
         end;
      end if;

      if End_Line (Last) = Next_Code_Line (Last)
        or else Start_Line (First) = Previous_Code_Line (First)
      then
         Report_Finding
           (Unit, Node, One_Construct_Per_Line,
            "more than one construct on the same line");
      end if;
   end Analyze_Line_Sharing;

   --  The number of statements and declarations in and below Node.
   function Logical_Lines
     (Node : Libadalang.Analysis.Ada_Node'Class) return Natural
   is
      Kind  : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
      Total : Natural := 0;
   begin
      if Kind in Libadalang.Common.Ada_Stmt then
         if Kind not in Libadalang.Common.Ada_Label
              | Libadalang.Common.Ada_Terminate_Alternative
              | Libadalang.Common.Ada_Named_Stmt
         then
            Total := 1;
         end if;
      elsif Kind = Libadalang.Common.Ada_Exception_Handler then
         if not Libadalang.Analysis.Is_Null
                  (Node.As_Exception_Handler.F_Exception_Name)
         then
            Total := 1;
         end if;
      elsif Kind in Libadalang.Common.Ada_Basic_Decl
        and then Kind not in Libadalang.Common.Ada_Generic_Formal
                   | Libadalang.Common.Ada_Generic_Package_Internal
                   | Libadalang.Common.Ada_Anonymous_Type_Decl
                   | Libadalang.Common.Ada_Named_Stmt_Decl
                   | Libadalang.Common.Ada_Label_Decl
                   | Libadalang.Common.Ada_Single_Task_Type_Decl
                   | Libadalang.Common.Ada_Generic_Subp_Internal
      then
         Total := 1;
      end if;

      for I in 1 .. Node.Children_Count loop
         if not Libadalang.Analysis.Is_Null (Node.Child (I)) then
            Total := Total + Logical_Lines (Node.Child (I));
         end if;
      end loop;
      return Total;
   end Logical_Lines;

   procedure Analyze_Logical_Lines
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Limit : constant Natural := Rule_Parameter (Logical_SLOC, "n", 200);
      Total : constant Natural := Logical_Lines (Node);
   begin
      if Total > Limit then
         Adalang_Analyzer.Report.Report_Rule_Violation
           (Unit, Node, Logical_SLOC,
            "unit has " & To_Decimal (Total)
            & " logical source lines, more than " & To_Decimal (Limit));
      end if;
   end Analyze_Logical_Lines;

   procedure Analyze_Defining_Name
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Name : constant Libadalang.Analysis.Name := Node.As_Defining_Name.F_Name;
   begin
      if Rule_States (Maximum_Identifier_Length) = Enabled
        and then not Libadalang.Analysis.Is_Null (Node.Parent)
        and then Node.Parent.Kind /= Libadalang.Common.Ada_Enum_Literal_Decl
      then
         declare
            Limit  : constant Natural :=
              Rule_Parameter (Maximum_Identifier_Length, "n", 20);
            Simple : constant String :=
              (if Name.Kind = Libadalang.Common.Ada_Dotted_Name
               then Node_Text (Name.As_Dotted_Name.F_Suffix)
               else Node_Text (Name));
         begin
            if Simple'Length > Limit then
               Report_Finding
                 (Unit, Node, Maximum_Identifier_Length,
                  "identifier is longer than " & To_Decimal (Limit)
                  & " characters");
            end if;
         end;
      end if;

      if Rule_States (Forbidden_Identifier) = Enabled then
         declare
            Spelling : constant String := Canonical_Text (Name);
            Clash    : Boolean := False;

            procedure Compare (Item : String) is
            begin
               if Ada.Characters.Handling.To_Lower (Item) = Spelling then
                  Clash := True;
               end if;
            end Compare;
         begin
            For_Each_Item
              (Rule_Parameter (Forbidden_Identifier, "forbidden", ""),
               Compare'Access);
            if Clash then
               Report_Finding
                 (Unit, Node, Forbidden_Identifier,
                  "forbidden identifier " & Node_Text (Name) & " declared");
            end if;
         end;
      end if;
   end Analyze_Defining_Name;

   procedure Analyze_Node
     (Unit : Libadalang.Analysis.Analysis_Unit;
      Node : Libadalang.Analysis.Ada_Node'Class)
   is
      Kind : constant Libadalang.Common.Ada_Node_Kind_Type := Node.Kind;
   begin
      Guarded
        (Unit, Node, On (One_Construct_Per_Line), Analyze_Line_Sharing'Access);

      if Kind = Libadalang.Common.Ada_Defining_Name then
         begin
            Analyze_Defining_Name (Unit, Node);
         exception
            when Exc : others =>
               Note_Skipped_Check (Node, Exc);
         end;
      elsif Kind in Libadalang.Common.Ada_Num_Literal then
         if Rule_States (Numeric_Format) = Enabled
           and then not Is_Well_Formed_Literal (Node_Text (Node))
         then
            Report_Finding
              (Unit, Node, Numeric_Format,
               "numeric literal is not written in the standard format");
         end if;
      elsif Kind = Libadalang.Common.Ada_Param_Spec then
         Guarded
           (Unit, Node, On (Parameters_Out_Of_Order),
            Analyze_Parameter_Order'Access);
      elsif Kind = Libadalang.Common.Ada_Params then
         if Rule_States (Default_Parameter) = Enabled then
            declare
               Limit : constant Natural :=
                 Rule_Parameter (Default_Parameter, "n", 0);
               Total : constant Natural :=
                 Count_Parameters (Node.As_Params, Has_Default'Access);
            begin
               if Total > Limit then
                  Report_Finding
                    (Unit, Node, Default_Parameter,
                     To_Decimal (Total) & " parameters have a default "
                     & "value, more than " & To_Decimal (Limit));
               end if;
            end;
         end if;
      elsif Kind = Libadalang.Common.Ada_Handled_Stmts then
         begin
            Analyze_Body_Statements (Unit, Node);
         exception
            when Exc : others =>
               Note_Skipped_Check (Node, Exc);
         end;
      elsif Kind = Libadalang.Common.Ada_Record_Def then
         Guarded
           (Unit, Node, On (Uncommented_End_Record), Analyze_End_Record'Access);
      elsif Kind in Libadalang.Common.Ada_Object_Decl_Range then
         Guarded
           (Unit, Node, On (Object_Declaration_Out_Of_Order),
            Analyze_Object_Order'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Subp_Body
           | Libadalang.Common.Ada_Expr_Function
           | Libadalang.Common.Ada_Null_Subp_Decl
           | Libadalang.Common.Ada_Subp_Body_Stub
           | Libadalang.Common.Ada_Classic_Subp_Decl
      then
         Guarded
           (Unit, Node, On (Maximum_Out_Parameters),
            Analyze_Out_Parameter_Count'Access);
      end if;

      if Kind in Libadalang.Common.Ada_Generic_Package_Decl
           | Libadalang.Common.Ada_Package_Decl
           | Libadalang.Common.Ada_Package_Body
           | Libadalang.Common.Ada_Base_Subp_Body
           | Libadalang.Common.Ada_Task_Type_Decl_Range
           | Libadalang.Common.Ada_Single_Task_Decl
           | Libadalang.Common.Ada_Task_Body
           | Libadalang.Common.Ada_Single_Protected_Decl
           | Libadalang.Common.Ada_Protected_Type_Decl
           | Libadalang.Common.Ada_Protected_Body
      then
         Guarded (Unit, Node, On (Logical_SLOC), Analyze_Logical_Lines'Access);
      end if;
   end Analyze_Node;

end Adalang_Analyzer.Checks.Readability;
