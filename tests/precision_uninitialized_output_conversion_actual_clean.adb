--  An out actual given as a view conversion of the out parameter writes it:
--  the value is converted back on return ("Get_PGID (Proc, Unsigned_32
--  (Returned))", "Fill_Data (Crypto_Data (Data))"; Ironclad, FP-195).
with Interfaces; use Interfaces;
procedure Precision_Uninitialized_Output_Conversion_Actual_Clean
  (Result : out Unsigned_64; Data : out String)
is
   type Bytes is array (Positive range <>) of Character;
   procedure Get (V : out Unsigned_32) is
   begin
      V := 7;
   end Get;
   procedure Fill (B : out Bytes) is
   begin
      B := [others => ' '];
   end Fill;
begin
   Get (Unsigned_32 (Result));
   Fill (Bytes (Data));
end Precision_Uninitialized_Output_Conversion_Actual_Clean;
