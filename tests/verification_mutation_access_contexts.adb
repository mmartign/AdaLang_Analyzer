package body Verification_Mutation_Access_Contexts
  with SPARK_Mode
is
   procedure Reset_A (Broken_Order : in out Context) is
   begin
      Broken_Order.Cursors (F_A) := (State => S_Invalid, others => <>);
   end Reset_A;

   procedure Lower (Lowered : in out Context) is
   begin
      Lowered.Verified_Last := Lowered.First - 1;
   end Lower;

   procedure Overrun_C (Overrun : in out Context) is
   begin
      Overrun.Cursors (F_C) :=
        (State => S_Valid, First => Overrun.First,
         Last => Overrun.Verified_Last + 1);
   end Overrun_C;

   procedure Two_Buffers (Left, Right : Context; Same : out Boolean) is
   begin
      pragma Assert (Left.Buffer'Last = Right.Buffer'Last);
      Same := True;
   end Two_Buffers;

   procedure Other_Formal (Mine, Theirs : Context; Same : out Boolean) is
   begin
      pragma Assert (Ends_At (Theirs.Buffer, Mine.Buffer_Last));
      Same := True;
   end Other_Formal;

   procedure Wrong_Bound (Holder : Context) is
   begin
      pragma Assert (Holder.Buffer'First = Holder.Buffer_Last);
   end Wrong_Bound;

   procedure Drop (Gone : in out Context) is
   begin
      Gone.Buffer := null;
      pragma Assert (Gone.Buffer /= null);
   end Drop;

   procedure None_Formed (Idle : Context) is
   begin
      pragma Assert (for some F in Field => Well_Formed (Idle.Cursors (F)));
   end None_Formed;

   procedure Grow (Final : out Index) is
      P : Bytes_Ptr := new Bytes'(1 .. 1 => 0);
      Q : Bytes_Ptr := null;
   begin
      for I in Index range 2 .. 3 loop
         Q := P;
         P := new Bytes'(1 .. I => 0);
         pragma Assert (P'Last = Q'Last);
      end loop;
      Final := P'Last;
   end Grow;
end Verification_Mutation_Access_Contexts;
