--  The specification of Counters, named as Rational Apex names it.
package Counters is
   type Counter is range 0 .. 100;
   procedure Bump (C : in out Counter);
   procedure Reset (C : out Counter);
   --  This comment is longer than the 120 columns Long_Line allows, so that its finding shows when this unit is analyzed.
end Counters;
