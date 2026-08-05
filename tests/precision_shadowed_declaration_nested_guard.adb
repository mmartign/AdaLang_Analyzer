procedure Precision_Shadowed_Declaration_Nested_Guard is
   X : Integer := 1;
begin
   declare
      X : Integer := 2;
   begin
      null;
   end;
end Precision_Shadowed_Declaration_Nested_Guard;
