--  An array has no more components than its index subtype has values:
--  whatever the state, the length of a dimension is from zero to that
--  number. Each procedure makes one claim; those that say more than the
--  index subtype does are not proved.
procedure Verification_Length_Limits (Count : Integer) with SPARK_Mode is

   type Small is range 1 .. 10;
   type Big is range 1 .. 1000;
   type Octet is mod 256;

   --  As many values as Count says, which nothing here knows.
   subtype Counted is Integer range 1 .. Count;

   type Matrix is array (Small range <>, Big range <>) of Integer;
   type By_Octet is array (Octet range <>) of Integer;
   type By_Count is array (Counted range <>) of Integer;
   type Row is array (Big range <>) of Integer;
   type Line is new Row;

   procedure Each_Dimension (Grid : Matrix) is
   begin
      pragma Assert (Grid'Length (1) <= 10);
      pragma Assert (Grid'Length (2) <= 1000);
   end Each_Dimension;

   --  The second dimension has the index subtype of the second.
   procedure Other_Dimension (Grid : Matrix) is
   begin
      pragma Assert (Grid'Length (2) <= 10);
   end Other_Dimension;

   --  Ten components are possible.
   procedure One_Less (Grid : Matrix) is
   begin
      pragma Assert (Grid'Length <= 9);
   end One_Less;

   procedure Modular_Index (Bytes : By_Octet) is
   begin
      pragma Assert (Bytes'Length <= 256);
   end Modular_Index;

   procedure Modular_Index_Less (Octets : By_Octet) is
   begin
      pragma Assert (Octets'Length <= 255);
   end Modular_Index_Less;

   --  The bounds of the index subtype are not static.
   procedure Unknown_Index (Items : By_Count) is
   begin
      pragma Assert (Items'Length <= 10);
   end Unknown_Index;

   procedure Derived_Type (Text : Line) is
   begin
      pragma Assert (Text'Length <= 1000);
   end Derived_Type;

   procedure Slice (Whole : Row) is
   begin
      pragma Assert (Whole (Whole'First .. Whole'Last)'Length <= 1000);
   end Slice;

   --  An array may be empty.
   procedure Not_Empty (Cells : Row) is
   begin
      pragma Assert (Cells'Length >= 1);
   end Not_Empty;

begin
   null;
end Verification_Length_Limits;
