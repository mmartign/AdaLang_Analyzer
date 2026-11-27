--  Precision regression for Wrong_Parameter_Mode (FP-187, libgfxinit's
--  Check_PP_Delays): an in out parameter that is written, never read, but
--  only on some paths keeps the caller's value on the others; mode out
--  would lose it.
procedure Precision_Wrong_Parameter_Mode_Conditional_Write_Clean is
   type Arr is array (1 .. 3) of Natural;

   procedure Check (A : in out Arr; Override : in out Boolean) is
   begin
      for I in A'Range loop
         if A (I) = 0 then
            A (I) := 1;
            Override := True;
         end if;
      end loop;
   end Check;

   X : Arr := (0, 1, 2);
   O : Boolean := False;
begin
   Check (X, O);
end Precision_Wrong_Parameter_Mode_Conditional_Write_Clean;
