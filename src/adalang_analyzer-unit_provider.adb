--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

with Libadalang.Common; use Libadalang.Common;
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
     (Provider       : Chained_Provider;
      Name           : Text_Type;
      Kind           : Analysis_Unit_Kind;
      Filename       : out Unbounded_String;
      PLE_Root_Index : out Natural) return Boolean;

   function Primary_Location
     (Provider       : Chained_Provider;
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

end Adalang_Analyzer.Unit_Provider;
