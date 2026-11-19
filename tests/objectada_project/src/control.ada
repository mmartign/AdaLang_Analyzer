--  Two compilation units in one file, which ObjectAda allows.
with Units;
package Control is
   procedure Step (Level : Units.Volts);
end Control;

with Sensors;
package body Control is
   procedure Step (Level : Units.Volts) is
      Next  : Sensors.Channel := Sensors.Last_Channel;
      Over  : Units.Volts := Units.Limit;
      Value : Integer;
   begin
      Next := Sensors.Last_Channel + 1;
      Over := Units.Limit * 2;
      Sensors.Read (Next, Value);
      if Level > Over then
         null;
      end if;
   end Step;
end Control;
