procedure Precision_Duplicate_Subprogram_Trivial_Clean is

   procedure Reset_A (X : out Integer) is
   begin
      X := 0;
   end Reset_A;

   procedure Reset_B (X : out Integer) is
   begin
      X := 0;
   end Reset_B;

begin
   null;
end Precision_Duplicate_Subprogram_Trivial_Clean;
