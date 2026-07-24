with Ada.Text_IO;
with Ada.Unchecked_Conversion;

procedure Automotive_Policy_Findings is
   function Float_To_Integer is new Ada.Unchecked_Conversion
     (Float, Integer);
   function Integer_To_Float is new Ada.Unchecked_Conversion
     (Integer, Float);

   X : Integer := Float_To_Integer (0.0);

   pragma Warnings (Off, X);
begin
   Ada.Text_IO.Put_Line (Integer'Image (X));
end Automotive_Policy_Findings;
