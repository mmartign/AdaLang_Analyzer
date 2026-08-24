procedure Precision_Null_Case_Alternative_Pragma_Assert_Clean is
   type Mode is (Idle, Active);
   M : Mode := Idle;
   X : Integer := 0;
begin
   case M is
      when Idle =>
         pragma Assert (False);
      when Active =>
         X := 1;
   end case;
end Precision_Null_Case_Alternative_Pragma_Assert_Clean;
