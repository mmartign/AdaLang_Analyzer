procedure Precision_Enumeration_Range_In_Case_Statement_Clean (N : Integer) is
   type Day is (Mon, Tue, Wed);
   D : constant Day := Tue;
   Working : Boolean := False;
begin
   case D is
      when Mon | Tue =>
         Working := True;
      when Wed =>
         Working := False;
   end case;
   case N is
      when 1 .. 5 =>
         Working := True;
      when others =>
         Working := False;
   end case;
end Precision_Enumeration_Range_In_Case_Statement_Clean;
