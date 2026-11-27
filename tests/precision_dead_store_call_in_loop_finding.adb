--  At the shape of the loop-store regression (FP-186): the value a call
--  stores into R on each pass is never read, in the loop or after it.
--  Must fire.
procedure Precision_Dead_Store_Call_In_Loop_Finding is
   type Req is array (0 .. 3) of Integer;

   procedure Fill (R : out Req; Cmd : Integer) is
   begin
      R := (others => Cmd);
   end Fill;

   procedure Loop_Fill (N : Integer) is
      R : Req;
   begin
      for I in 1 .. N loop
         Fill (R, I);
      end loop;
   end Loop_Fill;
begin
   Loop_Fill (3);
end Precision_Dead_Store_Call_In_Loop_Finding;
