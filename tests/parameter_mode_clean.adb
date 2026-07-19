--  Negative fixture: the parameter's incoming and outgoing values are both
--  semantically relevant, even though the caller does not read it afterward.
procedure Parameter_Mode_Clean is
   procedure Consume_And_Update (Value : in out Integer) is
   begin
      Value := Value + 1;
   end Consume_And_Update;

   Item : Integer := 1;
begin
   Consume_And_Update (Item);
end Parameter_Mode_Clean;
