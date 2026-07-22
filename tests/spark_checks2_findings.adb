--  Positive regression fixture for the aliasing, loop-variant, and
--  potentially-blocking SPARK diagnostics.
procedure Spark_Checks2_Findings is
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
         delay 1.0;
      end P;
   end PO;

   X : Integer := 1;
   N : Integer := 10;
begin
   Swap (X, X);

   while N > 0 loop
      pragma Loop_Invariant (N >= 0);
      N := N - 1;
   end loop;

   PO.P;
end Spark_Checks2_Findings;
