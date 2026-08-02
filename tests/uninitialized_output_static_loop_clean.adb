procedure Uninitialized_Output_Static_Loop_Clean is

   procedure Decode (Value : out Natural) is
      Temporary_1 : Natural := 0;
      Temporary_2 : Natural;
   begin
      --  "1 .. 3" is a statically non-empty range, and the loop body
      --  writes Value unconditionally on every pass with no exit, return,
      --  raise, or goto anywhere inside it. The write is therefore
      --  guaranteed regardless of how many iterations actually run.
      for I in 1 .. 3 loop
         Temporary_2 := Temporary_1 * 256 + I;
         Value := Temporary_2;
         Temporary_1 := Value;
      end loop;
   end Decode;

begin
   null;
end Uninitialized_Output_Static_Loop_Clean;
