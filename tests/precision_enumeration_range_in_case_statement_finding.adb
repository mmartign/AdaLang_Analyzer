procedure Precision_Enumeration_Range_In_Case_Statement_Finding is
   type Day is (Mon, Tue, Wed, Thu, Fri, Sat, Sun);
   D : constant Day := Tue;
   Working : Boolean := False;
begin
   case D is
      when Mon .. Fri =>
         Working := True;
      when Sat | Sun =>
         Working := False;
   end case;
   pragma Assert (Working);
end Precision_Enumeration_Range_In_Case_Statement_Finding;
