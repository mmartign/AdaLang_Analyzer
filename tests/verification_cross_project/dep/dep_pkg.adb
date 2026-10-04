package body Dep_Pkg is
   function Make (S : String) return Integer is
   begin
      return S'Length;
   end Make;

   Last_Key   : Integer := 0;
   Last_Value : Integer := 0;

   procedure Store (Key : Integer; Value : Integer) is
   begin
      Last_Key := Key;
      Last_Value := Value;
   end Store;

   procedure Remember is
   begin
      Store (1, 2);
   end Remember;
end Dep_Pkg;
