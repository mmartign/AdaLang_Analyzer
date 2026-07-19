--  Positive fixture for precise in-out parameter contracts.
procedure Parameter_Mode_Findings
  (Read_Only  : in out Integer;
   Write_Only : in out Integer)
is
   procedure Observe (Value : in Integer) is
   begin
      if Value = Integer'First then
         null;
      end if;
   end Observe;

   procedure Produce (Value : out Integer) is
   begin
      Value := 1;
   end Produce;
begin
   Observe (Read_Only);
   Produce (Write_Only);
end Parameter_Mode_Findings;
