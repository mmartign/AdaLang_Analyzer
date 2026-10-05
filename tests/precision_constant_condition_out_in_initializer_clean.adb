procedure Precision_Constant_Condition_Out_In_Initializer_Clean (Name : String; Hit : out Boolean) is
   function Lookup (N : String; Found : out Boolean) return Integer is
   begin
      Found := N'Length > 0;
      return N'Length;
   end Lookup;

   Found : Boolean := False;
   Kind  : constant Integer := Lookup (Name, Found);
begin
   if Found then
      Hit := Kind > 0;
   else
      Hit := False;
   end if;
end Precision_Constant_Condition_Out_In_Initializer_Clean;
