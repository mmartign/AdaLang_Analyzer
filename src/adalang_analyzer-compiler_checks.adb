--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Adalang_Analyzer.Config;     use Adalang_Analyzer.Config;
with Adalang_Analyzer.Report;
with Adalang_Analyzer.Rules;      use Adalang_Analyzer.Rules;
with Adalang_Analyzer.Text_Utils; use Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Compiler_Checks is

   use type GNAT.OS_Lib.String_Access;

   package String_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   package File_Name_Vectors renames Project_Files.File_Name_Vectors;

   function Parameter (Rule : Rule_Kind; Name : String) return String
   is (Ada.Strings.Fixed.Trim
         (Rule_Parameter (Rule, Name, ""), Ada.Strings.Both));

   function Configured (Rule : Rule_Kind; Name : String) return Boolean
   is (Rule_States (Rule) = Enabled and then Parameter (Rule, Name) /= "");

   procedure Warn (Message : String) is
   begin
      Ada.Text_IO.Put_Line
        (Ada.Text_IO.Standard_Error, "adalang-analyzer: warning: " & Message);
   end Warn;

   --  Writes to Path one Restriction_Warnings pragma for each
   --  comma-separated entry of the restrictions parameter.
   procedure Write_Restrictions (Path : String) is
      List  : constant String :=
        Parameter (Compiler_Restriction, "restrictions");
      File  : Ada.Text_IO.File_Type;
      Start : Positive := List'First;
   begin
      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, Path);
      for I in List'First .. List'Last + 1 loop
         if I > List'Last or else List (I) = ',' then
            declare
               Item : constant String :=
                 Ada.Strings.Fixed.Trim
                   (List (Start .. I - 1), Ada.Strings.Both);
            begin
               if Item /= "" then
                  Ada.Text_IO.Put_Line
                    (File, "pragma Restriction_Warnings (" & Item & ");");
               end if;
            end;
            Start := I + 1;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
   end Write_Restrictions;

   --  Where to put the compiler's by-products: the user's temporary
   --  directory, or the current directory when none is set or it is gone.
   function Temporary_Directory return String is
      procedure Free (Value : in out GNAT.OS_Lib.String_Access)
        renames GNAT.OS_Lib.Free;
   begin
      for Name of String_Sets.To_Set ("TMPDIR").Union
                    (String_Sets.To_Set ("TEMP"))
      loop
         declare
            Value : GNAT.OS_Lib.String_Access := GNAT.OS_Lib.Getenv (Name);
            Text  : constant String := Value.all;
         begin
            Free (Value);
            if Text /= "" and then Ada.Directories.Exists (Text) then
               return Ada.Directories.Full_Name (Text);
            end if;
         end;
      end loop;
      return (if Ada.Directories.Exists ("/tmp") then "/tmp"
              else Ada.Directories.Current_Directory);
   end Temporary_Directory;

   --  The messages already reported, so that one located in a
   --  specification is not repeated for every unit that depends on it.
   Seen : String_Sets.Set;

   --  The full names of the analyzed files.
   Analyzed : String_Sets.Set;

   Messages_Outside : Natural := 0;

   --  Text without the " at file:line" the compiler ends a restriction
   --  message with: it names the temporary file the pragmas were in.
   function Without_Pragma_Location (Text : String) return String is
      At_Mark : constant Natural :=
        Ada.Strings.Fixed.Index (Text, """ at ", Ada.Strings.Backward);
   begin
      return (if At_Mark = 0 then Text else Text (Text'First .. At_Mark));
   end Without_Pragma_Location;

   --  Reports Line when it is a selected compiler message of the form
   --  "file:line:column: text [tag]" located in an analyzed file.
   procedure Report_Message (Line : String) is
      use Ada.Strings.Fixed;

      Warning_Mark : constant String := ": warning: ";
      Style_Mark   : constant String := ": (style) ";

      Mark : Natural := Index (Line, Warning_Mark);
      Rule : Rule_Kind := Compiler_Warning;
      Text_First : Natural;
   begin
      if Mark /= 0 then
         Text_First := Mark + Warning_Mark'Length;
      else
         Mark := Index (Line, Style_Mark);
         if Mark = 0 then
            return;
         end if;
         Rule := Compiler_Style_Check;
         Text_First := Mark + Style_Mark'Length;
      end if;

      declare
         --  "file:line:column" ends at Mark - 1; the file name may hold a
         --  colon itself (a drive letter), so the two numbers are taken
         --  from the right.
         Column_Colon : constant Natural :=
           Index (Line (Line'First .. Mark - 1), ":", Ada.Strings.Backward);
         Line_Colon   : constant Natural :=
           (if Column_Colon > Line'First
            then Index (Line (Line'First .. Column_Colon - 1), ":",
                        Ada.Strings.Backward)
            else 0);
         Tag_First    : constant Natural :=
           Index (Line, " [", Ada.Strings.Backward);
      begin
         if Line_Colon = 0 or else Tag_First < Text_First
           or else Line (Line'Last) /= ']'
         then
            return;
         end if;

         declare
            File : constant String := Line (Line'First .. Line_Colon - 1);
            Tag  : constant String := Line (Tag_First + 2 .. Line'Last - 1);
            Text : constant String := Line (Text_First .. Tag_First - 1);
         begin
            if Tag = "restriction warning" then
               Rule := Compiler_Restriction;
            elsif Rule = Compiler_Warning
              and then (Tag'Length < 7
                        or else Tag (Tag'First .. Tag'First + 5) /= "-gnatw")
            then
               --  A warning no -gnatw switch selects, such as one that is
               --  enabled by default, is not part of the check.
               return;
            end if;

            if Rule_States (Rule) /= Enabled or else Seen.Contains (Line) then
               return;
            end if;
            Seen.Include (Line);

            if not Ada.Directories.Exists (File)
              or else not Analyzed.Contains (Ada.Directories.Full_Name (File))
            then
               Messages_Outside := Messages_Outside + 1;
               return;
            end if;

            Report.Report_Violation_At
              (Filename    => File,
               Line_Number =>
                 Natural'Value (Line (Line_Colon + 1 .. Column_Colon - 1)),
               Column      =>
                 Natural'Value (Line (Column_Colon + 1 .. Mark - 1)),
               Caret_Width => 1,
               Rule        => Rule,
               Message     =>
                 (if Rule = Compiler_Restriction
                  then Without_Pragma_Location (Text)
                  else Text & " (" & Tag & ")"));
         end;
      end;
   exception
      when Constraint_Error =>
         --  Not a located message after all.
         Log_Verbose ("compiler checks: ignored line: " & Line);
   end Report_Message;

   procedure Report_Output (Path : String) is
      File : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return;
      end if;
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            if Line /= "" then
               Report_Message (Line);
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
   end Report_Output;

   --  Runs Program with Arguments, both output streams going to Output.
   --  False when the program reports failure, which for a compiler also
   --  means "the source has errors".
   function Run
     (Program   : String;
      Arguments : File_Name_Vectors.Vector;
      Output    : String) return Boolean
   is
      Args    : GNAT.OS_Lib.Argument_List
        (1 .. Natural (File_Name_Vectors.Length (Arguments)));
      Index   : Natural := 0;
      Success : Boolean := False;
      Code    : Integer := 0;
   begin
      for Argument of Arguments loop
         Index := Index + 1;
         Args (Index) := new String'(Argument);
      end loop;
      GNAT.OS_Lib.Spawn
        (Program_Name => Program,
         Args         => Args,
         Output_File  => Output,
         Success      => Success,
         Return_Code  => Code,
         Err_To_Out   => True);
      for Argument of Args loop
         GNAT.OS_Lib.Free (Argument);
      end loop;
      return Success and then Code = 0;
   end Run;

   --  Name next to gnatls when it is there, so that "gcc" is GNAT's and not
   --  another compiler that comes first on the path; otherwise Name on the
   --  path, or null.
   function Locate_Tool (Name : String) return GNAT.OS_Lib.String_Access is
      Gnatls : GNAT.OS_Lib.String_Access :=
        GNAT.OS_Lib.Locate_Exec_On_Path ("gnatls");
   begin
      if Gnatls /= null then
         declare
            Beside : constant String :=
              Ada.Directories.Compose
                (Ada.Directories.Containing_Directory (Gnatls.all), Name);
            Found  : GNAT.OS_Lib.String_Access :=
              GNAT.OS_Lib.Locate_Exec_On_Path (Beside);
         begin
            GNAT.OS_Lib.Free (Gnatls);
            if Found /= null then
               return Found;
            end if;
            GNAT.OS_Lib.Free (Found);
         end;
      end if;
      return GNAT.OS_Lib.Locate_Exec_On_Path (Name);
   end Locate_Tool;

   procedure Analyze (Sources : Source_Set) is
      Files         : File_Name_Vectors.Vector renames Sources.Files;
      Lookup_Files  : File_Name_Vectors.Vector renames Sources.Lookup_Files;
      Projects      : File_Name_Vectors.Vector renames Sources.Projects;
      Scenario_Vars : File_Name_Vectors.Vector renames Sources.Scenario_Vars;

      Warnings     : constant Boolean :=
        Configured (Compiler_Warning, "options");
      Style        : constant Boolean :=
        Configured (Compiler_Style_Check, "options");
      Restrictions : constant Boolean :=
        Configured (Compiler_Restriction, "restrictions");

      Work_Dir : constant String :=
        Ada.Directories.Compose
          (Temporary_Directory,
           "adalang-analyzer-compiler-"
           & To_Decimal
               (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id)));
      Output   : constant String := Ada.Directories.Compose (Work_Dir, "out");
      Pragmas  : constant String :=
        Ada.Directories.Compose (Work_Dir, "restrictions.adc");

      Switches : File_Name_Vectors.Vector;
      Failures : Natural := 0;

      procedure Compile_Projects (Gprbuild : String) is
      begin
         for Project of Projects loop
            declare
               Arguments : File_Name_Vectors.Vector;
            begin
               Arguments.Append ("-q");
               Arguments.Append ("-c");
               Arguments.Append ("-k");
               Arguments.Append ("-u");
               Arguments.Append ("-P" & Project);
               Arguments.Append ("--relocate-build-tree=" & Work_Dir);
               for Scenario of Scenario_Vars loop
                  Arguments.Append ("-X" & Scenario);
               end loop;
               Arguments.Append ("-cargs:Ada");
               Arguments.Append_Vector (Switches);
               if not Run (Gprbuild, Arguments, Output) then
                  Failures := Failures + 1;
               end if;
               Report_Output (Output);
            end;
         end loop;
      end Compile_Projects;

      procedure Compile_Files (Gcc : String) is
         Directories : String_Sets.Set;
         Includes    : File_Name_Vectors.Vector;
      begin
         for File of Lookup_Files loop
            declare
               Directory : constant String :=
                 Ada.Directories.Containing_Directory
                   (Ada.Directories.Full_Name (File));
            begin
               if not Directories.Contains (Directory) then
                  Directories.Include (Directory);
                  Includes.Append ("-I" & Directory);
               end if;
            end;
         end loop;

         for File of Files loop
            declare
               Arguments : File_Name_Vectors.Vector;
            begin
               Arguments.Append ("-c");
               Arguments.Append_Vector (Switches);
               Arguments.Append_Vector (Includes);
               Arguments.Append ("-o");
               --  The compiler insists on an object named after the source.
               Arguments.Append
                 (Ada.Directories.Compose
                    (Work_Dir, Ada.Directories.Base_Name (File) & ".o"));
               Arguments.Append (Ada.Directories.Full_Name (File));
               if not Run (Gcc, Arguments, Output) then
                  Failures := Failures + 1;
               end if;
               Report_Output (Output);
            end;
         end loop;
      end Compile_Files;

      Tool : GNAT.OS_Lib.String_Access;
   begin
      if not Warnings and then not Style and then not Restrictions then
         return;
      end if;

      Tool := Locate_Tool (if Projects.Is_Empty then "gcc" else "gprbuild");
      if Tool = null then
         Warn
           ("the compiler checks need "
            & (if Projects.Is_Empty then "gcc" else "gprbuild")
            & " on the path; Compiler_Warning, Compiler_Style_Check and "
            & "Compiler_Restriction report nothing");
         return;
      end if;

      Seen.Clear;
      Analyzed.Clear;
      Messages_Outside := 0;
      for File of Files loop
         if Ada.Directories.Exists (File) then
            Analyzed.Include (Ada.Directories.Full_Name (File));
         end if;
      end loop;

      Ada.Directories.Create_Path (Work_Dir);

      --  Semantic checks only, full path names in messages, the switch
      --  that enables each warning shown after it. Whatever the project
      --  selects is cancelled first: warnings back to normal mode and all
      --  off, style checks off.
      Switches.Append ("-gnatc");
      Switches.Append ("-gnatef");
      Switches.Append ("-gnatwn");
      Switches.Append ("-gnatwA");
      Switches.Append ("-gnatw.d");
      Switches.Append ("-gnatyN");
      if Warnings then
         Switches.Append ("-gnatw" & Parameter (Compiler_Warning, "options"));
      end if;
      if Style then
         Switches.Append
           ("-gnaty" & Parameter (Compiler_Style_Check, "options"));
      end if;
      if Restrictions then
         Write_Restrictions (Pragmas);
         Switches.Append ("-gnatec=" & Pragmas);
      end if;

      if Projects.Is_Empty then
         Compile_Files (Tool.all);
      else
         Compile_Projects (Tool.all);
      end if;
      GNAT.OS_Lib.Free (Tool);

      Ada.Directories.Delete_Tree (Work_Dir);

      if Failures > 0 then
         Warn
           ("the compiler checks could not compile "
            & To_Decimal (Failures)
            & (if Projects.Is_Empty then " file(s)" else " project(s)")
            & " cleanly; their messages may be incomplete");
      end if;
      Log_Verbose
        ("compiler checks: " & To_Decimal (Messages_Outside)
         & " message(s) located outside the analyzed files");
   exception
      when others =>
         if Ada.Directories.Exists (Work_Dir) then
            Ada.Directories.Delete_Tree (Work_Dir);
         end if;
         raise;
   end Analyze;

end Adalang_Analyzer.Compiler_Checks;
