--  At the shape of the pragma Debug regression (FP-182): the same call
--  outside pragma Debug writes a state the Global aspect leaves out.
--  Must fire.
procedure Precision_Global_Contract_Mismatch_Pragma_Debug_Finding
  with SPARK_Mode
is
   package Log with Abstract_State => Lines, Initializes => Lines is
      procedure Put_Line (Item : String) with Global => (In_Out => Lines);
   end Log;

   package body Log with Refined_State => (Lines => Count) is
      Count : Natural := 0;
      procedure Put_Line (Item : String) with Refined_Global => (In_Out => Count) is
      begin
         if Count < Natural'Last - Item'Length then
            Count := Count + Item'Length;
         end if;
      end Put_Line;
   end Log;

   X : Integer := 0;

   procedure Step (A : Integer)
     with Global => (In_Out => X), Depends => (X => (X, A))
   is
   begin
      Log.Put_Line ("step");
      if X < Integer'Last - 10 and then A in 0 .. 10 then
         X := X + A;
      end if;
   end Step;
begin
   Step (1);
end Precision_Global_Contract_Mismatch_Pragma_Debug_Finding;
