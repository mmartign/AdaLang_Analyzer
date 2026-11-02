package body Verification_Element_Ranges
  with SPARK_Mode
is
   procedure Local_Subtype (X : Bytes_64) is
      Max_L : constant := 16;
      subtype XL_Limb is I64 range -(255 * Max_L) .. (255 * Max_L);
      type XL_Table is array (Index_64) of XL_Limb;
      XL : XL_Table := (others => 0);
   begin
      for K in Index_64 loop
         XL (K) := XL_Limb (X (K));
      end loop;
   end Local_Subtype;

   procedure Outer_Subtype (X : Bytes_64) is
      type O_Table is array (Index_64) of Outer_Limb;
      O : O_Table := (others => 0);
   begin
      for K in Index_64 loop
         O (K) := Outer_Limb (X (K));
      end loop;
   end Outer_Subtype;
end Verification_Element_Ranges;
