--  FP-132 boundary: once a block has ended, the bodies it declares cannot
--  be called, so the last store to Base is dead although Twice reads Base.
procedure Precision_Dead_Store_Block_Nested_Body_Finding
  (Result : out Integer)
is
   Base : Integer := 1;
begin
   declare
      function Twice return Integer is (2 * Base);
   begin
      Result := Twice;
   end;
   Base := 5;
end Precision_Dead_Store_Block_Nested_Body_Finding;
