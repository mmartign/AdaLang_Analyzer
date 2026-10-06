package body Verification_Mutation_Call_Frame with SPARK_Mode is

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

   procedure Refill (Target : in out Box) is
   begin
      Target.Value := 9;
   end Refill;

   procedure Drop (Value : in out Natural) is
   begin
      Value := 0;
   end Drop;

   procedure Actual_Written (Size : Natural) is
      Got  : constant Natural := 0;
      Rest : Natural := Size;
   begin
      Fetch (Rest);
      pragma Assert (Got + Rest = Size);
   end Actual_Written;

   procedure Global_Written is
      Mirror : constant Natural := Total;
   begin
      Log (1);
      pragma Assert (Mirror = Total);
   end Global_Written;

   procedure Local_Reached is
      Count : Natural := 0;
      Copy  : Natural;

      procedure Bump is
      begin
         Count := Count + 1;
      end Bump;
   begin
      Copy := Count;
      Bump;
      pragma Assert (Copy = Count);
   end Local_Reached;

   procedure Effects_Unknown is
      Seen : constant Natural := Total;
   begin
      External;
      pragma Assert (Seen = Total);
   end Effects_Unknown;

   procedure Component_Written (Held_Box : in out Box) is
      Held : constant Natural := Held_Box.Value;
   begin
      Refill (Held_Box);
      pragma Assert (Held = Held_Box.Value);
   end Component_Written;

   procedure Lowered (Level : in out Natural) is
   begin
      Drop (Level);
   end Lowered;

end Verification_Mutation_Call_Frame;
