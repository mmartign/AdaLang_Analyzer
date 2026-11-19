package body Sensors is
   procedure Read (Number : Channel; Value : out Integer) is
   begin
      Value := Number * 10;
   end Read;
end Sensors;
