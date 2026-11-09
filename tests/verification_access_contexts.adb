package body Verification_Access_Contexts
  with SPARK_Mode
is
   procedure Take_Buffer (Taken : in out Context; Buffer : out Bytes_Ptr) is
   begin
      Buffer := Taken.Buffer;
      Taken.Buffer := null;
   end Take_Buffer;

   procedure Reset_C (Cleared : in out Context) is
   begin
      Cleared.Cursors (F_C) := (State => S_Invalid, others => <>);
   end Reset_C;

   procedure Verify_All (Verified : in out Context) is
   begin
      Verified.Verified_Last := Verified.Written_Last;
   end Verify_All;

   procedure Set_Last (Updated : in out Context; L : Bit_Length) is
   begin
      Updated := Updated'Update (Verified_Last => L, Written_Last => L);
   end Set_Last;

   procedure Set_C (Placed : in out Context) is
   begin
      Placed.Cursors (F_C) :=
        (State => S_Valid, First => Placed.First,
         Last => Placed.Verified_Last);
      pragma Assert (for some F in Field => Well_Formed (Placed.Cursors (F)));
   end Set_C;

   procedure Read_Bounds (Holder : Context; Last : out Index) is
   begin
      pragma Assert (Holder.Buffer'Length > 0);
      Last := Holder.Buffer'Last;
   end Read_Bounds;
end Verification_Access_Contexts;
