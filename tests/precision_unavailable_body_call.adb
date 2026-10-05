with Precision_Global_Pack;
procedure Precision_Unavailable_Body_Call is
   procedure Unknown with Import;

   type Proc_A is access procedure (X : Integer);
   Handler : constant Proc_A := Precision_Global_Pack.External'Access;
   Value   : Integer := 0;
begin
   Unknown;
   Precision_Global_Pack.External (1);
   Handler (1);
   Precision_Global_Pack.Available (Value);
end Precision_Unavailable_Body_Call;
