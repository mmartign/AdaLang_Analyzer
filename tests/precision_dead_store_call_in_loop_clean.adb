--  Precision regression for Dead_Store (FP-186, libgfxinit's
--  I2C_Out_Packet): the value a call stores into R at the end of a loop
--  pass is read on the next pass, before the call in the text.
procedure Precision_Dead_Store_Call_In_Loop_Clean is
   type Req is array (0 .. 3) of Integer;

   procedure Fill (R : out Req; Cmd : Integer) is
   begin
      R := (others => Cmd);
   end Fill;

   procedure Send (R : Req; Ok : out Boolean) is
   begin
      Ok := R (0) > 0;
   end Send;

   procedure Out_Packet (Cmd : Integer; Ok : out Boolean) is
      R : Req;
   begin
      Fill (R, Cmd);
      loop
         Send (R, Ok);
         exit when not Ok;
         Fill (R, Cmd - 1);
      end loop;
   end Out_Packet;

   B : Boolean;
begin
   Out_Packet (3, B);
   if B then
      null;
   end if;
end Precision_Dead_Store_Call_In_Loop_Clean;
