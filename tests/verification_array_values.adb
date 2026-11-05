package body Verification_Array_Values with SPARK_Mode is
   procedure Take (B : Bytes_16) is null;

   procedure Converted (N : Bytes_24) is
   begin
      Take (Bytes_16 (N (0 .. 15)));
   end Converted;

   procedure Declared (N : Bytes_24) is
      Head : constant Bytes := N (2 .. 9);
   begin
      Take (N (8 .. 23));
      pragma Assert (Head'Length = 8);
   end Declared;

   procedure Assigned (N : Bytes_24; Out_B : out Bytes_16) is
   begin
      Out_B := N (4 .. 19);
   end Assigned;

   procedure Concatenated (V : Integer; Text : String; Out_S : out String) is
      Literal : constant String := "Value: " & Text;
      Char    : constant String := 'c' & Text;
      Image   : constant String := Integer'Image (V) & Text;
   begin
      pragma Assert (Literal'First = 1);
      pragma Assert (Char'First = 1);
      pragma Assert (Image'First = 1);
      Out_S := (others => ' ');
      Out_S (1 .. Literal'Last) := Literal;
   end Concatenated;
end Verification_Array_Values;
