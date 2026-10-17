package body Verification_FP125_Package_Elaboration is

   function Count (X : Integer) return Integer is
   begin
      Calls := Calls + 1;
      return X;
   end Count;

   package body Counting is
   begin
      Calls := Calls + 1;
   end Counting;

   procedure Local_Body is
   begin
      Calls := 0;
      declare
         package Inner is
            Value : Integer := 0;
         end Inner;
         package body Inner is
         begin
            Calls := Calls + 1;
         end Inner;
      begin
         pragma Assert (Calls = 0);
      end;
   end Local_Body;

   procedure Local_Instance is
   begin
      Calls := 0;
      declare
         package Counted is new Counting (1);
      begin
         pragma Assert (Calls + 0 = 0);
      end;
   end Local_Instance;

   procedure Local_Specification is
   begin
      Calls := 0;
      declare
         package Inner is
            Value : constant Integer := 1;
         end Inner;
      begin
         pragma Assert (Calls - 0 = 0);
      end;
   end Local_Specification;

   procedure Specification_Initializer is
   begin
      Calls := 0;
      declare
         package Inner is
            Value : Integer := Count (1);
         end Inner;
      begin
         pragma Assert (Calls * 1 = 0);
      end;
   end Specification_Initializer;

   procedure Body_Initializer is
   begin
      Calls := 0;
      declare
         package Inner is
            function Get return Integer;
         end Inner;
         package body Inner is
            Value : Integer := Count (1);
            function Get return Integer is (Value);
         end Inner;
      begin
         pragma Assert (0 + Calls = 0);
      end;
   end Body_Initializer;

end Verification_FP125_Package_Elaboration;
