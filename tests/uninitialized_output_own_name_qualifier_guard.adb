procedure Uninitialized_Output_Own_Name_Qualifier_Guard is

   type Rec is record
      Size : Natural;
   end record;

   procedure Wrong_Object (R : in out Rec; Size : out Natural) is
   begin
      --  "R.Size" writes a field of R, a different parameter, not the
      --  out-parameter also named "Size" -- the prefix "R" is not this
      --  procedure's own name, so this must still be flagged.
      R.Size := 0;
   end Wrong_Object;

begin
   null;
end Uninitialized_Output_Own_Name_Qualifier_Guard;
