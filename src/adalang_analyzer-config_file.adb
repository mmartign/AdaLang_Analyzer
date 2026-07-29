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

with Ada.Characters.Latin_1;
with Ada.Directories;
with Ada.Strings.Fixed;
with Ada.Text_IO;

package body Adalang_Analyzer.Config_File is

   function Resolve
     (Explicit_Path : String; No_Config : Boolean) return Resolution
   is
      use Ada.Strings.Unbounded;
   begin
      if Explicit_Path /= "" then
         return
           (Path  => To_Unbounded_String (Explicit_Path),
            Found => Ada.Directories.Exists (Explicit_Path));
      end if;

      if not No_Config
        and then Ada.Directories.Exists (Default_Config_File_Name)
      then
         return
           (Path  => To_Unbounded_String (Default_Config_File_Name),
            Found => True);
      end if;

      return (Path => Null_Unbounded_String, Found => False);
   end Resolve;

   function Load_Tokens
     (Path : String) return Project_Files.File_Name_Vectors.Vector
   is
      File   : Ada.Text_IO.File_Type;
      Tokens : Project_Files.File_Name_Vectors.Vector;

      --  Appends every whitespace-separated token found in Line.
      procedure Split_Into_Tokens (Line : String) is
         Start : Positive := Line'First;
      begin
         for Index in Line'Range loop
            if Line (Index) = ' '
              or else Line (Index) = Ada.Characters.Latin_1.HT
            then
               if Index > Start then
                  Project_Files.File_Name_Vectors.Append
                    (Tokens, Line (Start .. Index - 1));
               end if;
               Start := Index + 1;
            end if;
         end loop;

         if Start <= Line'Last then
            Project_Files.File_Name_Vectors.Append
              (Tokens, Line (Start .. Line'Last));
         end if;
      end Split_Into_Tokens;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String :=
              Ada.Strings.Fixed.Trim
                (Ada.Text_IO.Get_Line (File), Ada.Strings.Both);
         begin
            if Line /= "" and then Line (Line'First) /= '#' then
               Split_Into_Tokens (Line);
            end if;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return Tokens;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         raise;
   end Load_Tokens;

end Adalang_Analyzer.Config_File;
