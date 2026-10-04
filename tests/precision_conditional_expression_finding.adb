procedure Precision_Conditional_Expression_Finding (X : Integer) is
   Y : constant Integer := (if X > 0 then 1 else 0);
   Z : constant Integer := (case Y is when 0 => 5, when others => 6);
begin
   pragma Assert (Y + Z > 0);
end Precision_Conditional_Expression_Finding;
