procedure Verification_Call_Clean
  with SPARK_Mode
is
   Value : Integer := 0;

   procedure Set_Two (Output : out Integer)
   with
     Global => null,
     Post   => Output = 2;

   procedure Set_Two (Output : out Integer) is
   begin
      Output := 2;
   end Set_Two;
begin
   Set_Two (Value);
   pragma Assert (Value = 2);
end Verification_Call_Clean;
