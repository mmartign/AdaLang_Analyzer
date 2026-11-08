package body Verification_Mutation_Relaxed_Elements
  with SPARK_Mode
is
   procedure Fill_Two (Pair : out Bytes_2) is
   begin
      Pair := (others => 1);
   end Fill_Two;

   procedure Leave (Left : out Arr) is
   begin
      null;
   end Leave;

   procedure Past_Elements (Gappy : out Arr) is
   begin
      Gappy (1) := 1;
      Gappy (3) := 3;
      pragma Assert (Gappy (1 .. 3)'Initialized);
   end Past_Elements;

   procedure Past_Slice (Short_Band : out Arr) is
   begin
      Short_Band (1 .. 2) := (others => 0);
      pragma Assert (Short_Band (1 .. 3)'Initialized);
   end Past_Slice;

   procedure Past_Actual (Short_Strip : out Bytes) is
   begin
      Fill_Two (Short_Strip (0 .. 1));
      pragma Assert (Short_Strip (0 .. 2)'Initialized);
   end Past_Actual;

   procedure Past_Loop (Short_Lane : out Arr) is
   begin
      for I in 1 .. 3 loop
         Short_Lane (I) := I;
         pragma Loop_Invariant
           (for all K in 1 .. I => Short_Lane (K)'Initialized);
      end loop;
      pragma Assert (Short_Lane (1 .. 4)'Initialized);
   end Past_Loop;

   procedure One_Branch (Forked : out Arr; Flag : Boolean) is
   begin
      if Flag then
         Forked (1) := 1;
      end if;
      pragma Assert (Forked (1)'Initialized);
   end One_Branch;

   procedure Other_Index (Moved : out Arr; Where, Read_At : Positive;
                          Value : out Integer) is
   begin
      Moved (Where) := 1;
      Value := Moved (Read_At);
   end Other_Index;

   procedure Reassigned (Replaced : out Arr; Source : Arr) is
   begin
      Replaced (1) := 1;
      Replaced := Source;
      pragma Assert (Replaced (1)'Initialized);
   end Reassigned;

   procedure Left_By_Call (Dropped : out Arr) is
   begin
      Dropped (1) := 1;
      Leave (Dropped);
      pragma Assert (Dropped (1)'Initialized);
   end Left_By_Call;
end Verification_Mutation_Relaxed_Elements;
