package body Abstract_Ops.Operations with SPARK_Mode is
   procedure Walk (First, Last : Index; Count : out Natural) is
   begin
      Count := 0;
      if First < Last then
         for I in First + 1 .. Last loop
            if Count < Natural'Last then
               Count := Count + 1;
            end if;
         end loop;
      end if;
   end Walk;
end Abstract_Ops.Operations;
