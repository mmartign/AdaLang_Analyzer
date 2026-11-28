--  A write of an object declared over the out parameter, with the Address
--  aspect or an address clause, writes the out parameter; so does passing
--  that object as an out actual (Ironclad's VFS.FAT.Get_Next_Cluster and
--  Networking.Ethernet.Parse_Header, FP-194).
with Interfaces; use Interfaces;
procedure Precision_Uninitialized_Output_Overlay_Clean
  (Source : String; Word : out Unsigned_32; Half : out Unsigned_16;
   Other : out Unsigned_32)
is
   Bytes : String (1 .. 4) with Import, Address => Word'Address;
   Pair  : String (1 .. 2) with Import;
   for Pair'Address use Half'Address;
   Quad  : String (1 .. 4) with Import, Address => Other'Address;
   procedure Fill (S : out String) is
   begin
      S := [others => ' '];
   end Fill;
begin
   Bytes := Source (Source'First .. Source'First + 3);
   Pair := "ab";
   Fill (Quad);
end Precision_Uninitialized_Output_Overlay_Clean;
