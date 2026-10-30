package body Verification_FP134_Several_Names
  with SPARK_Mode
is
   procedure Store_First (N : Integer) is
   begin
      First := N;
   end Store_First;

   procedure Store_Second (N : Integer) is
   begin
      Second := N;
   end Store_Second;

   procedure Store_Alone (N : Integer) is
   begin
      Alone := N;
   end Store_Alone;

   procedure Use_First (R : out Integer) is
   begin
      First := 1;
      Store_First (5);
      R := 10 / (First - 5);
   end Use_First;

   procedure Use_Second (R : out Integer) is
   begin
      Second := 1;
      Store_Second (5);
      R := 10 / (Second - 5);
   end Use_Second;

   procedure Use_Alone (R : out Integer) is
   begin
      Alone := 1;
      Store_Alone (5);
      R := 10 / (Alone - 5);
   end Use_Alone;
end Verification_FP134_Several_Names;
