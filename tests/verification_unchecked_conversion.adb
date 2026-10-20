--  An instance of Unchecked_Conversion touches nothing outside it and its
--  result is made of its argument: the Global and Depends aspects of the
--  functions below hold, through Ada.Unchecked_Conversion and through its
--  library renaming Unchecked_Conversion alike.
with Ada.Unchecked_Conversion;
with Unchecked_Conversion;

procedure Verification_Unchecked_Conversion with SPARK_Mode is

   function To_Integer is new Ada.Unchecked_Conversion (Boolean, Integer);
   function To_Natural is new Unchecked_Conversion (Boolean, Natural);

   function Converted (X : Boolean) return Integer is (To_Integer (X))
     with Global => null, Depends => (Converted'Result => X);

   function Renamed (X : Boolean) return Natural is (To_Natural (X))
     with Global => null, Depends => (Renamed'Result => X);

   Value : Integer;
begin
   Value := Converted (True) + Renamed (False);
   pragma Unreferenced (Value);
end Verification_Unchecked_Conversion;
