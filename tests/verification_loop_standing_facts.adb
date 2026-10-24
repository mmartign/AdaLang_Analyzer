package body Verification_Loop_Standing_Facts
  with SPARK_Mode
is
   procedure Ok_Linear (Data : Byte_Array; Len : Natural; W : out Unsigned_8)
   is
      Remaining : Natural := Len;
      Offset    : Natural := 0;
   begin
      W := 0;
      for X in Coord loop
         pragma Loop_Invariant (Offset + Remaining = Len);
         exit when Remaining < 8;
         W := W xor Data (Data'First + Offset + 7);
         Offset    := Offset + 8;
         Remaining := Remaining - 8;
      end loop;
   end Ok_Linear;

   procedure Ok_Division
     (Data : Byte_Array; Bit_Len : Natural; W : out Unsigned_8)
   is
      Remaining : Natural := Bit_Len;
      Offset    : Natural := 0;
   begin
      W := 0;
      for X in Coord loop
         pragma Loop_Invariant ((Offset * 8) + Remaining = Bit_Len);
         exit when Remaining < 64;
         W := W xor Data (Data'First + Offset + 7);
         Offset    := Offset + 8;
         Remaining := Remaining - 64;
      end loop;
   end Ok_Division;

   procedure Ok_Constant (Data : Byte_Array; W : out Unsigned_8) is
      Last : constant Natural := Data'First + 39;
   begin
      W := 0;
      for X in Coord loop
         W := W xor Data (Last - Natural (X));
      end loop;
   end Ok_Constant;

   --  C is 4 on the last iteration.
   procedure Bad_Inner_Constant (W : out Integer) is
   begin
      W := 0;
      for X in Coord loop
         declare
            C : constant Integer := Integer (X);
         begin
            W := 10 / (4 - C);
         end;
      end loop;
   end Bad_Inner_Constant;

   --  Y and X are equal three times.
   procedure Bad_Outer_Parameter (W : out Integer) is
   begin
      W := 0;
      for Y in Coord loop
         for X in Coord loop
            W := 10 / (Integer (Y) - Integer (X));
         end loop;
      end loop;
   end Bad_Outer_Parameter;

   --  N is 11 on the second iteration, whatever it was entered with.
   procedure Bad_In_Out (N : in out Natural; W : out Integer) is
   begin
      W := 0;
      for X in Coord loop
         W := 10 / (11 - N);
         N := 11;
      end loop;
   end Bad_In_Out;

   --  Len <= Data'Length only where the test says so.
   procedure Bad_One_Way (Data : Byte_Array; Len : Natural; W : out Unsigned_8)
   is
      Remaining : Natural := Len;
      Offset    : Natural := 0;
   begin
      W := 0;
      for X in Coord loop
         pragma Loop_Invariant (Offset + Remaining = Len);
         exit when Remaining < 8;
         if Len <= Data'Length then
            W := W xor 1;
         end if;
         W := W xor Data (Data'First + Offset + 7);
         Offset    := Offset + 8;
         Remaining := Remaining - 8;
      end loop;
   end Bad_One_Way;
end Verification_Loop_Standing_Facts;
