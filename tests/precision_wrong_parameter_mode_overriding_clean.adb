procedure Precision_Wrong_Parameter_Mode_Overriding_Clean is
   package Devices is
      type Device is tagged record
         Ready : Boolean := False;
      end record;
      procedure Start (This : in out Device);

      type Probe is new Device with null record;
      overriding procedure Start (This : in out Probe);
   end Devices;

   package body Devices is
      procedure Start (This : in out Device) is
      begin
         This.Ready := True;
      end Start;

      overriding procedure Start (This : in out Probe) is
      begin
         if not This.Ready then
            raise Program_Error;
         end if;
      end Start;
   end Devices;
begin
   null;
end Precision_Wrong_Parameter_Mode_Overriding_Clean;
