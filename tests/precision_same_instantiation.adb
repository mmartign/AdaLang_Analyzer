procedure Precision_Same_Instantiation is
   generic
      type T is private;
      X : Integer;
   package Gen is
      Value : Integer := X;
   end Gen;

   package First is new Gen (Integer, 2);
   package Second is new Gen (Integer, 2);
   package Third is new Gen (Integer, 5);
begin
   First.Value := Second.Value + Third.Value;
end Precision_Same_Instantiation;
