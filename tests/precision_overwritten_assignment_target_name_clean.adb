--  Overwritten_Assignment, Dead_Store: a target name, "@" (RM 5.2.1),
--  reads the target of its assignment, so the value it reads is neither
--  overwritten before it is read nor never read (AWS's HPACK Huffman
--  decoder, SOAP.Utils).

function Precision_Overwritten_Assignment_Target_Name_Clean
  (X : Integer) return Integer
is
   T : Integer;
begin
   T := X * 3;
   T := @ + 1;
   return T;
end Precision_Overwritten_Assignment_Target_Name_Clean;
