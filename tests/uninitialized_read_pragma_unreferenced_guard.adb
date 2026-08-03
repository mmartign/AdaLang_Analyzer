procedure Uninitialized_Read_Pragma_Unreferenced_Guard is

   --  Same colliding shape as the clean sibling, but this time the bare
   --  identifier is the condition of an executable pragma (Assert, not
   --  Unreferenced): Assert genuinely evaluates its argument when
   --  execution reaches it, so a read before assignment here must still
   --  be flagged.
   Is_Ready : Boolean;

begin
   pragma Assert (Is_Ready);
   Is_Ready := True;
end Uninitialized_Read_Pragma_Unreferenced_Guard;
