--  Positive fixture: Idx's only use is as the index inside a write
--  destination (Values (Idx) := 0). Writing Values (Idx) writes Values, not
--  Idx -- Idx's own appearance there is a read. The parameter must still be
--  flagged as read-only despite appearing inside an assignment destination.
procedure Precision_Wrong_Parameter_Mode_Index_Read is
   type Value_Array is array (Positive range 1 .. 4) of Integer;

   Values : Value_Array := (others => 0);

   procedure Zero_At (Idx : in out Positive) is
   begin
      Values (Idx) := 0;
   end Zero_At;

   Position : Positive := 2;
begin
   Zero_At (Position);
end Precision_Wrong_Parameter_Mode_Index_Read;
