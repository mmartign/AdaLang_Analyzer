procedure Precision_Null_Case_Alternative_Others_Clean is
   type Mode is (Idle, Active, Draining);
   M : Mode := Idle;
   X : Integer := 0;
begin
   case M is
      when Active =>
         X := 1;
      when others =>
         null;
   end case;
end Precision_Null_Case_Alternative_Others_Clean;
