--  FP-149: what the exemption leaves reported. A scalar, a record with no
--  default, and a tagged object in code declared SPARK, which GNATprove
--  takes as without a value on entry.
procedure Uninitialized_Output_Defaults_Findings (Flag : Boolean) is
   type Plain is record
      Count : Integer;
   end record;

   type Tagged_Item is tagged record
      Count : Integer;
   end record;

   procedure Set_Scalar (F : Boolean; Value : out Integer) is
   begin
      if F then
         Value := 1;
      end if;
   end Set_Scalar;

   procedure Set_Plain (F : Boolean; Item : out Plain) is
   begin
      if F then
         Item := (Count => 1);
      end if;
   end Set_Plain;

   procedure Set_Tagged (F : Boolean; Item : out Tagged_Item)
     with SPARK_Mode
   is
   begin
      if F then
         Item.Count := 1;
      end if;
   end Set_Tagged;

   V : Integer;
   P : Plain;
   T : Tagged_Item;
begin
   Set_Scalar (Flag, V);
   Set_Plain (Flag, P);
   Set_Tagged (Flag, T);
end Uninitialized_Output_Defaults_Findings;
