procedure Automotive_Additional_Findings is
   type Callback is access procedure;
   subtype Descending is Integer range 10 .. 1;

   procedure Fail is
   begin
      raise Program_Error;
   end Fail;

   Handler : Callback := Fail'Access;
   Value   : Descending;
   pragma Unreferenced (Handler, Value);
begin
   if False then
      Fail;
   end if;

   begin
      Fail;
   exception
      when others =>
         null;
   end;

   declare
      Count : Integer := 0;
   begin
      <<Retry>>
      Count := Count + 1;
      if Count < 2 then
         goto Retry;
      end if;
   end;
end Automotive_Additional_Findings;
