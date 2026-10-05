package body Prep_Pkg is
   procedure Reset (Value : out Integer) is
   begin
#if MODE = "demo" then
      Value := 0;
#else
      Value := 1;
#end if;
   end Reset;
end Prep_Pkg;
