package body Precision_Outside_Reference_Generic_Clean is
   procedure Apply (Value : in out Item) is
      Copy : constant Item := Value;

      procedure Swap is
      begin
         Value := Copy;
      end Swap;
   begin
      Swap;
   end Apply;
end Precision_Outside_Reference_Generic_Clean;
