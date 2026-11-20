--  FP-149 regression: an out parameter that Ada gives a value however the
--  subprogram returns -- of a tagged or controlled type, passed by
--  reference; of an access type, or of a record type with a default, given
--  the value of the actual -- is not an output left without one, outside
--  SPARK. Alire's "Value : out TOML_Value", set when the function returns
--  True only.
with Ada.Strings.Unbounded; use Ada.Strings.Unbounded;

procedure Uninitialized_Output_Defaults_Clean (Flag : Boolean) is
   type Tagged_Item is tagged record
      Count : Integer;
   end record;

   type Defaulted is record
      Count : Integer := 0;
      Total : Integer;
   end record;

   type Reference is access all Integer;

   function Pop_Tagged (F : Boolean; Item : out Tagged_Item) return Boolean is
   begin
      if F then
         Item.Count := 1;
         return True;
      end if;
      return False;
   end Pop_Tagged;

   procedure Pop_Text (F : Boolean; Text : out Unbounded_String) is
   begin
      if F then
         Text := To_Unbounded_String ("value");
      end if;
   end Pop_Text;

   procedure Pop_Defaulted (F : Boolean; Item : out Defaulted) is
   begin
      if F then
         Item.Total := 1;
      end if;
   end Pop_Defaulted;

   procedure Pop_Reference (F : Boolean; Item : out Reference) is
   begin
      if F then
         Item := null;
      end if;
   end Pop_Reference;

   T : Tagged_Item;
   S : Unbounded_String;
   D : Defaulted;
   R : Reference;
begin
   if Pop_Tagged (Flag, T) then
      Pop_Text (Flag, S);
      Pop_Defaulted (Flag, D);
      Pop_Reference (Flag, R);
   end if;
end Uninitialized_Output_Defaults_Clean;
