--  Symbolic array bounds beyond the first dimension. Each dimension of an
--  object whose bounds no declaration fixes has bounds of its own:
--  "Data'First (2)", "Data'Last (2)" and "Data'Range (2)" place an index
--  within the second dimension and say nothing about the first.
procedure Verification_Symbolic_Bounds_Dimensions (Sink : out Integer)
with
  SPARK_Mode
is
   type Grid is array (Integer range <>, Integer range <>) of Integer;

   procedure Read
     (Data   : Grid;
      Row    : Integer;
      Col    : Integer;
      Probe  : Integer;
      Result : out Integer)
   with
     Pre => Row in Data'Range (1) and then Col in Data'Range (2)
   is
   begin
      Result := Data (Row, Col);
      Result := Data (Col + 0, Row + 0);

      if Probe >= Data'First (2) and then Probe <= Data'Last (2) then
         Result := Data (Row, Probe);
         Result := Data (Probe + 0, Col);
      end if;

      if Data'Length (2) > 1 then
         Result := Data (Row, Data'First (2) + 1);
         Result := Data (Row, Data'Last (2) + 1);
         Result := Data (Data'First (1) + 1, Col);
      end if;
   end Read;

   procedure Last_Columns (Data : Grid; Total : out Integer) is
   begin
      Total := 0;
      for R in Data'Range (1) loop
         for C in Data'First (2) .. Data'Last (2) - 1 loop
            Total := Data (R, C + 1);
            Total := Data (R, C + 2);
            Total := Data (C + 1 - 0, C + 1);
         end loop;
      end loop;
   end Last_Columns;
begin
   Sink := 0;
end Verification_Symbolic_Bounds_Dimensions;
