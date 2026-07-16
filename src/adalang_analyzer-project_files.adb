--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Latin_1;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with Adalang_Analyzer.Config;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Project_Files is

   use type Ada.Directories.File_Kind;

   function Directory_Name_Of (Path : String) return String is
      Last_Slash : Natural := 0;
   begin
      for I in Path'Range loop
         if Path (I) = '/' then
            Last_Slash := I;
         end if;
      end loop;

      if Last_Slash = 0 then
         return ".";
      else
         return Path (Path'First .. Last_Slash - 1);
      end if;
   end Directory_Name_Of;

   function Join_Path (Dir : String; Name : String) return String is
   begin
      if Dir = "" or else Dir = "." then
         return Name;
      elsif Dir (Dir'Last) = '/' then
         return Dir & Name;
      else
         return Dir & "/" & Name;
      end if;
   end Join_Path;

   function Vector_Contains
     (Items : File_Name_Vectors.Vector; Item : String) return Boolean is
   begin
      for I of Items loop
         if I = Item then
            return True;
         end if;
      end loop;
      return False;
   end Vector_Contains;

   --  Adds Name, replacing any existing entry with the same simple file
   --  name. This gives an extending project's own sources priority over
   --  the same-named files inherited from the project it extends.
   procedure Append_Or_Replace_By_Simple_Name
     (Files : in out File_Name_Vectors.Vector; Name : String)
   is
      Target : constant String := Ada.Directories.Simple_Name (Name);
   begin
      for Index in File_Name_Vectors.First_Index (Files) ..
                   File_Name_Vectors.Last_Index (Files)
      loop
         if Ada.Directories.Simple_Name
              (File_Name_Vectors.Element (Files, Index)) = Target
         then
            File_Name_Vectors.Replace_Element (Files, Index, Name);
            return;
         end if;
      end loop;

      File_Name_Vectors.Append (Files, Name);
   end Append_Or_Replace_By_Simple_Name;

   --  Walks Dir (recursively when Recursive) collecting *.adb/*.ads files.
   procedure Collect_Ada_Sources  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Dir : String; Recursive : Boolean; Files : in out File_Name_Vectors.Vector)
   is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      if not Ada.Directories.Exists (Dir)
        or else Ada.Directories.Kind (Dir) /= Ada.Directories.Directory
      then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: warning: project source directory not found: "
            & Dir);
         return;
      end if;

      Ada.Directories.Start_Search
        (Search, Dir, "*",
         (Ada.Directories.Ordinary_File => True,
          Ada.Directories.Directory     => True,
          Ada.Directories.Special_File  => False));

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);

         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Ada.Directories.Kind (Item) = Ada.Directories.Directory then
               if Recursive and then Name /= "." and then Name /= ".." then
                  Collect_Ada_Sources (Join_Path (Dir, Name), True, Files);
               end if;
            elsif Text_Utils.Has_Suffix (Name, ".adb")
              or else Text_Utils.Has_Suffix (Name, ".ads")
            then
               declare
                  Full : constant String := Join_Path (Dir, Name);
               begin
                  if not Vector_Contains (Files, Full) then
                     File_Name_Vectors.Append (Files, Full);
                  end if;
               end;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
   exception
      when others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: warning: could not read directory: " & Dir);
   end Collect_Ada_Sources;

   --  A tiny lexer for the subset of GPR syntax this reader understands:
   --  identifiers, double-quoted string literals (with "" escaping), and
   --  single-character punctuation. "--" starts a comment to end of line.
   type Gpr_Token_Kind is
     (Gpr_Tok_Identifier, Gpr_Tok_String, Gpr_Tok_Symbol, Gpr_Tok_End);

   type Gpr_Token is record
      Kind : Gpr_Token_Kind := Gpr_Tok_End;
      Text : Unbounded_String := Null_Unbounded_String;
   end record;

   function Gpr_Ident_Equals (Left : String; Right : String) return Boolean is
   begin
      if Left'Length /= Right'Length then
         return False;
      end if;

      for I in 0 .. Left'Length - 1 loop
         if Text_Utils.Lower_Char (Left (Left'First + I)) /=
            Text_Utils.Lower_Char (Right (Right'First + I))
         then
            return False;
         end if;
      end loop;

      return True;
   end Gpr_Ident_Equals;

   procedure Gpr_Skip_Trivia (Text : String; Pos : in out Positive) is  --  adalang-analyzer: ignore Cyclomatic_Complexity
   begin
      loop
         if Pos > Text'Last then
            return;
         elsif Text (Pos) = ' ' or else Text (Pos) = Ada.Characters.Latin_1.HT
           or else Text (Pos) = Ada.Characters.Latin_1.LF
           or else Text (Pos) = Ada.Characters.Latin_1.CR
         then
            Pos := Pos + 1;
         elsif Pos < Text'Last and then Text (Pos) = '-'
           and then Text (Pos + 1) = '-'
         then
            while Pos <= Text'Last
              and then Text (Pos) /= Ada.Characters.Latin_1.LF
            loop
               Pos := Pos + 1;
            end loop;
         else
            return;
         end if;
      end loop;
   end Gpr_Skip_Trivia;

   function Gpr_Next_Token
     (Text : String; Pos : in out Positive) return Gpr_Token is
   begin
      Gpr_Skip_Trivia (Text, Pos);

      if Pos > Text'Last then
         return (Kind => Gpr_Tok_End, Text => Null_Unbounded_String);
      end if;

      if Text (Pos) in 'A' .. 'Z' | 'a' .. 'z' then
         declare
            Start : constant Positive := Pos;
         begin
            while Pos <= Text'Last
              and then Text (Pos) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_'
            loop
               Pos := Pos + 1;
            end loop;

            return (Kind => Gpr_Tok_Identifier,
                    Text => To_Unbounded_String (Text (Start .. Pos - 1)));
         end;
      end if;

      if Text (Pos) = '"' then
         declare
            Result : Unbounded_String;
         begin
            Pos := Pos + 1;

            while Pos <= Text'Last loop
               if Text (Pos) = '"' then
                  if Pos < Text'Last and then Text (Pos + 1) = '"' then
                     Append (Result, '"');
                     Pos := Pos + 2;  --  adalang-analyzer: ignore Magic_Number
                  else
                     Pos := Pos + 1;
                     exit;  --  adalang-analyzer: ignore No_Exit
                  end if;
               else
                  Append (Result, Text (Pos));
                  Pos := Pos + 1;
               end if;
            end loop;

            return (Kind => Gpr_Tok_String, Text => Result);
         end;
      end if;

      declare
         Symbol : constant String := Text (Pos .. Pos);
      begin
         Pos := Pos + 1;
         return (Kind => Gpr_Tok_Symbol, Text => To_Unbounded_String (Symbol));
      end;
   end Gpr_Next_Token;

   --  Reads either a single string or a parenthesized, comma-separated
   --  string list, as used on the right of "use" in a GPR attribute.
   --  Anything else (a variable reference, concatenation, ...) is simply
   --  not collected, consistent with this reader's best-effort scope.
   procedure Gpr_Read_String_List
     (Text : String; Pos : in out Positive; Values : in out File_Name_Vectors.Vector)
   is
      Tok : Gpr_Token := Gpr_Next_Token (Text, Pos);
   begin
      if Tok.Kind = Gpr_Tok_String then
         File_Name_Vectors.Append (Values, To_String (Tok.Text));
      elsif Tok.Kind = Gpr_Tok_Symbol and then To_String (Tok.Text) = "(" then
         loop
            Tok := Gpr_Next_Token (Text, Pos);
            exit when Tok.Kind = Gpr_Tok_End;  --  adalang-analyzer: ignore No_Exit

            if Tok.Kind = Gpr_Tok_String then
               File_Name_Vectors.Append (Values, To_String (Tok.Text));
            elsif Tok.Kind = Gpr_Tok_Symbol and then To_String (Tok.Text) = ")" then
               exit;  --  adalang-analyzer: ignore No_Exit
            end if;
         end loop;
      end if;
   end Gpr_Read_String_List;

   procedure Load_Project_File  --  adalang-analyzer: ignore Cyclomatic_Complexity
     (Project_File : String;
      Files        : in out File_Name_Vectors.Vector;
      Seen         : in out File_Name_Vectors.Vector)
   is
      Actual : constant String :=
        (if Text_Utils.Has_Suffix (Project_File, ".gpr") then Project_File
         else Project_File & ".gpr");
   begin
      if Vector_Contains (Seen, Actual) then
         return;
      end if;
      File_Name_Vectors.Append (Seen, Actual);

      if not Ada.Directories.Exists (Actual) then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: project file not found: " & Actual);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      Config.Log_Verbose ("Reading project: " & Actual);

      declare
         Project_Dir : constant String := Directory_Name_Of (Actual);

         function Resolve (Spec : String) return String is
         begin
            if Spec = "" then
               return Project_Dir;
            elsif Spec (Spec'First) = '/' then
               return Spec;
            else
               return Join_Path (Project_Dir, Spec);
            end if;
         end Resolve;

         Input  : Ada.Text_IO.File_Type;
         Buffer : Unbounded_String;
         Pos    : Positive := 1;

         Dir_Specs      : File_Name_Vectors.Vector;
         File_Specs     : File_Name_Vectors.Vector;
         Excluded_Specs : File_Name_Vectors.Vector;
         Extends_Spec   : Unbounded_String := Null_Unbounded_String;
         Collected      : File_Name_Vectors.Vector;
      begin
         Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Actual);
         while not Ada.Text_IO.End_Of_File (Input) loop
            Append (Buffer, Ada.Text_IO.Get_Line (Input));
            Append (Buffer, Ada.Characters.Latin_1.LF);
         end loop;
         Ada.Text_IO.Close (Input);

         declare
            Source : constant String := To_String (Buffer);
         begin
            loop
               declare
                  Tok : constant Gpr_Token := Gpr_Next_Token (Source, Pos);
               begin
                  exit when Tok.Kind = Gpr_Tok_End;  --  adalang-analyzer: ignore No_Exit

                  if Tok.Kind = Gpr_Tok_Identifier
                    and then Gpr_Ident_Equals (To_String (Tok.Text), "for")
                  then
                     declare
                        Attr_Tok : constant Gpr_Token :=
                          Gpr_Next_Token (Source, Pos);
                     begin
                        if Attr_Tok.Kind = Gpr_Tok_Identifier then
                           declare
                              Use_Tok : constant Gpr_Token :=
                                Gpr_Next_Token (Source, Pos);
                           begin
                              if Use_Tok.Kind = Gpr_Tok_Identifier
                                and then Gpr_Ident_Equals
                                           (To_String (Use_Tok.Text), "use")
                              then
                                 declare
                                    Attr_Name : constant String :=
                                      To_String (Attr_Tok.Text);
                                    Values : File_Name_Vectors.Vector;
                                 begin
                                    Gpr_Read_String_List (Source, Pos, Values);

                                    if Gpr_Ident_Equals
                                         (Attr_Name, "Source_Dirs")
                                    then
                                       for V of Values loop
                                          File_Name_Vectors.Append
                                            (Dir_Specs, V);
                                       end loop;
                                    elsif Gpr_Ident_Equals
                                            (Attr_Name, "Source_Files")
                                    then
                                       for V of Values loop
                                          File_Name_Vectors.Append
                                            (File_Specs, V);
                                       end loop;
                                    elsif Gpr_Ident_Equals
                                            (Attr_Name, "Excluded_Source_Files")
                                      or else Gpr_Ident_Equals
                                                (Attr_Name,
                                                 "Locally_Removed_Files")
                                    then
                                       for V of Values loop
                                          File_Name_Vectors.Append
                                            (Excluded_Specs, V);
                                       end loop;
                                    end if;
                                 end;
                              end if;
                           end;
                        end if;
                     end;
                  elsif Tok.Kind = Gpr_Tok_Identifier
                    and then Gpr_Ident_Equals (To_String (Tok.Text), "extends")
                  then
                     declare
                        Str_Tok : constant Gpr_Token :=
                          Gpr_Next_Token (Source, Pos);
                     begin
                        if Str_Tok.Kind = Gpr_Tok_String then
                           Extends_Spec := Str_Tok.Text;
                        end if;
                     end;
                  end if;
               end;
            end loop;
         end;

         --  Follow the extension chain first so the child project's own
         --  sources can override same-named files inherited from the base.
         if Length (Extends_Spec) > 0 then
            Load_Project_File
              (Resolve (To_String (Extends_Spec)), Files, Seen);
         end if;

         if File_Name_Vectors.Is_Empty (Dir_Specs) then
            File_Name_Vectors.Append (Dir_Specs, "");
         end if;

         for Spec of Dir_Specs loop
            declare
               Recursive : Boolean := False;
               Base      : Unbounded_String := To_Unbounded_String (Spec);
            begin
               if Text_Utils.Has_Suffix (Spec, "**") then
                  Recursive := True;  --  adalang-analyzer: ignore Dead_Store
                  Base := To_Unbounded_String
                    (Spec (Spec'First .. Spec'Last - 2));  --  adalang-analyzer: ignore Magic_Number

                  if Length (Base) > 0
                    and then Element (Base, Length (Base)) = '/'
                  then
                     Base := To_Unbounded_String
                       (Slice (Base, 1, Length (Base) - 1));
                  end if;
               end if;

               Collect_Ada_Sources
                 (Resolve (To_String (Base)), Recursive, Collected);
            end;
         end loop;

         if not File_Name_Vectors.Is_Empty (File_Specs) then
            declare
               Filtered : File_Name_Vectors.Vector;
            begin
               for F of Collected loop
                  if Vector_Contains
                       (File_Specs, Ada.Directories.Simple_Name (F))
                  then
                     File_Name_Vectors.Append (Filtered, F);
                  end if;
               end loop;
               Collected := Filtered;
            end;
         end if;

         for F of Collected loop
            if not Vector_Contains
                     (Excluded_Specs, Ada.Directories.Simple_Name (F))
            then
               Append_Or_Replace_By_Simple_Name (Files, F);
            end if;
         end loop;
      end;
   end Load_Project_File;

end Adalang_Analyzer.Project_Files;
