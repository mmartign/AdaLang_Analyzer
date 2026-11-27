--  At the shape of the declaration-call regression (FP-185): the call in
--  the declaration is given the out parameter as an in actual, which sets
--  nothing. Must fire.
procedure Precision_Uninitialized_Output_Declaration_Call_In_Finding is
   function Twice (V : Integer) return Integer is (2 * V);

   procedure Map (Addr : out Integer; Ok : out Boolean) is
      Ret : constant Integer := Twice (Addr);
   begin
      Ok := Ret = 0;
   end Map;

   A : Integer;
   B : Boolean;
begin
   Map (A, B);
end Precision_Uninitialized_Output_Declaration_Call_In_Finding;
