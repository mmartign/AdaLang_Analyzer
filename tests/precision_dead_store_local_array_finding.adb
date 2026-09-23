procedure Precision_Dead_Store_Local_Array_Finding (Result : out Character) is
   Buffer : String (1 .. 3) := "abc";
begin
   Result := Buffer (2);
   Buffer (1) := 'X';
end Precision_Dead_Store_Local_Array_Finding;
