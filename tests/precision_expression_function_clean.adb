package body Precision_Expression_Function_Clean is
   function Double (X : Integer) return Integer is (2 * X);

   function Triple (X : Integer) return Integer is
   begin
      return 3 * X;
   end Triple;
end Precision_Expression_Function_Clean;
