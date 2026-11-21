package body Counters is
   procedure Bump (C : in out Counter) is
   begin
      if C < Counter'Last then
         C := C + 1;
      end if;
   end Bump;

   procedure Reset (C : out Counter) is separate;
end Counters;
