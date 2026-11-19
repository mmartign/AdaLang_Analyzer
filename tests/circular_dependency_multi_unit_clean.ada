--  A package whose specification and body are in one file, and a package
--  that withs the first one's specification while the first one's body
--  withs it. That is legal Ada and no cycle: the body is not the
--  specification.
package Circular_Multi_Gamma is
   procedure Run;
end Circular_Multi_Gamma;

with Circular_Multi_Gamma;
package Circular_Multi_Delta is
   procedure Start renames Circular_Multi_Gamma.Run;
end Circular_Multi_Delta;

with Circular_Multi_Delta;
package body Circular_Multi_Gamma is
   Count : Natural := 0;

   procedure Run is
   begin
      Count := Count + 1;
      if Count < 2 then
         Circular_Multi_Delta.Start;
      end if;
   end Run;
end Circular_Multi_Gamma;
