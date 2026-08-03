with System;
procedure Uninitialized_Read_Import_Overlay_Clean
  (Buffer_Addr : System.Address)
is
   --  An object with the Import aspect gets its value from outside the
   --  Ada code -- here, an overlay onto a buffer some other layer (DMA, a
   --  driver call) already populated -- so its first Ada-level mention
   --  being a read is the expected shape, not a bug. Data_Flow.Is_
   --  Externally_Observable already recognizes an Address aspect (present
   --  on every "with Import, Address => ..." overlay, since Import alone
   --  needs somewhere to import from) for Dead_Store/Overwritten_
   --  Assignment/Repeated_Statement (see FP-003); Uninitialized_Read must
   --  make the same exemption for reads.
   L : Character with Import, Address => Buffer_Addr;
   R : Character;
begin
   R := L;
end Uninitialized_Read_Import_Overlay_Clean;
