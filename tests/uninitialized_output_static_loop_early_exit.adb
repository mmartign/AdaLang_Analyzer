procedure Uninitialized_Output_Static_Loop_Early_Exit is

   procedure Decode (Value : out Natural; Stop_Early : Boolean) is
   begin
      --  Same statically non-empty range ("1 .. 3") as the clean sibling
      --  case, but an exit can leave the loop before Value is ever
      --  written, e.g. on the very first iteration. This must still be
      --  flagged: a statically non-empty range only guarantees the loop
      --  runs at least once, not that every path through its body reaches
      --  the write.
      for I in 1 .. 3 loop
         if Stop_Early then
            exit;
         end if;
         Value := I;
      end loop;
   end Decode;

begin
   null;
end Uninitialized_Output_Static_Loop_Early_Exit;
