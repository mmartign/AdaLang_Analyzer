package Automotive_State_Clean is
   Initialized : Integer := 0;
   Enabled     : Boolean := True;
   Letter      : Character := 'A';
   Converted   : Integer := Integer (1);
   Qualified   : Integer := Integer'(1);

   type Payload is record
      Ready : Integer := 0;
   end record;

   Default_Payload : Payload := (others => <>);

   Device_Register : Integer := 0
     with Volatile, Atomic;
end Automotive_State_Clean;
