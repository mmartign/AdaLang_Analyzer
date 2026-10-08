--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Text_IO;

with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Gnatprove_Import is

   use type Ada.Containers.Count_Type;
   use type Proof.Obligation_Kind;

   --  What GNATprove calls a check, and the kind of AdaLang obligation
   --  that stands for one. The first label found in a message is the one
   --  taken, so "loop invariant initialization" comes before "loop
   --  invariant". The table is that of benchmarks/gnatprove_gap_ledger.py.
   type Label_Entry is record
      Text     : Unbounded_String;
      Has_Kind : Boolean := False;
      Kind     : Proof.Obligation_Kind := Proof.Assertion_Check;
   end record;

   function Of_Kind
     (Text : String; Kind : Proof.Obligation_Kind) return Label_Entry
   is ((Text => To_Unbounded_String (Text), Has_Kind => True, Kind => Kind));

   function No_Kind (Text : String) return Label_Entry
   is ((Text => To_Unbounded_String (Text), others => <>));

   Object_Initialization : constant String := "initialization of";

   Labels : constant array (Positive range <>) of Label_Entry :=
     (Of_Kind ("loop invariant initialization",
               Proof.Loop_Invariant_Initialization),
      Of_Kind ("loop invariant in first iteration",
               Proof.Loop_Invariant_Initialization),
      Of_Kind ("loop invariant preservation",
               Proof.Loop_Invariant_Preservation),
      Of_Kind ("loop invariant", Proof.Loop_Invariant_Preservation),
      Of_Kind ("loop variant", Proof.Loop_Variant_Check),
      No_Kind ("refined post"),
      Of_Kind ("postcondition", Proof.Postcondition_Check),
      Of_Kind ("precondition", Proof.Precondition_Check),
      No_Kind ("contract case"),
      No_Kind ("contract or exit cases"),
      No_Kind ("contract cases"),
      No_Kind ("default initial condition"),
      Of_Kind ("assertion", Proof.Assertion_Check),
      Of_Kind ("overflow check", Proof.Integer_Overflow_Check),
      Of_Kind ("division check", Proof.Division_By_Zero_Check),
      Of_Kind ("divide by zero", Proof.Division_By_Zero_Check),
      Of_Kind ("index check", Proof.Index_Check),
      Of_Kind ("range check", Proof.Range_Check),
      Of_Kind ("discriminant check", Proof.Discriminant_Check),
      Of_Kind ("length check", Proof.Length_Check),
      No_Kind ("predicate check"),
      No_Kind ("invariant check"),
      No_Kind ("tag check"),
      No_Kind ("pointer dereference check"),
      No_Kind ("null exclusion check"),
      No_Kind ("accessibility check"),
      Of_Kind ("initialization check", Proof.Initialization_Check),
      Of_Kind (Object_Initialization, Proof.Initialization_Check),
      Of_Kind ("might not be initialized", Proof.Initialization_Check),
      Of_Kind ("is not initialized", Proof.Initialization_Check),
      No_Kind ("resource or memory leak"),
      No_Kind ("non-aliasing"),
      No_Kind ("aliasing"),
      Of_Kind ("Always_Terminates", Proof.Termination_Check),
      Of_Kind ("data dependencies", Proof.Data_Dependencies_Check),
      Of_Kind ("flow dependencies", Proof.Flow_Dependencies_Check),
      No_Kind ("unchecked conversion"),
      No_Kind ("Container_Aggregates annotation"));

   --  How a message that goes on from the one before, or tells of the run
   --  and not of a check, begins.
   Not_A_Check : constant array (Positive range <>) of Unbounded_String :=
     (To_Unbounded_String ("in "),
      To_Unbounded_String ("during "),
      To_Unbounded_String ("when "),
      To_Unbounded_String ("after "),
      To_Unbounded_String ("for "),
      To_Unbounded_String ("analyzing "),
      To_Unbounded_String ("add a contract"),
      To_Unbounded_String ("unrolling "),
      To_Unbounded_String ("cannot unroll"),
      To_Unbounded_String ("local subprogram"),
      To_Unbounded_String ("no contextual analysis"),
      To_Unbounded_String ("justified that"));

   type Severity is (Info, Low, Medium, High);

   function Severity_Text (Item : Severity) return String
   is (case Item is
          when Info   => "info",
          when Low    => "low",
          when Medium => "medium",
          when High   => "high");

   type Place is record
      Filename : Unbounded_String;
      Line     : Natural := 0;
      Column   : Natural := 0;
   end record;

   function Image (Where : Place) return String
   is (To_String (Where.Filename) & ":" &
       Text_Utils.To_Decimal (Where.Line) & ":" &
       Text_Utils.To_Decimal (Where.Column));

   function Place_Of (Item : Check) return Place
   is ((Filename => Item.Filename, Line => Item.Line, Column => Item.Column));

   --  Path without its directories, whichever way they are separated.
   function Simple_Name (Path : String) return String is
   begin
      for Index in reverse Path'Range loop
         if Path (Index) in '/' | '\' then
            return Path (Index + 1 .. Path'Last);
         end if;
      end loop;
      return Path;
   end Simple_Name;

   Decimal_Base : constant := 10;
   Most_Digits  : constant := 9;

   --  The number written at Position, which is moved past it. Found is
   --  False when no digit is there, or more than a line or a column has.
   procedure Scan_Number
     (Text     : String;
      Position : in out Positive;
      Value    : out Natural;
      Found    : out Boolean)
   is
      Digit_Count : Natural := 0;
   begin
      Value := 0;
      while Position <= Text'Last
        and then Text (Position) in '0' .. '9'
        and then Digit_Count < Most_Digits
      loop
         Value :=
           Value * Decimal_Base +
           (Character'Pos (Text (Position)) - Character'Pos ('0'));
         Position := Position + 1;
         Digit_Count := Digit_Count + 1;
      end loop;
      Found :=
        Digit_Count > 0
        and then (Position > Text'Last
                  or else Text (Position) not in '0' .. '9');
   end Scan_Number;

   --  A line of the form "<file>:<line>:<column>: <severity>: <text>",
   --  read at the first place from the left where it reads so.
   type Message is record
      Found   : Boolean := False;
      Where   : Place;
      Is_Info : Boolean := False;
      First   : Positive := 1;
      --  Where the text begins in the line.
   end record;

   function Message_Of (Line : String) return Message is
   begin
      for Index in Line'Range loop
         if Line (Index) = ':' then
            declare
               Position  : Positive := Index + 1;
               Row       : Natural;
               Col       : Natural;
               Has_Row   : Boolean;
               Has_Col   : Boolean := False;
            begin
               Scan_Number (Line, Position, Row, Has_Row);
               if Has_Row
                 and then Position <= Line'Last
                 and then Line (Position) = ':'
               then
                  Position := Position + 1;
                  Scan_Number (Line, Position, Col, Has_Col);
               end if;

               if Has_Col then
                  for Level in Severity loop
                     declare
                        Marker : constant String :=
                          ": " & Severity_Text (Level) & ": ";
                        Last   : constant Natural :=
                          Position + Marker'Length - 1;
                     begin
                        if Last <= Line'Last
                          and then Line (Position .. Last) = Marker
                        then
                           return
                             (Found   => True,
                              Where   =>
                                (Filename =>
                                   To_Unbounded_String
                                     (Simple_Name
                                        (Line (Line'First .. Index - 1))),
                                 Line     => Row,
                                 Column   => Col),
                              Is_Info => Level = Info,
                              First   => Last + 1);
                        end if;
                     end;
                  end loop;
               end if;
            end;
         end if;
      end loop;
      return (others => <>);
   end Message_Of;

   --  What a message says before its remarks, without the names it
   --  quotes: the text up to the first " [", each quoted name left out. A
   --  division check that "might fail [possible fix: add precondition
   --  ...]" is not a precondition, nor is the initialization of
   --  "precondition_met".
   function Said (Text : String) return String is
      Result    : String (1 .. Text'Length);
      Last      : Natural := 0;
      In_Quotes : Boolean := False;
   begin
      for Index in Text'Range loop
         exit when not In_Quotes
           and then Text (Index) = '['
           and then Index > Text'First
           and then Text (Index - 1) = ' ';

         if Text (Index) = '"' then
            In_Quotes := not In_Quotes;
         end if;
         if not In_Quotes or else Text (Index) = '"' then
            Last := Last + 1;
            Result (Last) := Text (Index);
         end if;
      end loop;
      return Result (1 .. Last);
   end Said;

   function Continues_Another (Text : String) return Boolean is
   begin
      for Prefix of Not_A_Check loop
         if Text'Length >= Length (Prefix)
           and then Text (Text'First .. Text'First + Length (Prefix) - 1) =
             To_String (Prefix)
         then
            return True;
         end if;
      end loop;
      return False;
   end Continues_Another;

   package Check_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Check);
   package Name_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Unbounded_String);
   package Index_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Positive,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Imported is record
      Known  : Boolean := False;
      Result : Verdict := Not_Proved;
   end record;
   package Imported_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Imported);

   Checks   : Check_Vectors.Vector;
   Places   : Index_Maps.Map;
   --  A place and a label, to the check of the log that is there:
   --  GNATprove repeats the check of a generic unit for each instance.
   Logs     : Name_Vectors.Vector;
   Verdicts : Imported_Vectors.Vector;
   Summed   : Summary;

   procedure Add_Line (Line : String) is
      Read : constant Message := Message_Of (Line);
   begin
      if not Read.Found or else Read.Where.Filename = Null_Unbounded_String
      then
         return;
      end if;

      declare
         Text   : constant String := Line (Read.First .. Line'Last);
         Result : constant Verdict :=
           (if Ada.Strings.Fixed.Index (Text, "justified") > 0
            then Justified
            elsif Read.Is_Info then Proved
            else Not_Proved);
      begin
         if Continues_Another (Text) then
            return;
         end if;

         for Label of Labels loop
            if Ada.Strings.Fixed.Index (Said (Text), To_String (Label.Text))
              > 0
            then
               declare
                  Key      : constant String :=
                    Image (Read.Where) & ":" & To_String (Label.Text);
                  Position : constant Index_Maps.Cursor := Places.Find (Key);
               begin
                  if Index_Maps.Has_Element (Position) then
                     declare
                        Seen : Check :=
                          Checks (Index_Maps.Element (Position));
                     begin
                        Seen.Instances := Seen.Instances + 1;
                        Seen.Result := Verdict'Max (Seen.Result, Result);
                        Checks.Replace_Element
                          (Index_Maps.Element (Position), Seen);
                     end;
                  else
                     Checks.Append
                       ((Filename => Read.Where.Filename,
                         Line     => Read.Where.Line,
                         Column   => Read.Where.Column,
                         Label    => Label.Text,
                         Has_Kind => Label.Has_Kind,
                         Kind     => Label.Kind,
                         Result   => Result,
                         others   => <>));
                     Places.Insert (Key, Checks.Last_Index);
                  end if;
               end;
               return;
            end if;
         end loop;
      end;
   end Add_Line;

   procedure Load (Filename : String) is
      File : Ada.Text_IO.File_Type;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);
      Logs.Append (To_Unbounded_String (Filename));
      while not Ada.Text_IO.End_Of_File (File) loop
         Add_Line (Ada.Text_IO.Get_Line (File));
      end loop;
      Ada.Text_IO.Close (File);
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Load;

   function Active return Boolean is (not Logs.Is_Empty);

   function Log_Count return Natural is (Natural (Logs.Length));

   function Log_Name (Index : Positive) return String
   is (To_String (Logs (Index)));

   --  Where an object is as good as the worst of the obligations about it,
   --  the worst comes first.
   function Rank (Status : Proof.Obligation_Status) return Natural
   is (case Status is
          when Proof.Definite_Error => 0,
          when Proof.Unproved       => 1,
          when Proof.Unsupported    => 2,
          when Proof.Unreachable    => 3,
          when Proof.Proved_Safe    => 4);

   procedure Pair is
      Count : constant Natural := Proof.Count;

      package Index_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Positive);
      package Group_Maps is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type        => String,
         Element_Type    => Index_Vectors.Vector,
         Hash            => Ada.Strings.Hash,
         Equivalent_Keys => "=",
         "="             => Index_Vectors."=");
      package Name_Maps is new Ada.Containers.Indefinite_Hashed_Maps
        (Key_Type        => String,
         Element_Type    => String,
         Hash            => Ada.Strings.Hash,
         Equivalent_Keys => "=");

      --  What the pairing needs of an obligation.
      type Brief is record
         Column : Natural := 0;
         Status : Proof.Obligation_Status := Proof.Unproved;
         Used   : Boolean := False;
      end record;
      package Brief_Vectors is new Ada.Containers.Vectors
        (Index_Type => Positive, Element_Type => Brief);

      Briefs     : Brief_Vectors.Vector;
      By_Place   : Group_Maps.Map;
      --  File, line and kind, to the obligations there.
      By_Subject : Group_Maps.Map;
      --  A declaration, to the initialization checks about what it
      --  declares.
      Files      : Name_Maps.Map;
      --  The simple name of each file with an obligation, to its full
      --  name; to no name at all when two files have the simple name.

      procedure Add
        (Map : in out Group_Maps.Map; Key : String; Index : Positive)
      is
         Position : Group_Maps.Cursor := Map.Find (Key);
      begin
         if not Group_Maps.Has_Element (Position) then
            Map.Insert (Key, Index_Vectors.Empty_Vector);
            Position := Map.Find (Key);
         end if;
         Map.Reference (Position).Append (Index);
      end Add;

      procedure Note_File (Full : String) is
         Name     : constant String := Simple_Name (Full);
         Position : constant Name_Maps.Cursor := Files.Find (Name);
      begin
         if not Name_Maps.Has_Element (Position) then
            Files.Insert (Name, Full);
         elsif Name_Maps.Element (Position) /= Full then
            Files.Replace_Element (Position, "");
         end if;
      end Note_File;

      function Place_Key (Item : Check) return String
      is (To_String (Item.Filename) & ":" &
          Text_Utils.To_Decimal (Item.Line) & ":" &
          Proof.Kind_Name (Item.Kind));

      function Name_Is_Unique (Item : Check) return Boolean is
         Position : constant Name_Maps.Cursor :=
           Files.Find (To_String (Item.Filename));
      begin
         return not Name_Maps.Has_Element (Position)
           or else Name_Maps.Element (Position) /= "";
      end Name_Is_Unique;

      --  The obligation not yet taken that Item is nearest to, at its
      --  column only when Exact; 0 when there is none.
      function Candidate (Item : Check; Exact : Boolean) return Natural is
         Position : constant Group_Maps.Cursor :=
           By_Place.Find (Place_Key (Item));
         Best     : Natural := 0;
         Nearest  : Natural := Natural'Last;
      begin
         if not Group_Maps.Has_Element (Position) then
            return 0;
         end if;

         for Index of By_Place.Constant_Reference (Position) loop
            declare
               Distance : constant Natural :=
                 abs (Briefs (Index).Column - Item.Column);
            begin
               if not Briefs (Index).Used
                 and then (Distance = 0 or else not Exact)
                 and then Distance < Nearest
               then
                  Best := Index;
                  Nearest := Distance;
               end if;
            end;
         end loop;
         return Best;
      end Candidate;

      procedure Take (Position : Positive; Exact : Boolean) is
         Item   : Check := Checks (Position);
         Chosen : Natural := 0;
      begin
         if Item.Has_Kind
           and then Item.Pairing /= Paired
           and then Name_Is_Unique (Item)
         then
            Chosen := Candidate (Item, Exact);
         end if;

         if Chosen /= 0 then
            Briefs.Reference (Chosen).Used := True;
            Verdicts.Replace_Element
              (Chosen, (Known => True, Result => Item.Result));
            Item.Pairing := Paired;
            Item.Obligation := Chosen;
            Item.Status := Briefs (Chosen).Status;
            Checks.Replace_Element (Position, Item);
         end if;
      end Take;

      --  The obligations about the object whose initialization Item is.
      procedure Take_Object (Position : Positive) is
         Item  : Check := Checks (Position);
         Found : constant Group_Maps.Cursor :=
           By_Subject.Find (Image (Place_Of (Item)));
      begin
         if not Group_Maps.Has_Element (Found)
           or else not Name_Is_Unique (Item)
         then
            return;
         end if;

         Item.Obligation := By_Subject.Constant_Reference (Found).First_Element;
         for Index of By_Subject.Constant_Reference (Found) loop
            Briefs.Reference (Index).Used := True;
            Verdicts.Replace_Element
              (Index, (Known => True, Result => Item.Result));
            if Rank (Briefs (Index).Status) <
              Rank (Briefs (Item.Obligation).Status)
            then
               Item.Obligation := Index;
            end if;
         end loop;
         Item.Pairing := Paired;
         Item.Grouped :=
           Natural (By_Subject.Constant_Reference (Found).Length);
         Item.Status := Briefs (Item.Obligation).Status;
         Checks.Replace_Element (Position, Item);
      end Take_Object;

      procedure Classify (Position : Positive) is
         Item : Check := Checks (Position);
      begin
         if Item.Pairing = Paired then
            return;
         elsif not Name_Is_Unique (Item) then
            Item.Pairing := File_Name_Not_Unique;
         elsif not Files.Contains (To_String (Item.Filename)) then
            Item.Pairing := File_Without_Obligation;
         elsif not Item.Has_Kind then
            Item.Pairing := No_Such_Kind;
         else
            Item.Pairing := No_Obligation_Here;
         end if;
         Checks.Replace_Element (Position, Item);
      end Classify;

      procedure Sum (Item : Check) is
      begin
         Summed.Checks := Summed.Checks + 1;
         case Item.Result is
            when Proved =>
               Summed.Proved := Summed.Proved + 1;
               if Item.Pairing /= Paired then
                  Summed.Without_Obligation := Summed.Without_Obligation + 1;
               else
                  case Item.Status is
                     when Proof.Proved_Safe =>
                        Summed.Proved_By_Both := Summed.Proved_By_Both + 1;
                     when Proof.Definite_Error =>
                        Summed.Error_Where_Proved :=
                          Summed.Error_Where_Proved + 1;
                     when Proof.Unproved
                        | Proof.Unreachable
                        | Proof.Unsupported =>
                        Summed.On_Obligation := Summed.On_Obligation + 1;
                  end case;
               end if;
            when Justified =>
               Summed.Justified := Summed.Justified + 1;
            when Not_Proved =>
               Summed.Not_Proved := Summed.Not_Proved + 1;
               if Item.Pairing = Paired
                 and then Item.Status in Proof.Proved_Safe
               then
                  Summed.Proved_Where_Not_Proved :=
                    Summed.Proved_Where_Not_Proved + 1;
               end if;
         end case;
      end Sum;
   begin
      Summed := (others => <>);
      Verdicts :=
        Imported_Vectors.To_Vector
          (New_Item => (others => <>),
           Length   => Ada.Containers.Count_Type (Count));
      Briefs.Reserve_Capacity (Ada.Containers.Count_Type (Count));

      for Index in 1 .. Count loop
         declare
            Item : constant Proof.Obligation := Proof.Element (Index);
            Full : constant String := To_String (Item.Location.Filename);
         begin
            Briefs.Append
              ((Column => Item.Location.Column,
                Status => Item.Status,
                Used   => False));
            Note_File (Full);
            Add
              (By_Place,
               Simple_Name (Full) & ":" &
               Text_Utils.To_Decimal (Item.Location.Line) & ":" &
               Proof.Kind_Name (Item.Kind),
               Index);
            if Item.Kind = Proof.Initialization_Check
              and then Item.Subject.Line /= 0
            then
               Add
                 (By_Subject,
                  Image
                    ((Filename =>
                        To_Unbounded_String
                          (Simple_Name (To_String (Item.Subject.Filename))),
                      Line     => Item.Subject.Line,
                      Column   => Item.Subject.Column)),
                  Index);
            end if;
         end;
      end loop;

      for Position in Checks.First_Index .. Checks.Last_Index loop
         if To_String (Checks (Position).Label) = Object_Initialization then
            Take_Object (Position);
         end if;
      end loop;

      for Exact in reverse Boolean loop
         for Position in Checks.First_Index .. Checks.Last_Index loop
            Take (Position, Exact);
         end loop;
      end loop;

      for Position in Checks.First_Index .. Checks.Last_Index loop
         Classify (Position);
         Sum (Checks (Position));
      end loop;

      for Item of Verdicts loop
         if Item.Known then
            Summed.Obligations_With_Verdict :=
              Summed.Obligations_With_Verdict + 1;
         end if;
      end loop;
   end Pair;

   function Check_Count return Natural is (Natural (Checks.Length));

   function Element (Index : Positive) return Check is (Checks (Index));

   function Has_Verdict (Obligation : Positive) return Boolean
   is (Obligation <= Verdicts.Last_Index
       and then Verdicts (Obligation).Known);

   function Verdict_Of (Obligation : Positive) return Verdict
   is (if Has_Verdict (Obligation) then Verdicts (Obligation).Result
       else Not_Proved);

   function Verdict_Name (Item : Verdict) return String
   is (case Item is
          when Proved     => "proved",
          when Justified  => "justified",
          when Not_Proved => "not-proved");

   function Outcome_Name (Item : Check) return String
   is (case Item.Pairing is
          when Paired                  => Proof.Status_Name (Item.Status),
          when No_Obligation_Here      => "no obligation here",
          when No_Such_Kind            => "no such obligation kind",
          when File_Without_Obligation => "file without any obligation",
          when File_Name_Not_Unique    => "file name not unique");

   function Totals return Summary is (Summed);

   procedure Reset is
   begin
      Checks.Clear;
      Places.Clear;
      Logs.Clear;
      Verdicts.Clear;
      Summed := (others => <>);
   end Reset;

end Adalang_Analyzer.Gnatprove_Import;
