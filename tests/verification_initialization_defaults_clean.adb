procedure Verification_Initialization_Defaults_Clean
  (Data : out String)
is
   type Record_With_Default is record
      Value : Integer := 0;
   end record;

   Source : Integer := 1;
   Copy   : Integer renames Source;
   Item   : Record_With_Default;
   Mirror : Record_With_Default := Item;
   Backing : aliased Integer := 1;
   Overlay : Integer with Address => Backing'Address;
   Element : Character := Data (Data'First);
begin
   pragma Assert (Copy = Source);
   Mirror := Item;
   pragma Assert (Overlay = Backing);
   Data (Data'First) := Element;
end Verification_Initialization_Defaults_Clean;
