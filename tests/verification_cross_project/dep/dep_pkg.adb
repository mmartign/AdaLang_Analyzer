package body Dep_Pkg is
   function Make (S : String) return Integer is
   begin
      return S'Length;
   end Make;
end Dep_Pkg;
