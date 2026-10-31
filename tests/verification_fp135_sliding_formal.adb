package body Verification_FP135_Sliding_Formal
  with SPARK_Mode
is
   procedure Needs_Twenty (X : From_One) is
   begin
      null;
   end Needs_Twenty;

   procedure Set_Twenty (X : in out From_One) is
   begin
      X (1) := 20;
   end Set_Twenty;

   procedure Bad_Inlined (Slid : From_Zero) is
   begin
      if Slid (1) = 20 then
         pragma Assert (First_Of (Slid) = 20);
      end if;
   end Bad_Inlined;

   procedure Bad_Assumed (Slid : From_Zero) is
   begin
      if Starts_At_Twenty (Slid) then
         pragma Assert (Slid (1) = 20);
      end if;
   end Bad_Assumed;

   procedure Bad_Called (Slid : From_Zero) is
   begin
      if Slid (1) = 20 then
         Needs_Twenty (Slid);
      end if;
   end Bad_Called;

   procedure Bad_After_Call (Slid : in out From_Zero) is
   begin
      Set_Twenty (Slid);
      pragma Assert (Slid (1) = 20);
   end Bad_After_Call;

   procedure Same_Subtype_Inlined (A : From_One) is
   begin
      if A (1) = 20 then
         pragma Assert (First_Of (A) = 20);
      end if;
   end Same_Subtype_Inlined;

   procedure Same_Subtype_Called (A : From_One) is
   begin
      if A (1) = 20 then
         Needs_Twenty (A);
      end if;
   end Same_Subtype_Called;

   procedure Own_Bounds (A : From_Zero) is
   begin
      if A (1) = 20 then
         pragma Assert (Own_First (A) = 20);
      end if;
   end Own_Bounds;
end Verification_FP135_Sliding_Formal;
