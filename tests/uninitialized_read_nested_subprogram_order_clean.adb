procedure Uninitialized_Read_Nested_Subprogram_Order_Clean is

   --  A nested subprogram body is a declaration: it is elaborated, not
   --  executed, at its own textual position. "Inner" is declared (and
   --  reads A and B as up-level references) before "Set" initializes
   --  them via its out-mode formals, but Inner is only ever actually
   --  invoked afterwards, from the "return" statement -- so A and B are
   --  never read uninitialized at runtime (observed in the wild: AWS.
   --  Headers.Values.Split's nested To_Set/Element).
   function Outer return Integer is
      A : Integer;
      B : Integer;

      function Inner return Integer is
      begin
         return A + B;
      end Inner;

      procedure Set (X : out Integer; Y : out Integer) is
      begin
         X := 1;
         Y := 2;
      end Set;

   begin
      Set (A, B);
      return Inner;
   end Outer;

   Result : Integer;
begin
   Result := Outer;
end Uninitialized_Read_Nested_Subprogram_Order_Clean;
