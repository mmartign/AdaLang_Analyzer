--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  Developed, validated, and maintained by Spazio IT.
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;
with Ada.Text_IO;

with Libadalang.Common; use Libadalang.Common;

with Adalang_Analyzer.Config;
with Langkit_Support.Text; use Langkit_Support.Text;

package body Adalang_Analyzer.Unit_Provider is

   use Libadalang.Analysis;

   type Chained_Provider is new Unit_Provider_Interface with record
      Primary  : Unit_Provider_Reference;
      Fallback : Unit_Provider_Reference;
   end record;

   overriding function Get_Unit_Filename
     (Provider : Chained_Provider;
      Name     : Text_Type;
      Kind     : Analysis_Unit_Kind) return String;

   overriding procedure Get_Unit_Location
     (Provider       : Chained_Provider;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Filename       : in out Unbounded_String;
      PLE_Root_Index : in out Natural);

   overriding function Get_Unit
     (Provider : Chained_Provider;
      Context  : Analysis_Context'Class;
      Name     : Text_Type;
      Kind     : Analysis_Unit_Kind;
      Charset  : String := "";
      Reparse  : Boolean := False) return Analysis_Unit'Class;

   overriding procedure Get_Unit_And_PLE_Root
     (Provider       : Chained_Provider;
      Context        : Analysis_Context'Class;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Charset        : String := "";
      Reparse        : Boolean := False;
      Unit           : in out Analysis_Unit'Class;
      PLE_Root_Index : in out Natural);

   overriding procedure Release (Provider : in out Chained_Provider);

   function Primary_Location
     (Provider       : Chained_Provider'Class;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Filename       : out Unbounded_String;
      PLE_Root_Index : out Natural) return Boolean;

   function Primary_Location
     (Provider       : Chained_Provider'Class;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Filename       : out Unbounded_String;
      PLE_Root_Index : out Natural) return Boolean
   is
   begin
      Filename := Null_Unbounded_String;
      PLE_Root_Index := 0;
      Provider.Primary.Get.Get_Unit_Location
        (Name, Kind, Filename, PLE_Root_Index);
      return Length (Filename) > 0;
   end Primary_Location;

   overriding function Get_Unit_Filename
     (Provider : Chained_Provider;
      Name     : Text_Type;
      Kind     : Analysis_Unit_Kind) return String
   is
      Filename : Unbounded_String;
      Index    : Natural;
   begin
      if Primary_Location (Provider, Name, Kind, Filename, Index) then
         return To_String (Filename);
      else
         return Provider.Fallback.Get.Get_Unit_Filename (Name, Kind);
      end if;
   end Get_Unit_Filename;

   overriding procedure Get_Unit_Location
     (Provider       : Chained_Provider;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Filename       : in out Unbounded_String;
      PLE_Root_Index : in out Natural) is
   begin
      if not Primary_Location
        (Provider, Name, Kind, Filename, PLE_Root_Index)
      then
         Provider.Fallback.Get.Get_Unit_Location
           (Name, Kind, Filename, PLE_Root_Index);
      end if;
   end Get_Unit_Location;

   overriding function Get_Unit
     (Provider : Chained_Provider;
      Context  : Analysis_Context'Class;
      Name     : Text_Type;
      Kind     : Analysis_Unit_Kind;
      Charset  : String := "";
      Reparse  : Boolean := False) return Analysis_Unit'Class
   is
      Filename : Unbounded_String;
      Index    : Natural;
   begin
      if Primary_Location (Provider, Name, Kind, Filename, Index) then
         return Context.Get_From_File
           (To_String (Filename), Charset, Reparse);
      else
         return Provider.Fallback.Get.Get_Unit
           (Context, Name, Kind, Charset, Reparse);
      end if;
   end Get_Unit;

   overriding procedure Get_Unit_And_PLE_Root
     (Provider       : Chained_Provider;
      Context        : Analysis_Context'Class;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Charset        : String := "";
      Reparse        : Boolean := False;
      Unit           : in out Analysis_Unit'Class;
      PLE_Root_Index : in out Natural)
   is
      Filename : Unbounded_String;
   begin
      if Primary_Location
        (Provider, Name, Kind, Filename, PLE_Root_Index)
      then
         Unit := Analysis_Unit'Class
           (Context.Get_From_File (To_String (Filename), Charset, Reparse));
      else
         Provider.Fallback.Get.Get_Unit_And_PLE_Root
           (Context, Name, Kind, Charset, Reparse, Unit, PLE_Root_Index);
      end if;
   end Get_Unit_And_PLE_Root;

   overriding procedure Release (Provider : in out Chained_Provider) is
   begin
      Provider.Primary := No_Unit_Provider_Reference;
      Provider.Fallback := No_Unit_Provider_Reference;
   end Release;

   function Create
     (Primary  : Unit_Provider_Reference;
      Fallback : Unit_Provider_Reference) return Unit_Provider_Reference is
   begin
      return Create_Unit_Provider_Reference
        (Chained_Provider'(Primary => Primary, Fallback => Fallback));
   end Create;

   ----------------------------------
   --  Units of preprocessed files  --
   ----------------------------------

   type Unit_Location is record
      Filename : Unbounded_String;
      Index    : Positive;
   end record;

   package Location_Maps is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Unit_Location,
      Hash            => Ada.Strings.Hash,
      Equivalent_Keys => "=");

   type Indexed_Provider is new Unit_Provider_Interface with record
      Locations : Location_Maps.Map;
   end record;

   overriding function Get_Unit_Filename
     (Provider : Indexed_Provider;
      Name     : Text_Type;
      Kind     : Analysis_Unit_Kind) return String;

   overriding procedure Get_Unit_Location
     (Provider       : Indexed_Provider;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Filename       : in out Unbounded_String;
      PLE_Root_Index : in out Natural);

   overriding function Get_Unit
     (Provider : Indexed_Provider;
      Context  : Analysis_Context'Class;
      Name     : Text_Type;
      Kind     : Analysis_Unit_Kind;
      Charset  : String := "";
      Reparse  : Boolean := False) return Analysis_Unit'Class;

   overriding procedure Get_Unit_And_PLE_Root
     (Provider       : Indexed_Provider;
      Context        : Analysis_Context'Class;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Charset        : String := "";
      Reparse        : Boolean := False;
      Unit           : in out Analysis_Unit'Class;
      PLE_Root_Index : in out Natural);

   overriding procedure Release (Provider : in out Indexed_Provider);

   function Key (Name : Text_Type; Kind : Analysis_Unit_Kind) return String
   is (To_UTF8 (To_Lower (Name)) & "|" & Analysis_Unit_Kind'Image (Kind));

   overriding procedure Get_Unit_Location
     (Provider       : Indexed_Provider;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Filename       : in out Unbounded_String;
      PLE_Root_Index : in out Natural)
   is
      Position : constant Location_Maps.Cursor :=
        Provider.Locations.Find (Key (Name, Kind));
   begin
      if Location_Maps.Has_Element (Position) then
         Filename := Location_Maps.Element (Position).Filename;
         PLE_Root_Index := Location_Maps.Element (Position).Index;
      else
         Filename := Null_Unbounded_String;
         PLE_Root_Index := 0;
      end if;
   end Get_Unit_Location;

   overriding function Get_Unit_Filename
     (Provider : Indexed_Provider;
      Name     : Text_Type;
      Kind     : Analysis_Unit_Kind) return String
   is
      Filename : Unbounded_String;
      Index    : Natural := 0;
   begin
      Provider.Get_Unit_Location (Name, Kind, Filename, Index);
      return To_String (Filename);
   end Get_Unit_Filename;

   overriding procedure Get_Unit_And_PLE_Root
     (Provider       : Indexed_Provider;
      Context        : Analysis_Context'Class;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Charset        : String := "";
      Reparse        : Boolean := False;
      Unit           : in out Analysis_Unit'Class;
      PLE_Root_Index : in out Natural)
   is
      Filename : Unbounded_String;
   begin
      Provider.Get_Unit_Location (Name, Kind, Filename, PLE_Root_Index);
      --  An unknown unit gives an empty file name, and with it a unit
      --  that carries the "cannot open" diagnostic.
      Unit := Analysis_Unit'Class
        (Context.Get_From_File (To_String (Filename), Charset, Reparse));
   end Get_Unit_And_PLE_Root;

   overriding function Get_Unit
     (Provider : Indexed_Provider;
      Context  : Analysis_Context'Class;
      Name     : Text_Type;
      Kind     : Analysis_Unit_Kind;
      Charset  : String := "";
      Reparse  : Boolean := False) return Analysis_Unit'Class
   is
      Unit  : Analysis_Unit;
      Index : Natural := 0;
   begin
      Provider.Get_Unit_And_PLE_Root
        (Context, Name, Kind, Charset, Reparse, Unit, Index);
      return Unit;
   end Get_Unit;

   overriding procedure Release (Provider : in out Indexed_Provider) is
   begin
      Provider.Locations.Clear;
   end Release;

   --  True when a line of the file starts, after blanks, with '#'.
   function Has_Directive (Filename : String) return Boolean is
      File  : Ada.Text_IO.File_Type;
      Found : Boolean := False;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Filename);
      while not Found and then not Ada.Text_IO.End_Of_File (File) loop
         declare
            Line : constant String := Ada.Text_IO.Get_Line (File);
         begin
            for Char of Line loop
               if Char = '#' then
                  Found := True;
               end if;
               exit when Char /= ' ' and then Char /= ASCII.HT;
            end loop;
         end;
      end loop;
      Ada.Text_IO.Close (File);
      return Found;
   exception
      when Ada.Text_IO.Name_Error | Ada.Text_IO.Use_Error
         | Ada.Text_IO.End_Error =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return False;
   end Has_Directive;

   function Create_Preprocessed_Index
     (Files  : Project_Files.File_Name_Vectors.Vector;
      Reader : Langkit_Support.File_Readers.File_Reader_Reference)
      return Unit_Provider_Reference
   is
      use type Langkit_Support.File_Readers.File_Reader_Reference;

      Provider : Indexed_Provider;
      Skipped  : Natural := 0;

      procedure Add
        (Filename : String; Item : Compilation_Unit; Index : Positive)
      is
         Parts : constant Unbounded_Text_Type_Array :=
           Item.P_Syntactic_Fully_Qualified_Name;
         Name  : Unbounded_String;
      begin
         for I in Parts'Range loop
            if I > Parts'First then
               Append (Name, ".");
            end if;
            Append (Name, To_UTF8 (To_Text (Parts (I))));
         end loop;
         Provider.Locations.Include
           (Key (From_UTF8 (To_String (Name)), Item.P_Unit_Kind),
            (To_Unbounded_String (Filename), Index));
      end Add;
   begin
      if Reader = Langkit_Support.File_Readers.No_File_Reader_Reference then
         return No_Unit_Provider_Reference;
      end if;

      declare
         Context : constant Analysis_Context :=
           Create_Context (File_Reader => Reader);
      begin
         for Filename of Files loop
            if Has_Directive (Filename) then
               declare
                  Unit : constant Analysis_Unit :=
                    Context.Get_From_File (Filename);
                  Root : constant Ada_Node := Unit.Root;
               begin
                  --  A file that still does not parse is reported when it is
                  --  analyzed itself.
                  if Unit.Has_Diagnostics or else Root.Is_Null then
                     Skipped := Skipped + 1;
                  elsif Root.Kind = Ada_Compilation_Unit then
                     Add (Filename, Root.As_Compilation_Unit, 1);
                  elsif Root.Kind = Ada_Compilation_Unit_List then
                     for I in 1 .. Root.Children_Count loop
                        Add (Filename, Root.Child (I).As_Compilation_Unit, I);
                     end loop;
                  end if;
               end;
            end if;
         end loop;
      end;

      if Skipped > 0 then
         Config.Log_Verbose
           ("Preprocessed sources that do not parse:" & Skipped'Image);
      end if;
      if Provider.Locations.Is_Empty then
         return No_Unit_Provider_Reference;
      end if;
      return Create_Unit_Provider_Reference (Provider);
   end Create_Preprocessed_Index;

end Adalang_Analyzer.Unit_Provider;
