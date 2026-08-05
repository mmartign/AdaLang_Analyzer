procedure Precision_Multiple_Return_Enclosing_Guard is
   function Outer (X : Integer) return Integer is
      function Inner (Y : Integer) return Integer is
      begin
         if Y > 0 then
            return Y;
         end if;
         return -Y;
      end Inner;
   begin
      if X > 0 then
         return Inner (X);
      end if;
      return Inner (-X);
   end Outer;

   Result : Integer;
begin
   Result := Outer (5);
end Precision_Multiple_Return_Enclosing_Guard;
