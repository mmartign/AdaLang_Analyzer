procedure Precision_Function_Out_Parameter_Clean is
   function Next (Counter : in Integer) return Integer is
   begin
      return Counter + 1;
   end Next;

   procedure Bump (Counter : in out Integer) is
   begin
      Counter := Next (Counter);
   end Bump;

   C : Integer := 0;
begin
   Bump (C);
end Precision_Function_Out_Parameter_Clean;
