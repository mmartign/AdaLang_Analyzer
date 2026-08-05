procedure Precision_Shadowed_Declaration_Sibling_Clean is
begin
   declare
      X : Integer := 1;
   begin
      null;
   end;
   declare
      X : Integer := 2;
   begin
      null;
   end;
end Precision_Shadowed_Declaration_Sibling_Clean;
