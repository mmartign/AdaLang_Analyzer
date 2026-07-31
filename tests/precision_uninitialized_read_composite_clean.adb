--  Negative fixture: Uninitialized_Read only checks scalar declarations
--  (see Is_Scalar_Declaration); a record variable read before its first
--  assignment is not flagged because composite types are default
--  initialized to a well-defined state.
procedure Precision_Uninitialized_Read_Composite_Clean is
   type Point is record
      X : Integer;
      Y : Integer;
   end record;

   procedure Reads_Before_Assignment is
      P : Point;
   begin
      P := (X => P.X, Y => 0);
   end Reads_Before_Assignment;
begin
   Reads_Before_Assignment;
end Precision_Uninitialized_Read_Composite_Clean;
