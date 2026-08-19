procedure Precision_Null_Case_Alternative_Guard is
   type Mode is (Idle, Active);
   M : Mode := Idle;
   X : Integer := 0;
begin
   case M is
      when Idle =>
         null;
      when Active =>
         X := 1;
   end case;
end Precision_Null_Case_Alternative_Guard;
