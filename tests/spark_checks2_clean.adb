--  Negative regression fixture for the aliasing, loop-variant, and
--  potentially-blocking SPARK diagnostics.
procedure Spark_Checks2_Clean is
   procedure Swap (A, B : in out Integer)
     with Global => null
   is
      Temp : Integer;
   begin
      Temp := A;
      A := B;
      B := Temp;
   end Swap;

   protected PO is
      procedure P;
   end PO;

   protected body PO is
      procedure P is
      begin
         null;
      end P;
   end PO;

   X : Integer := 1;
   Y : Integer := 2;
   N : Integer := 10;
begin
   Swap (X, Y);

   while N > 0 loop
      pragma Loop_Invariant (N >= 0);
      pragma Loop_Variant (Decreases => N);
      N := N - 1;
   end loop;

   PO.P;
end Spark_Checks2_Clean;
