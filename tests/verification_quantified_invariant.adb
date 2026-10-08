package body Verification_Quantified_Invariant with SPARK_Mode is

   procedure Kept (Data : in out Table) is
      Steady : Integer := 20;
   begin
      for Index in Data'Range loop
         pragma Loop_Invariant (for all I in 1 .. 10 => I < Steady);
         Data (Index) := 100 / Steady;
      end loop;
   end Kept;

   procedure Broken (Data : in out Table) is
      Falling : Integer := 20;
   begin
      for Index in Data'Range loop
         pragma Loop_Invariant (for all J in 1 .. 10 => J < Falling);
         Falling := Falling - 1;
         Data (Index) := Falling;
      end loop;
   end Broken;

   procedure Widened (Data : in out Table) is
      Growing : Integer := 5;
   begin
      for Index in Data'Range loop
         pragma Loop_Invariant (for all K in 1 .. Growing => K <= 10);
         Growing := Growing + 1;
         Data (Index) := Growing;
      end loop;
   end Widened;

   procedure Never_True (Data : in out Table; Result : out Integer) is
      Low : Integer := 0;
   begin
      for Index in Data'Range loop
         pragma Loop_Invariant (for all L in 1 .. 10 => Low > L);
         Data (Index) := Index;
      end loop;
      Result := 100 / Low;
   end Never_True;

   procedure Inside (Data : in out Table) is
   begin
      for Index in Data'Range loop
         pragma Loop_Invariant (for all M in 1 .. 10 => 100 / (M - 5) < 1000);
         Data (Index) := Index;
      end loop;
   end Inside;

   procedure Cut (Result : out Integer) is
      Short : Integer := 0;
   begin
      pragma Assert_And_Cut (for all N in 1 .. 10 => Short > N);
      Result := 100 / Short;
   end Cut;

end Verification_Quantified_Invariant;
