package body Verification_Provisional_Error with SPARK_Mode is

   procedure Walk (Data : in out Bytes_64) is
      Exponent      : constant Index_64 := 128 / 8;
      Factor_Pivot  : constant Index_64 := Data'Last - Exponent;
      Product_Pivot : constant Index_64 := Data'First + Exponent;
      Factor_Index  : Index_64 := Factor_Pivot;
      Product_Index : Index_64 := Data'First;
   begin
      Factor_Index := Index_64'Succ (Factor_Index);
      while Product_Index < Product_Pivot loop
         pragma Loop_Invariant
           (Factor_Index - Product_Index = Data'Last - Product_Pivot + 1);
         Product_Index := Index_64'Succ (Product_Index);
         exit when Product_Index = Product_Pivot;
         Factor_Index := Index_64'Succ (Factor_Index);
      end loop;
      pragma Assert (Factor_Index = Data'Last);
      Data (Data'First) := 0;
   end Walk;

   procedure Counted (Rounds : Integer; Sink : out Integer) is
      Count : Integer := 0;
   begin
      for Round in 1 .. Rounds loop
         pragma Loop_Invariant (Count = Round - 1);
         Count := Count + 1;
      end loop;
      pragma Assert (Count >= 1);
      Sink := 10 / Count;
   end Counted;

end Verification_Provisional_Error;
