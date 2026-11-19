--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  AdaLang Analyzer is developed and supported by Spazio IT.
--  This project is not endorsed or sponsored by AdaCore.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.UTF_Encoding.Conversions;
with Ada.Strings.UTF_Encoding.Wide_Strings;

with GNAT.Directory_Operations;
with GNAT.OS_Lib;

with Adalang_Analyzer.Config;

package body Adalang_Analyzer.ObjectAda_Projects is

   use Ada.Strings.Unbounded;

   package Names renames Project_Files.File_Name_Vectors;

   package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   --  A project file is a few kilobytes; one this large is something else.
   Largest_Project : constant := 64 * 1024 * 1024;

   --  One source as the project lists it.
   type Listed_File is record
      Absolute : Unbounded_String;
      --  Where it was when the project was last saved: "C:\Ada\x\a.adb".
      Name     : Unbounded_String;
      --  The name the IDE shows: "a.adb", in the case it was added with.
      Relative : Unbounded_String;
      --  From the target's library directory: "..\a.adb".
   end record;

   package Listed_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Listed_File);

   --  What a project file says, before anything is looked for on this
   --  host.
   type Contents is record
      Target      : Unbounded_String;
      Files       : Listed_Vectors.Vector;
      Library_Dir : Unbounded_String;
      --  The simple name of the first target's library directory, such as
      --  "app-Win32(Intel)-Debug", or "" when it cannot be read.
      Search_Path : Names.Vector;
      --  The entries of the first target's library search path.
   end record;

   function Lower (Text : String) return String
     renames Ada.Characters.Handling.To_Lower;

   function Same_Name (Left, Right : String) return Boolean is
     (Lower (Left) = Lower (Right));
   --  File names on Windows do not depend on case.

   function Is_ObjectAda_Project_Name (Name : String) return Boolean is
     (Name'Length > 4
      and then Lower (Name (Name'Last - 3 .. Name'Last)) = ".prj");

   -----------------------------------------------------------------------
   --  Reading the archive
   -----------------------------------------------------------------------

   function Byte (Data : String; Index : Integer) return Natural is
     (if Index in Data'Range then Character'Pos (Data (Index))
      else raise Format_Error with "the file ends too early");

   function Word (Data : String; Index : Integer) return Natural is
     (Byte (Data, Index) + 256 * Byte (Data, Index + 1));

   function Double_Word (Data : String; Index : Integer) return Natural is
      Low  : constant Natural := Word (Data, Index);
      High : constant Natural := Word (Data, Index + 2);
   begin
      --  No string in a file of Largest_Project bytes is longer.
      if High > Largest_Project / 65_536 then
         raise Format_Error with "a string is longer than the file";
      end if;
      return Low + 65_536 * High;
   end Double_Word;

   --  The Unicode characters Windows code page 1252 gives the bytes 16#80#
   --  to 16#9F#; the others are those of Latin-1. The page is the one of
   --  Western European editions of Windows, where ObjectAda wrote ANSI
   --  strings in it.
   type Code_Point_Table is array (16#80# .. 16#9F#) of Natural;
   Windows_1252 : constant Code_Point_Table :=
     (16#20AC#, 16#0081#, 16#201A#, 16#0192#, 16#201E#, 16#2026#, 16#2020#,
      16#2021#, 16#02C6#, 16#2030#, 16#0160#, 16#2039#, 16#0152#, 16#008D#,
      16#017D#, 16#008F#, 16#0090#, 16#2018#, 16#2019#, 16#201C#, 16#201D#,
      16#2022#, 16#2013#, 16#2014#, 16#02DC#, 16#2122#, 16#0161#, 16#203A#,
      16#0153#, 16#009D#, 16#017E#, 16#0178#);

   --  Bytes in Windows code page 1252, as UTF-8.
   function From_ANSI (Bytes : String) return String is
      Wide : Wide_String (1 .. Bytes'Length);
      Last : Natural := 0;
   begin
      if (for all C of Bytes => Character'Pos (C) < 16#80#) then
         return Bytes;
      end if;
      for C of Bytes loop
         Last := Last + 1;
         Wide (Last) :=
           Wide_Character'Val
             (if Character'Pos (C) in Windows_1252'Range
              then Windows_1252 (Character'Pos (C))
              else Character'Pos (C));
      end loop;
      return Ada.Strings.UTF_Encoding.Wide_Strings.Encode (Wide);
   end From_ANSI;

   --  UTF-16LE bytes, as UTF-8.
   function From_UTF_16 (Bytes : String) return String is
      Units : Ada.Strings.UTF_Encoding.UTF_16_Wide_String
        (1 .. Bytes'Length / 2);
   begin
      for Index in Units'Range loop
         Units (Index) :=
           Wide_Character'Val
             (Character'Pos (Bytes (Bytes'First + 2 * (Index - 1)))
              + 256 * Character'Pos (Bytes (Bytes'First + 2 * Index - 1)));
      end loop;
      return Ada.Strings.UTF_Encoding.Conversions.Convert (Units);
   end From_UTF_16;

   --  Reads the length MFC writes before a CString at Position, and moves
   --  Position past it: a byte, or when that byte is FF a word, or when
   --  that word is FFFF a double word. A word FFFE instead says that UTF-16
   --  characters follow, their count written the same way again; it is
   --  returned as such, no string being that long in this form.
   procedure Read_Length
     (Data     : String;
      Position : in out Integer;
      Length   : out Natural)
   is
      Value : Natural := Byte (Data, Position);
   begin
      Position := Position + 1;
      if Value = 16#FF# then
         Value := Word (Data, Position);
         Position := Position + 2;
         if Value = 16#FFFF# then
            Value := Double_Word (Data, Position);
            Position := Position + 4;
         end if;
      end if;
      Length := Value;
   end Read_Length;

   --  How many bytes a CString takes, and whether they are UTF-16
   --  characters.
   type String_Size is record
      Bytes   : Natural := 0;
      Unicode : Boolean := False;
   end record;

   --  Reads the length or lengths before the CString at Position, and
   --  moves Position to its first byte.
   procedure Read_Size
     (Data     : String;
      Position : in out Integer;
      Size     : out String_Size)
   is
      Length : Natural;
   begin
      Read_Length (Data, Position, Length);
      Size := (Bytes => Length, Unicode => Length = 16#FFFE#);
      if Size.Unicode then
         Read_Length (Data, Position, Length);
         Size.Bytes := 2 * Length;
      end if;
      if Size.Bytes > Data'Last - Position + 1 then
         raise Format_Error with "a string runs past the end of the file";
      end if;
   end Read_Size;

   --  Reads the CString at Position, and moves Position past it.
   procedure Read_String
     (Data     : String;
      Position : in out Integer;
      Value    : out Unbounded_String)
   is
      Size : String_Size;
   begin
      Read_Size (Data, Position, Size);
      declare
         Bytes : constant String :=
           Data (Position .. Position + Size.Bytes - 1);
      begin
         Value := To_Unbounded_String
           (if Size.Unicode then From_UTF_16 (Bytes) else From_ANSI (Bytes));
      end;
      Position := Position + Size.Bytes;
   exception
      when Ada.Strings.UTF_Encoding.Encoding_Error =>
         raise Format_Error with "a string is not valid UTF-16";
   end Read_String;

   --  Moves Position past the CString there.
   procedure Skip_String (Data : String; Position : in out Integer) is
      Size : String_Size;
   begin
      Read_Size (Data, Position, Size);
      Position := Position + Size.Bytes;
   end Skip_String;

   --  Data and Name are both strings, but a call that swapped them would
   --  look for the whole file in a class name.
   function Find_Class
     (Data : String;
      Name : String;  --  adalang-analyzer: ignore Swappable_Parameters
      From : Positive) return Natural
   is
      Key   : constant String :=
        Character'Val (Name'Length) & Character'Val (0) & Name;
      Start : Positive := From;
   begin
      while Start <= Data'Last loop
         declare
            Found : constant Natural :=
              Ada.Strings.Fixed.Index (Data (Start .. Data'Last), Key);
         begin
            if Found = 0 then
               return 0;
            elsif Found - 4 >= Data'First
              and then Data (Found - 4 .. Found - 3) =
                Character'Val (16#FF#) & Character'Val (16#FF#)
            then
               return Found - 4;
            end if;
            Start := Found + 1;
         end;
      end loop;
      return 0;
   end Find_Class;

   --  The position after the declaration of the class named Name that
   --  begins at Declaration.
   function After_Class (Declaration : Positive; Name : String)
     return Positive is (Declaration + 6 + Name'Length);

   function Last_Component (Path : String) return String is
   begin
      for Index in reverse Path'Range loop
         if Path (Index) in '\' | '/' then
            return Path (Index + 1 .. Path'Last);
         end if;
      end loop;
      return Path;
   end Last_Component;

   --  Reads the three strings of a listed source at Position, and moves
   --  Position past them, when they are what such a record holds: three
   --  paths without control characters, the second a simple name that ends
   --  the first or the third. Leaves Position alone and returns False
   --  otherwise.
   function Read_Listed_File
     (Data     : String;
      Position : in out Integer;
      Item     : out Listed_File) return Boolean
   is
      Next : Integer := Position;

      function Plausible (Text : String) return Boolean is
        (Text'Length in 1 .. 4_096
         and then (for all C of Text => Character'Pos (C) >= 32));
   begin
      Item := (others => Null_Unbounded_String);
      begin
         Read_String (Data, Next, Item.Absolute);
         Read_String (Data, Next, Item.Name);
         Read_String (Data, Next, Item.Relative);
      exception
         when Format_Error =>
            return False;
      end;
      declare
         Absolute : constant String := To_String (Item.Absolute);
         Name     : constant String := To_String (Item.Name);
         Relative : constant String := To_String (Item.Relative);
      begin
         if Plausible (Absolute)
           and then Plausible (Name)
           and then Plausible (Relative)
           and then (for all C of Name => C not in '\' | '/' | ':')
           and then (Same_Name (Last_Component (Relative), Name)
                     or else Same_Name (Last_Component (Absolute), Name))
         then
            Position := Next;
            return True;
         end if;
      end;
      return False;
   end Read_Listed_File;

   --  The whole of the file at Path.
   function Read_File (Path : String) return GNAT.OS_Lib.String_Access is
      use Ada.Streams.Stream_IO;
      File : File_Type;
      Data : GNAT.OS_Lib.String_Access;
   begin
      Open (File, In_File, Path);
      if Size (File) > Largest_Project then
         Close (File);
         raise Format_Error with "it is too large";
      end if;
      Data := new String (1 .. Natural (Size (File)));
      String'Read (Stream (File), Data.all);
      Close (File);
      return Data;
   exception
      when Error : others =>
         if Is_Open (File) then
            Close (File);
         end if;
         GNAT.OS_Lib.Free (Data);
         raise Format_Error with
           "the file cannot be read: "
           & Ada.Exceptions.Exception_Message (Error);
   end Read_File;

   --  The archive begins with the project's first target: the class
   --  CTarget, declared there.
   function Starts_As_Project (Data : String) return Boolean is
     (Data'Length >= 19
      and then Data (Data'First + 6 .. Data'First + 7) =
        Character'Val (16#FF#) & Character'Val (16#FF#)
      and then Word (Data, Data'First + 10) = 7
      and then Data (Data'First + 12 .. Data'First + 18) = "CTarget");

   procedure Read_Library_Options
     (Data : String; From : Positive; Result : in out Contents);

   --  Finds the library options of the first target, after From, and
   --  reads them. Raises Format_Error when there are none.
   procedure Read_Search_Path
     (Data : String; From : Positive; Result : in out Contents)
   is
      Declaration : constant Natural := Find_Class (Data, "CAdaOptions", From);
      Position    : Positive;
   begin
      if Declaration = 0 then
         --  Every target has them: the file has been cut short.
         raise Format_Error with
           "the file ends before the target's library options: it is cut"
           & " short or damaged";
      end if;

      Position := After_Class (Declaration, "CAdaOptions");
      Read_Library_Options (Data, Position, Result);
   end Read_Search_Path;

   --  The library options that begin at From, read as every release seen
   --  writes them: the library directory, by full path and by simple name;
   --  the names of its object, information and cross-reference
   --  subdirectories; six bytes and a word; the search path, its entries
   --  separated by semicolons. The full path is where the project was
   --  first saved, even when it has been moved since. Options written
   --  otherwise leave the library directory and the search path unknown.
   procedure Read_Library_Options
     (Data : String; From : Positive; Result : in out Contents)
   is
      Position : Integer := From;
      Path     : Unbounded_String;
   begin
      Skip_String (Data, Position);
      Read_String (Data, Position, Result.Library_Dir);
      for Subdirectory in 1 .. 3 loop
         Skip_String (Data, Position);
      end loop;
      Position := Position + 8;
      Read_String (Data, Position, Path);

      declare
         Text  : constant String := To_String (Path);
         First : Positive := Text'First;
      begin
         for Index in Text'First .. Text'Last + 1 loop
            if Index > Text'Last or else Text (Index) = ';' then
               declare
                  Item : constant String :=
                    Ada.Strings.Fixed.Trim
                      (Text (First .. Index - 1), Ada.Strings.Both);
               begin
                  if Item /= "" then
                     Result.Search_Path.Append (Item);
                  end if;
               end;
               First := Index + 1;
            end if;
         end loop;
      end;
   exception
      when Format_Error =>
         Result.Library_Dir := Null_Unbounded_String;
         Result.Search_Path.Clear;
         Config.Log_Verbose ("  library options not read");
   end Read_Library_Options;

   function Read (Path : String) return Contents is
      Data     : GNAT.OS_Lib.String_Access := Read_File (Path);
      Result   : Contents;
      Position : Integer;
      Tag      : Natural := 0;
      Item     : Listed_File;
   begin
      if not Starts_As_Project (Data.all) then
         raise Format_Error with
           "this is not an ObjectAda project file (it does not begin with "
           & "a target)";
      end if;

      --  The target's name comes after two double words.
      begin
         Position := Data'First + 19 + 8;
         Read_String (Data.all, Position, Result.Target);
      exception
         when Format_Error =>
            Result.Target := Null_Unbounded_String;
      end;

      declare
         Declaration : constant Natural :=
           Find_Class (Data.all, "CTargetFile", Data'First + 19);
         Count       : Natural;
      begin
         if Declaration = 0 then
            --  No target lists a source, or the file ends before the
            --  list.
            Read_Search_Path (Data.all, Data'First + 19, Result);
            GNAT.OS_Lib.Free (Data);
            return Result;
         end if;

         --  The number of sources comes before the first, which declares
         --  the class. Each of the others begins with a reference to the
         --  class, then come the three strings, then a few bytes whose
         --  number depends on the class's schema (ten for schema 9, the
         --  one of every release seen, Aonix 7.2 to PTC 10). The next
         --  source is looked for where those bytes end, among the next
         --  64 positions.
         Count := Word (Data.all, Declaration - 2);
         Position := After_Class (Declaration, "CTargetFile");
         if not Read_Listed_File (Data.all, Position, Item) then
            raise Format_Error with
              "the first listed source is not laid out as expected";
         end if;
         Result.Files.Append (Item);

         for Source in 2 .. Count loop
            declare
               Found : Boolean := False;
            begin
               for Start in Position .. Integer'Min (Position + 64, Data'Last)
               loop
                  declare
                     Reference : constant Natural :=
                       (if Start < Data'Last then Word (Data.all, Start)
                        else 0);
                     Next      : Integer := Start + 2;
                  begin
                     if Reference >= 16#8000#
                       and then (Tag = 0 or else Reference = Tag)
                       and then Read_Listed_File (Data.all, Next, Item)
                     then
                        Tag := Reference;
                        Position := Next;
                        Result.Files.Append (Item);
                        Found := True;
                        exit;
                     end if;
                  end;
               end loop;
               if not Found then
                  raise Format_Error with
                    "listed source" & Source'Image & " of" & Count'Image
                    & " is not laid out as expected";
               end if;
            end;
         end loop;

         Read_Search_Path (Data.all, Position, Result);

         --  The lists of the other targets, if any, refer to the class in
         --  the same way. Their sources join those of the first.
         if Tag = 0 then
            --  MFC numbers each class and each object as it writes them:
            --  the class CTarget, the first target, then this class.
            Tag := 16#8003#;
         end if;
         while Position < Data'Last loop
            declare
               Next : Integer := Position + 2;
            begin
               if Word (Data.all, Position) = Tag
                 and then Read_Listed_File (Data.all, Next, Item)
               then
                  if not (for some Listed of Result.Files =>
                            Same_Name (To_String (Listed.Relative),
                                       To_String (Item.Relative)))
                  then
                     Result.Files.Append (Item);
                  end if;
                  Position := Next;
               else
                  Position := Position + 1;
               end if;
            end;
         end loop;
      end;

      GNAT.OS_Lib.Free (Data);
      return Result;
   exception
      when others =>
         GNAT.OS_Lib.Free (Data);
         raise;
   end Read;

   -----------------------------------------------------------------------
   --  Finding the files on this host
   -----------------------------------------------------------------------

   On_Windows : constant Boolean := GNAT.OS_Lib.Directory_Separator = '\';

   --  A path as the project writes it, with this host's separators. On
   --  Windows both separators are accepted, so it is left as it is.
   function To_Host (Path : String) return String is
      Result : String := Path;
   begin
      if not On_Windows then
         for C of Result loop
            if C = '\' then
               C := '/';
            end if;
         end loop;
      end if;
      return Result;
   end To_Host;

   --  True for "C:\..." and "\\server\...", or "\..." on the current drive.
   function Is_Windows_Absolute (Path : String) return Boolean is
     ((Path'Length >= 2 and then Path (Path'First + 1) = ':')
      or else (Path'Length >= 1 and then Path (Path'First) in '\' | '/'));

   function Normal (Path : String) return String is
     (GNAT.OS_Lib.Normalize_Pathname
        (Path, Resolve_Links => False, Case_Sensitive => True));

   package Component_Vectors renames Names;

   function Components (Path : String) return Component_Vectors.Vector is
      Result : Component_Vectors.Vector;
      First  : Positive := Path'First;
   begin
      for Index in Path'First .. Path'Last + 1 loop
         if Index > Path'Last or else Path (Index) in '\' | '/' then
            if Index > First then
               Result.Append (Path (First .. Index - 1));
            end if;
            First := Index + 1;
         end if;
      end loop;
      return Result;
   end Components;

   package Listing_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Names.Vector,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=",
      "="             => Names."=");

   --  The names in the directories read so far.
   Listings : Listing_Maps.Map;

   --  The names in Directory, but "." and "..". Only the names are read:
   --  Ada.Directories reads the attributes of every entry as well, and
   --  raises Use_Error at an entry whose attributes cannot be read. A
   --  drive root on Windows has such entries (pagefile.sys, System Volume
   --  Information), and a symbolic link that loops is one on any host.
   --  Raises GNAT.Directory_Operations.Directory_Error when Directory
   --  cannot be read.
   function Listing (Directory : String) return Names.Vector is
      Handle : GNAT.Directory_Operations.Dir_Type;
      Buffer : String (1 .. 4_096);
      Last   : Natural;
      Result : Names.Vector;
   begin
      if Listings.Contains (Directory) then
         return Listings.Element (Directory);
      end if;
      GNAT.Directory_Operations.Open (Handle, Directory);
      loop
         GNAT.Directory_Operations.Read (Handle, Buffer, Last);
         exit when Last = 0;
         if Buffer (1 .. Last) not in "." | ".." then
            Result.Append (Buffer (1 .. Last));
         end if;
      end loop;
      GNAT.Directory_Operations.Close (Handle);
      Listings.Insert (Directory, Result);
      return Result;
   end Listing;

   function Join (Directory, Name : String) return String is
     (if Directory /= "" and then Directory (Directory'Last) in '/' | '\'
      then Directory & Name
      else Directory & GNAT.OS_Lib.Directory_Separator & Name);

   --  The name in Directory that Part is, as it is on disk, or "". When
   --  Directory can be entered but not listed, Part is taken as it is
   --  written if something of that name is there.
   function Name_On_Disk
     (Directory : String;
      Part      : String)  --  adalang-analyzer: ignore Swappable_Parameters
      return String
   is
      Names_In : Names.Vector;
   begin
      begin
         Names_In := Listing (Directory);
      exception
         when GNAT.Directory_Operations.Directory_Error =>
            return
              (if GNAT.OS_Lib.Is_Regular_File (Join (Directory, Part))
                 or else GNAT.OS_Lib.Is_Directory (Join (Directory, Part))
               then Part
               else "");
      end;
      if Names_In.Contains (Part) then
         return Part;
      end if;
      for Name of Names_In loop
         if Same_Name (Name, Part) then
            return Name;
         end if;
      end loop;
      return "";
   end Name_On_Disk;

   --  Path on this host, named as it is on disk, or "" when nothing is
   --  there. A component that matches a name on disk only when case is
   --  ignored is taken for it, as Windows would: a project names a file
   --  in the case it was added with, which need not be the case it has on
   --  disk. A file is so named the same in the reports, and in their
   --  fingerprints, whatever the host.
   function Find_On_Host (Path : String) return String is
      Full      : constant String := Normal (Path);
      Root_Last : Natural;
      Current   : Unbounded_String;
   begin
      if Full'Length >= 1 and then Full (Full'First) in '/' | '\'
        and then not (Full'Length >= 2
                      and then Full (Full'First + 1) in '/' | '\')
      then
         Root_Last := Full'First;
      elsif On_Windows
        and then Full'Length >= 3
        and then Full (Full'First + 1) = ':'
        and then Full (Full'First + 2) in '/' | '\'
      then
         Root_Last := Full'First + 2;
      else
         --  A network path, or one of no form known here.
         return (if Ada.Directories.Exists (Full) then Full else "");
      end if;

      Current := To_Unbounded_String (Full (Full'First .. Root_Last));
      for Part of Components (Full (Root_Last + 1 .. Full'Last)) loop
         declare
            Directory : constant String := To_String (Current);
            Match     : constant String := Name_On_Disk (Directory, Part);
         begin
            if Match = "" then
               return "";
            end if;
            Current := To_Unbounded_String (Join (Directory, Match));
         end;
      end loop;
      return To_String (Current);
   exception
      when Ada.Directories.Name_Error | Ada.Directories.Use_Error =>
         return "";
   end Find_On_Host;

   function Is_Ada_Source_Name (Name : String) return Boolean is
      Extension : constant String :=
        Lower (Ada.Directories.Extension (Name));
   begin
      return Extension in "ada" | "adb" | "ads" | "a" | "spc" | "bdy";
   end Is_Ada_Source_Name;

   --  The run-time library of the ObjectAda installation: "...\lib\rts".
   --  Libadalang uses the GNAT run-time instead.
   function Is_Runtime (Entry_Path : String) return Boolean is
      Parts : constant Component_Vectors.Vector := Components (Entry_Path);
   begin
      return Natural (Parts.Length) >= 2
        and then Same_Name (Parts.Last_Element, "rts")
        and then Same_Name (Parts (Parts.Last_Index - 1), "lib");
   end Is_Runtime;

   --  A source found on this host, with the path the project gives for it.
   type Found_File is record
      Listed : Listed_File;
      Host   : Unbounded_String;
   end record;

   package Found_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Found_File);

   --  The library directory of the project at Project_Path on this host.
   --  The relative paths start from it; it is one directory below the
   --  project's, and need not exist.
   function Library_Base
     (Project_Path : String; Read_From : Contents) return String
   is
      Directory : constant String :=
        Ada.Directories.Containing_Directory
          (Ada.Directories.Full_Name (Project_Path));
      Library   : constant String := To_String (Read_From.Library_Dir);
   begin
      return Directory & GNAT.OS_Lib.Directory_Separator
        & (if Library = "" or else Library = "."
             or else Library = ".."
             or else (for some C of Library => C in '\' | '/' | ':')
           then "objectada-library"
           else Library);
   end Library_Base;

   --  The host path of a listed source, or "": through its relative path,
   --  then through whichever of its paths is absolute on this host.
   function Locate (Base : String; Item : Listed_File) return String is
      Relative : constant String := To_String (Item.Relative);

      function Absolute_On_Host (Path : String) return String is
        (if Path /= "" and then GNAT.OS_Lib.Is_Absolute_Path (Path)
         then Find_On_Host (Path)
         else "");
   begin
      if Relative /= "" and then not Is_Windows_Absolute (Relative) then
         declare
            Found : constant String :=
              Find_On_Host
                (Base & GNAT.OS_Lib.Directory_Separator & To_Host (Relative));
         begin
            if Found /= "" then
               return Found;
            end if;
         end;
      end if;

      declare
         Found : constant String := Absolute_On_Host (To_Host (Relative));
      begin
         if Found /= "" then
            return Found;
         end if;
      end;
      return Absolute_On_Host (To_Host (To_String (Item.Absolute)));
   end Locate;

   --  Where the search-path entry Entry_Path is on this host, in the light
   --  of where the sources Found were found: an absolute entry that is not
   --  there is taken to have moved along with the project, so the part it
   --  shares with the absolute path of a listed source is replaced by
   --  where that source now is. "" when nothing says where it is.
   function Locate_Link
     (Base       : String;
      Entry_Path : String;  --  adalang-analyzer: ignore Swappable_Parameters
      Found      : Found_Vectors.Vector) return String
   is
      Separator : constant Character := GNAT.OS_Lib.Directory_Separator;
   begin
      if not Is_Windows_Absolute (Entry_Path) then
         return Normal (Base & Separator & To_Host (Entry_Path));
      elsif GNAT.OS_Lib.Is_Absolute_Path (To_Host (Entry_Path))
        and then Ada.Directories.Exists (To_Host (Entry_Path))
      then
         return Normal (To_Host (Entry_Path));
      end if;

      declare
         Wanted    : constant Component_Vectors.Vector :=
           Components (Entry_Path);
         Best      : Natural := 1;
         Best_Path : Unbounded_String;
      begin
         for Source of Found loop
            declare
               Was    : constant Component_Vectors.Vector :=
                 Components (To_String (Source.Listed.Absolute));
               Is_Now : constant Component_Vectors.Vector :=
                 Components (To_String (Source.Host));
               Shared : Natural := 0;
            begin
               while Shared < Natural (Wanted.Length)
                 and then Shared < Natural (Was.Length) - 1
                 and then Same_Name
                   (Wanted (Wanted.First_Index + Shared),
                    Was (Was.First_Index + Shared))
               loop
                  Shared := Shared + 1;
               end loop;

               --  The drive and at least one directory.
               if Shared > Best
                 and then Natural (Was.Length) - Shared
                   < Natural (Is_Now.Length)
               then
                  declare
                     Kept : constant Natural :=
                       Natural (Is_Now.Length)
                       - (Natural (Was.Length) - Shared);
                     Path : Unbounded_String;
                  begin
                     if On_Windows then
                        Path := To_Unbounded_String
                          (Is_Now (Is_Now.First_Index));
                     end if;
                     for Index in
                       Is_Now.First_Index + (if On_Windows then 1 else 0)
                         .. Is_Now.First_Index + Kept - 1
                     loop
                        Append (Path, Separator & Is_Now (Index));
                     end loop;
                     for Index in
                       Wanted.First_Index + Shared .. Wanted.Last_Index
                     loop
                        Append (Path, Separator & Wanted (Index));
                     end loop;
                     Best := Shared;
                     Best_Path := Path;
                  end;
               end if;
            end;
         end loop;
         return To_String (Best_Path);
      end;
   end Locate_Link;

   --  Reads the project at Path, finds its sources, and those of the
   --  libraries on its search path, recursively. The sources of the root
   --  project are analyzed, those of the libraries only looked up.
   procedure Load_Into
     (Path    : String;
      Is_Root : Boolean;
      Visited : in out Name_Sets.Set;
      Result  : in out Project)
   is
      Read_From : constant Contents := Read (Path);
      Base      : constant String := Library_Base (Path, Read_From);
      Found     : Found_Vectors.Vector;
      Seen      : Name_Sets.Set;
   begin
      Visited.Include (Normal (Path));
      if Is_Root then
         Result.Target := Read_From.Target;
         Result.Listed := Natural (Read_From.Files.Length);
      end if;

      for Item of Read_From.Files loop
         declare
            Host : constant String := Locate (Base, Item);
         begin
            if Host = "" then
               if Is_Root then
                  Result.Missing.Append (To_String (Item.Relative));
               else
                  Config.Log_Verbose
                    ("  library source not found: "
                     & To_String (Item.Relative) & " (" & Path & ")");
               end if;
            elsif not Seen.Contains (Host) then
               Seen.Include (Host);
               Found.Append ((Listed => Item,
                              Host   => To_Unbounded_String (Host)));
               if Is_Root then
                  Result.Sources.Append (Host);
               elsif not Result.Sources.Contains (Host)
                 and then not Result.Library_Sources.Contains (Host)
               then
                  Result.Library_Sources.Append (Host);
               end if;
            end if;
         end;
      end loop;

      for Link of Read_From.Search_Path loop
         if Is_Runtime (Link) then
            Config.Log_Verbose ("  ObjectAda run-time not read: " & Link);
         else
            declare
               Library   : constant String := Locate_Link (Base, Link, Found);
               Directory : constant String :=
                 (if Library = "" then "" else Find_On_Host (Library));
               Parent    : constant String :=
                 (if Library = "" then ""
                  else Find_On_Host
                    (Ada.Directories.Containing_Directory (Library)));
               Before    : constant Natural :=
                 Natural (Result.Library_Sources.Length);
            begin
               --  Sources in the library directory itself.
               if Directory /= "" and then GNAT.OS_Lib.Is_Directory (Directory)
               then
                  for Name of Listing (Directory) loop
                     declare
                        Source : constant String := Join (Directory, Name);
                     begin
                        if Is_Ada_Source_Name (Source)
                          and then GNAT.OS_Lib.Is_Regular_File (Source)
                          and then not Result.Sources.Contains (Source)
                          and then not Result.Library_Sources.Contains
                            (Source)
                        then
                           Result.Library_Sources.Append (Source);
                        end if;
                     end;
                  end loop;
               end if;

               --  The project whose library directory it is: a project
               --  file in the directory above it.
               if Parent /= "" then
                  for Name of Listing (Parent) loop
                     declare
                        Other : constant String := Join (Parent, Name);
                     begin
                        if Is_ObjectAda_Project_Name (Other)
                          and then GNAT.OS_Lib.Is_Regular_File (Other)
                          and then not Visited.Contains (Normal (Other))
                        then
                           declare
                              Other_Contents : Contents;
                           begin
                              Other_Contents := Read (Other);
                              if Same_Name
                                   (To_String (Other_Contents.Library_Dir),
                                    Last_Component (Library))
                              then
                                 Config.Log_Verbose
                                   ("  library " & Link & ": project "
                                    & Other);
                                 Load_Into (Other, False, Visited, Result);
                              end if;
                           exception
                              when Error : Format_Error =>
                                 Config.Log_Verbose
                                   ("  " & Other & " not read: "
                                    & Ada.Exceptions.Exception_Message
                                        (Error));
                           end;
                        end if;
                     end;
                  end loop;
               end if;

               if Natural (Result.Library_Sources.Length) = Before
                 and then not Result.Unresolved_Links.Contains (Link)
               then
                  Result.Unresolved_Links.Append (Link);
               end if;
            exception
               when Ada.Directories.Name_Error | Ada.Directories.Use_Error
                  | GNAT.Directory_Operations.Directory_Error
               =>
                  if not Result.Unresolved_Links.Contains (Link) then
                     Result.Unresolved_Links.Append (Link);
                  end if;
            end;
         end if;
      end loop;
   end Load_Into;

   function Load (Path : String) return Project is
      Result  : Project;
      Visited : Name_Sets.Set;
   begin
      Load_Into (Path, True, Visited, Result);
      return Result;
   end Load;

end Adalang_Analyzer.ObjectAda_Projects;
