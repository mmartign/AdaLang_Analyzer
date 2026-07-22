procedure General_Checks2_Findings is
   type Color is (Red, Green, Blue);
   type Meters is new Integer;

   X : Integer := 1;
   Y : Integer := 2;
   C : Color := Red;
   M : Meters := 5;
   N : Meters;
begin
   case C is
      when Red =>
         X := 1;
         Y := 2;
      when Green =>
         X := 1;
         Y := 2;
      when Blue =>
         X := 3;
   end case;

   N := Meters (M);

   begin
      X := X + 1;
   exception
      when others =>
         Y := 0;
      when Constraint_Error =>
         Y := -1;
   end;
end General_Checks2_Findings;
