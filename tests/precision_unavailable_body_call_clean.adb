with Precision_Global_Pack;
procedure Precision_Unavailable_Body_Call_Clean is
   procedure Local (X : in out Integer);

   procedure Local (X : in out Integer) is
   begin
      X := X * 2;
   end Local;

   function Twice (X : Integer) return Integer is (X * 2);

   Value : Integer := 1;
begin
   Local (Value);
   Precision_Global_Pack.Available (Value);
   Value := Twice (Value);
end Precision_Unavailable_Body_Call_Clean;
