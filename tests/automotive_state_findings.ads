package Automotive_State_Findings is
   function Initialize return Integer;

   Uninitialized : Integer;

   type Payload is record
      Missing_Default : Integer;
      Ready           : Integer := 0;
   end record;

   Device_Register : Integer with Volatile;

   Sized : Integer := 0;
   for Sized'Size use 32;

   Elaborated_By_Call : Integer := Initialize;
end Automotive_State_Findings;
