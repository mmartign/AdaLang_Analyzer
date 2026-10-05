--  FP-106: Count is zero, so none of the operations below that divide by
--  it, index with it or convert it is ever evaluated. Each stands behind a
--  guard that is false, in a loop over an empty range or in a case
--  alternative that zero does not select.
procedure Precision_Guarded_Operand_Clean
  (Total : Integer; Result : out Integer)
is
   subtype Small is Integer range 1 .. 10;
   type Vector is array (1 .. 4) of Integer;

   Table : constant Vector := (others => 1);
   Count : Natural := 0;
   Seen  : Boolean;
begin
   Seen := Count > 0 and then Total / Count > 1;
   Seen := Seen or else (Count /= 0 and then Table (Count) = 1);
   Seen := Seen or else (Count = 0 or else Table (Count) = 1);
   Seen := Seen or else (Count in 1 .. 10 and then Small (Count) = 3);
   Seen := Seen
     or else (for some Step in 1 .. Count => Total / Count = Step);

   Result := (if Count = 0 then 0 else Total / Count);
   Result :=
     Result + (if Count < 0 then 1 elsif Count > 0 then Table (Count) else 0);
   Result :=
     Result + (case Count is when 1 .. 4 => Table (Count), when others => 0);

   for Step in 1 .. Count loop
      Result := Total / Count + Table (Count) + Step;
   end loop;

   case Count is
      when 1 .. 4 => Result := Table (Count);
      when others => null;
   end case;

   if Count /= 0 then
      Result := Total / Count;
   end if;

   if Seen then
      Result := 0;
   end if;
end Precision_Guarded_Operand_Clean;
