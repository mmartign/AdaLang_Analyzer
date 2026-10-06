package body Verification_Call_Frame with SPARK_Mode is

   procedure Log (Value : Natural) is
   begin
      if Total <= 1000 then
         Total := Total + Value mod 2;
      end if;
   end Log;

   procedure Fetch (Item : out Natural) is
   begin
      Item := 7;
   end Fetch;

   procedure Kept (Length : Natural) is
      Offset    : constant Natural := 0;
      Remaining : constant Natural := Length;
      Item      : Natural;
   begin
      Fetch (Item);
      pragma Assert (Offset + Remaining = Length);
      Log (Item);
      pragma Assert (Remaining = Length - Offset);
   end Kept;

   procedure Kept_In_Loop (Length : Natural) is
      Offset    : Natural := 0;
      Remaining : Natural := Length;
      Item      : Natural;
   begin
      while Remaining >= 8 loop
         pragma Loop_Invariant (Offset + Remaining = Length);
         Fetch (Item);
         Log (Item);
         Offset := Offset + 8;
         Remaining := Remaining - 8;
      end loop;
   end Kept_In_Loop;

end Verification_Call_Frame;
