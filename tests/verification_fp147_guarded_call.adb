package body Verification_FP147_Guarded_Call is

   function Operating_System return Systems is (MacOS);

   procedure Windows_Only (N : Natural) is
   begin
      null;
   end Windows_Only;

   procedure Guarded (Count : Natural) is
      type Options is tagged record
         Verbose : Boolean := False;
      end record;
      Settings : Options;
   begin
      if On_Windows and then not Settings.Verbose then
         Windows_Only (Count);
      end if;
   end Guarded;

   procedure Unguarded (Total : Natural) is
      type Options is tagged record
         Verbose : Boolean := False;
      end record;
      Settings : Options;
   begin
      if not Settings.Verbose then
         null;
      end if;
      Windows_Only (Total);
   end Unguarded;

end Verification_FP147_Guarded_Call;
