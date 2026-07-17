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

begin
   Set_Shared;
   Result := 10 / Shared;
end Spark_Clean;
