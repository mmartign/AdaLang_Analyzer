package body Verification_Static_Constants_External is
   procedure Bad_Volatile (W : out Integer) is
   begin
      W := 10 / (Port - 7);
   end Bad_Volatile;

   --  Overlay is Counter, which may be 7 by now.
   procedure Bad_Overlay (W : out Integer) is
   begin
      W := 10 / (Overlay - 7);
   end Bad_Overlay;
end Verification_Static_Constants_External;
