--  A library that the legacy project links to: its sources resolve the
--  names the project uses, and are not analyzed with it.
package Units is
   --  This comment is longer than the 120 characters a line may have, so that Long_Line reports it when the file is analyzed.
   subtype Volts is Integer range 0 .. 400;
   Limit : constant Volts := 230;
end Units;
