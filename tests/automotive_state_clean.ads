package Automotive_State_Clean is
   Initialized : Integer := 0;

   type Payload is record
      Ready : Integer := 0;
   end record;

   Device_Register : Integer := 0
     with Volatile, Atomic;
end Automotive_State_Clean;
