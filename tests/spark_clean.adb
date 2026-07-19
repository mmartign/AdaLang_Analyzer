--  A Global/Depends output must invalidate a value known before the call.
procedure Spark_Clean is
   Shared : Integer := 0;
   Result : Integer := 0;

   procedure Set_Shared
     with Global  => (Output => Shared),
          Depends => (Shared => null)
   is
   begin
      Shared := 1;
   end Set_Shared;

   procedure Requires_Positive (X : Integer)
     with Pre  => X > 0,
          Post => X > 0
   is
   begin
      null;
   end Requires_Positive;

   procedure Set_Positive (X : out Integer)
     with Post => X > 0
   is
   begin
      X := 1;
   end Set_Positive;

   Value : Integer := 1;

begin
   Requires_Positive (Value);
   Set_Positive (Value);
   Set_Shared;
   Result := 10 / Shared;
end Spark_Clean;
