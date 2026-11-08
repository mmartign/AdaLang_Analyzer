package body Verification_Relaxed_Elements
  with SPARK_Mode
is
   procedure Fill_Two (Pair : out Bytes_2) is
   begin
      Pair := (others => 1);
   end Fill_Two;

   procedure Fill_Relaxed_Two (Soft_Pair : out Bytes_2) is
   begin
      Soft_Pair := (others => 2);
   end Fill_Relaxed_Two;

   procedure Element_Writes (Row : out Arr; Elem_Read : out Integer) is
   begin
      Row (1) := 1;
      pragma Assert (Row (1)'Initialized);
      Elem_Read := Row (1);
      Row (2) := 2;
      pragma Assert (Row (1 .. 2)'Initialized);
      Row (3) := 3;
      Row (4) := 4;
      pragma Assert (Row'Initialized);
   end Element_Writes;

   function Pick (Given_Rows : Arr; Upto : Positive) return Boolean is
   begin
      return Given_Rows (1) > 0 and then Given_Rows (Upto) > 0;
   end Pick;

   procedure Slice_Write (Band : out Arr; Band_Read : out Integer) is
   begin
      Band (1 .. 2) := (others => 0);
      pragma Assert (Band (1 .. 2)'Initialized);
      Band_Read := Band (2);
   end Slice_Write;

   procedure Slice_Actuals (Strip : out Bytes; Strip_Read : out Integer) is
   begin
      Fill_Two (Strip (0 .. 1));
      pragma Assert (Strip (0 .. 1)'Initialized);
      Fill_Relaxed_Two (Strip (2 .. 3));
      pragma Assert (Strip'Initialized);
      Strip_Read := Strip (3);
   end Slice_Actuals;

   procedure Loop_Elements (Lane : out Arr; Lane_Read : out Integer) is
   begin
      for I in 1 .. 3 loop
         Lane (I) := I;
         pragma Loop_Invariant (for all K in 1 .. I => Lane (K)'Initialized);
      end loop;
      pragma Assert (Lane (1 .. 3)'Initialized);
      Lane_Read := Lane (3);
   end Loop_Elements;

   procedure Known_Index (Spot : out Arr; At_Index : Positive) is
   begin
      Spot (At_Index) := 7;
      pragma Assert (Spot (At_Index)'Initialized);
   end Known_Index;
end Verification_Relaxed_Elements;
