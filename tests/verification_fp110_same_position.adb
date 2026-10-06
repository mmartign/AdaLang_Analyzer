package body Verification_FP110_Same_Position is
   --  What the precondition says of Checked is not known of Other, though
   --  the two are declared at the same line and column of their files.
   procedure P (Checked : Integer;
                Other : Integer) is
   begin
      pragma Assert (Other > 5);
      pragma Assert (Checked > 5);
   end P;
end Verification_FP110_Same_Position;
