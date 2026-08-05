procedure Precision_Multiple_Return_Nested_Clean is
   function Inner (X : Integer) return Integer is
   begin
      return abs X;
   end Inner;

   function Outer (X : Integer) return Integer is
   begin
      return Inner (X);
   end Outer;

   Result : Integer;
begin
   Result := Outer (5);
end Precision_Multiple_Return_Nested_Clean;
