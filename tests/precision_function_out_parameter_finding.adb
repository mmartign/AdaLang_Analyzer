procedure Precision_Function_Out_Parameter_Finding is
   function Next (Counter : in out Integer) return Integer is
   begin
      Counter := Counter + 1;
      return Counter;
   end Next;

   C : Integer := 0;
   R : constant Integer := Next (C);
begin
   pragma Assert (R = 1);
end Precision_Function_Out_Parameter_Finding;
