procedure Uninitialized_Read_Import_Overlay_Guard is
   --  An ordinary scalar local with no Import/Address/Volatile/Atomic
   --  aspect at all must still be flagged when read before its first
   --  assignment: the exemption is specific to externally-observable
   --  declarations, not a general loosening of the check.
   L : Character;
   R : Character;
begin
   R := L;
end Uninitialized_Read_Import_Overlay_Guard;
