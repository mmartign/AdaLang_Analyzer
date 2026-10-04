with Ada.Strings.Unbounded;

procedure Precision_Use_Package_Clause_Clean is
   use type Ada.Strings.Unbounded.Unbounded_String;
   A : constant Ada.Strings.Unbounded.Unbounded_String :=
     Ada.Strings.Unbounded.Null_Unbounded_String;
   Same : constant Boolean := A = A;
begin
   pragma Assert (Same);
end Precision_Use_Package_Clause_Clean;
