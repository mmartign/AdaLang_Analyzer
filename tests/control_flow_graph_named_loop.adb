procedure Control_Flow_Graph_Named_Loop
  (Leave : Boolean; Result : out Integer) is
begin
   Result := 0;
   Outer : for Row in 1 .. 3 loop
      Inner : for Column in 1 .. 3 loop
         exit Outer when Leave;
         exit Inner when Column = 2;
         Result := Result + 1;
      end loop Inner;
   end loop Outer;

   Scoped : begin
      Result := Result + 1;
   end Scoped;
end Control_Flow_Graph_Named_Loop;
