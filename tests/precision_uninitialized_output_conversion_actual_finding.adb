--  At the same shape, a view conversion of another object is no write of
--  the out parameter.
with Interfaces; use Interfaces;
procedure Precision_Uninitialized_Output_Conversion_Actual_Finding
  (Result : out Unsigned_64)
is
   Other : Unsigned_64;
   procedure Get (V : out Unsigned_32) is
   begin
      V := 7;
   end Get;
begin
   Get (Unsigned_32 (Other));
end Precision_Uninitialized_Output_Conversion_Actual_Finding;
