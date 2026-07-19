--  Copyright (C) 2024, AdaCore
--  Copyright (C) 2026, Spazio IT
--  Modified by Spazio IT in 2026.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Command_Line;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Text_IO;

with GPR2;
with GPR2.Build.Source;
with GPR2.Build.Source.Sets;
with GPR2.Options;
with GPR2.Project.Tree;
with GPR2.Project.View;

with Adalang_Analyzer.Config;
with Adalang_Analyzer.Text_Utils;

package body Adalang_Analyzer.Project_Files is

   use type GPR2.Language_Id;

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
     (Project_File : String;
      Files        : in out File_Name_Vectors.Vector;
      Seen         : in out File_Name_Vectors.Vector)
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
         Sources : constant GPR2.Build.Source.Sets.Object :=
           Tree.Root_Project.Sources;
      begin
         for Src of Sources loop
            if Src.Language = GPR2.Ada_Language then
               Append_Or_Replace_By_Simple_Name
                 (Files, String (Src.Path_Name.Value));
            end if;
         end loop;
      end;

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
