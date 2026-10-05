--  The counterpart of Precision_Guarded_Operand_Clean (FP-106): Count is
--  zero and each guard below lets evaluation through, so the division, the
--  indexing and the conversion are evaluated and fail.
procedure Precision_Guarded_Operand_Finding
  (Total : Integer; Result : out Boolean)
is
   subtype Small is Integer range 1 .. 10;
   type Vector is array (1 .. 4) of Integer;

   Table : constant Vector := (others => 1);
   Count : Natural := 0;
begin
   Result := Count >= 0 and then Total / Count > 1;
   Result := Result or else (Count = 0 and then Table (Count) = 1);
   Result := Result or else (Count > 0 or else Small (Count) = 3);
end Precision_Guarded_Operand_Finding;
