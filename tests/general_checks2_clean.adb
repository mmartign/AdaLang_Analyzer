procedure General_Checks2_Clean is
   type Color is (Red, Green, Blue);
   type Meters is new Integer;
   subtype Small_Meters is Meters range 0 .. 10;

   X : Integer := 1;
   Y : Integer := 2;
   C : Color := Red;
   M : Meters := 5;
   N : Small_Meters;
begin
   case C is
      when Red =>
         X := 1;
         Y := 2;
      when Green =>
         X := 2;
         Y := 1;
      when Blue =>
         X := 3;
   end case;

   N := Small_Meters (M);

   begin
      X := X + 1;
   exception
      when Constraint_Error =>
         Y := -1;
      when others =>
         Y := 0;
   end;
end General_Checks2_Clean;
