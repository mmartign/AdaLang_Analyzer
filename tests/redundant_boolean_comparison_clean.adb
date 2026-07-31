procedure Redundant_Boolean_Comparison_Clean is
   --  A user-declared enumeration literal spelled "True" is a homograph of
   --  Standard.True, not an instance of it: Result below is Tri_State, not
   --  Boolean, so "Result = True" is an ordinary same-type comparison, and
   --  "Result" alone would not be the equivalent expression the check's
   --  advice assumes.
   type Tri_State is (True, False, Unknown);

   function Evaluate return Tri_State is
   begin
      return Unknown;
   end Evaluate;

   Result : constant Tri_State := Evaluate;
begin
   if Result = True then
      null;
   end if;
end Redundant_Boolean_Comparison_Clean;
