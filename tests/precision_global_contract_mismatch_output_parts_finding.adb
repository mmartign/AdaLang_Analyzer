--  At the shape of the KeyStore regression (FP-189): a component of the
--  Output global is read on a path where it was not written first. Must
--  fire.
procedure Precision_Global_Contract_Mismatch_Output_Parts_Finding
  with SPARK_Mode
is
   package Store with Abstract_State => Info_State,
     Initializes => Info_State
   is
      procedure Init (Key : Natural) with Global => (Output => Info_State);
   end Store;

   package body Store with Refined_State => (Info_State => Info) is
      type Info_T is record
         Present : Boolean;
         Owner   : Natural;
      end record;

      Info : Info_T := (Present => False, Owner => 0);

      procedure Init (Key : Natural)
        with Refined_Global => (Output => Info)
      is
      begin
         if Key /= 0 then
            Info.Present := True;
         end if;
         Info.Owner := (if Info.Present then Key else 0);
         Info.Present := Info.Owner /= 0;
      end Init;
   end Store;
begin
   Store.Init (1);
end Precision_Global_Contract_Mismatch_Output_Parts_Finding;
