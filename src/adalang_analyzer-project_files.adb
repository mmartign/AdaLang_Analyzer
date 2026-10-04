--  AdaLang Analyzer
--
--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--
--  Derived from AdaCore's libadalang-tools and substantially extended,
--  integrated, validated, and maintained by Spazio IT as part of the
--  independent AdaLang Analyzer project.
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Hash;
with Ada.Text_IO;

with GPR2;
with GPR2.Build.Source;
with GPR2.Build.Source.Sets;
with GPR2.Options;
with GPR2.Path_Name;
with GPR2.Project.Registry.Attribute;
with GPR2.Project.Tree;
with GPR2.Project.View;

with Adalang_Analyzer.Config;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Project_Files is

   use type GPR2.Language_Id;

   package PRA renames GPR2.Project.Registry.Attribute;

   --  Sources of the projects whose configuration pragmas turn SPARK_Mode
   --  on.
   SPARK_Sources : File_Name_Vectors.Vector;
   Import_Sources : File_Name_Vectors.Vector;

   --  True when the configuration pragma file at Path holds "pragma
   --  SPARK_Mode;" or "pragma SPARK_Mode (On);". Comments are ignored, as
   --  are case and spacing.
   function File_Sets_SPARK_Mode (Path : String) return Boolean is
      File  : Ada.Text_IO.File_Type;
      Found : Boolean := False;
   begin
      if not Ada.Directories.Exists (Path) then
         return False;
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Found and then not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line    : constant String := Ada.Text_IO.Get_Line (File);
            Compact : String (1 .. Line'Length);
            Length  : Natural := 0;
         begin
            for Index in Line'Range loop
               exit when Line (Index) = '-'
                 and then Index < Line'Last
                 and then Line (Index + 1) = '-';
               if Line (Index) not in ' ' | ASCII.HT | ASCII.CR then
                  Length := Length + 1;
                  Compact (Length) :=
                    Ada.Characters.Handling.To_Lower (Line (Index));
               end if;
            end loop;
            Found := Compact (1 .. Length) in
              "pragmaspark_mode;" | "pragmaspark_mode(on);";
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return Found;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return False;
   end File_Sets_SPARK_Mode;

   --  True when View names a configuration pragma file, through Attribute,
   --  that turns SPARK_Mode on.
   function View_Sets_SPARK_Mode
     (View      : GPR2.Project.View.Object;
      Attribute : GPR2.Q_Attribute_Id) return Boolean
   is
   begin
      if not View.Has_Attribute (Attribute) then
         return False;
      end if;

      declare
         Name : constant String :=
           String (View.Attribute (Attribute).Value.Text);
      begin
         return Name /= ""
           and then File_Sets_SPARK_Mode
             (if Name (Name'First) = '/' then Name
              else View.Dir_Name.Compose
                (GPR2.Filename_Type (Name)).String_Value);
      end;
   exception
      when others =>
         return False;
   end View_Sets_SPARK_Mode;

   function Lookup_Sources
     (Files : File_Name_Vectors.Vector) return File_Name_Vectors.Vector
   is
      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type        => String,
         Hash                => Ada.Strings.Hash,
         Equivalent_Elements => "=");

      Known  : Name_Sets.Set;
      Result : File_Name_Vectors.Vector := Files;
   begin
      for F of Files loop
         Known.Include (Ada.Directories.Simple_Name (F));
      end loop;

      for F of Import_Sources loop
         if not Known.Contains (Ada.Directories.Simple_Name (F)) then
            Known.Include (Ada.Directories.Simple_Name (F));
            File_Name_Vectors.Append (Result, F);
         end if;
      end loop;
      return Result;
   end Lookup_Sources;

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

   function Under_Project_SPARK_Mode (Filename : String) return Boolean is
     (Vector_Contains (SPARK_Sources, Filename));

   --  Keep the historical command-line behavior when explicit files and a
   --  project both name the same source. GPR2 itself has already resolved
   --  source visibility within the project tree at this point.
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

   procedure Load_Project_File
     (Project_File  : String;
      Files         : in out File_Name_Vectors.Vector;
      Seen          : in out File_Name_Vectors.Vector;
      Scenario_Vars : File_Name_Vectors.Vector := File_Name_Vectors.Empty_Vector)
   is
      Actual : constant String :=
        (if Text_Utils.Has_Suffix (Project_File, ".gpr") then Project_File
         else Project_File & ".gpr");
      Options : GPR2.Options.Object;
      Tree    : GPR2.Project.Tree.Object;
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

      Config.Log_Verbose ("Reading project with GPR2: " & Actual);
      Options.Add_Switch (GPR2.Options.P, Actual);

      for Var of Scenario_Vars loop
         Config.Log_Verbose ("Applying scenario variable: " & Var);
         Options.Add_Switch (GPR2.Options.X, Var);
      end loop;

      if not Tree.Load
               (Options, Artifacts_Info_Level => GPR2.Sources_Only)
      then
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: could not load project: " & Actual);
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: hint: configure the project's GPR environment"
            & " (for Alire projects, use `alr exec -- ./bin/"
            & "adalang_analyzer ...`)");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         return;
      end if;

      declare
         Sources  : constant GPR2.Build.Source.Sets.Object :=
           Tree.Root_Project.Sources;
         In_SPARK : constant Boolean :=
           View_Sets_SPARK_Mode
             (Tree.Root_Project, PRA.Compiler.Local_Configuration_Pragmas)
           or else View_Sets_SPARK_Mode
             (Tree.Root_Project, PRA.Builder.Global_Configuration_Pragmas);
      begin
         for Src of Sources loop
            if Src.Language = GPR2.Ada_Language then
               Append_Or_Replace_By_Simple_Name
                 (Files, String (Src.Path_Name.Value));
               if In_SPARK then
                  File_Name_Vectors.Append
                    (SPARK_Sources, String (Src.Path_Name.Value));
               end if;
            end if;
         end loop;
      end;

      --  The other projects of the tree only serve name resolution.
      for View of Tree loop
         if not GPR2.Project.View."=" (View, Tree.Root_Project)
           and then not View.Is_Runtime
         then
            for Src of View.Sources loop
               if Src.Language = GPR2.Ada_Language then
                  File_Name_Vectors.Append
                    (Import_Sources, String (Src.Path_Name.Value));
               end if;
            end loop;
         end if;
      end loop;

      Tree.Unload;
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "adalang-analyzer: could not load project " & Actual & ": "
            & Ada.Exceptions.Exception_Message (Error));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   end Load_Project_File;

end Adalang_Analyzer.Project_Files;
