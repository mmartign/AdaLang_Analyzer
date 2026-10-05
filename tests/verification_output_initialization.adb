procedure Verification_Output_Initialization
  with SPARK_Mode
is
   type Triple is array (1 .. 3) of Integer;

   --  Assigned on the only path.
   procedure Set_Always (Assigned : out Integer) is
      Local : Integer;
   begin
      Local := 1;
      Assigned := Local;
   end Set_Always;

   --  Assigned on both branches.
   procedure Set_Both (Flag : Boolean; Branches : out Integer) is
   begin
      if Flag then
         Branches := 1;
      else
         Branches := 2;
      end if;
   end Set_Both;

   --  Assigned as a whole.
   procedure Set_Whole (Aggregate : out Triple) is
   begin
      Aggregate := (others => 0);
   end Set_Whole;

   --  Initialized by a callee that always assigns its out parameter.
   procedure Set_Through (Forwarded : out Integer) is
   begin
      Set_Always (Forwarded);
   end Set_Through;

   Value : Integer;
   Items : Triple;
begin
   Set_Always (Value);
   Set_Both (True, Value);
   Set_Through (Value);
   Set_Whole (Items);
   pragma Assert (Items (1) = 0 or else Value /= 0 or else Value = 0);
end Verification_Output_Initialization;
