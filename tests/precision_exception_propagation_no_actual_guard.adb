--  A call with no actual ("return Next;") is a call: Wrap may propagate
--  what Next raises, and Exception_Propagation must fire at the call of
--  Wrap (AWS's Get_Integer, whose "B := Get_Byte_Safe;" raises
--  Protocol_Error at the end of the stream).
procedure Precision_Exception_Propagation_No_Actual_Guard is
   function Next return Integer is
   begin
      raise Program_Error;
      return 0;
   end Next;

   function Wrap (N : Integer) return Integer is
   begin
      return Next + N;
   end Wrap;

   X : Integer;
begin
   X := Wrap (1);
   pragma Assert (X > 0);
end Precision_Exception_Propagation_No_Actual_Guard;
