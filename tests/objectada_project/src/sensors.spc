--  Sensor channels. The file is named as ObjectAda projects often name
--  specifications, not as GNAT would.
package Sensors is
   subtype Channel is Integer range 1 .. 8;
   Last_Channel : constant Channel := 8;

   procedure Read (Number : Channel; Value : out Integer);
end Sensors;
