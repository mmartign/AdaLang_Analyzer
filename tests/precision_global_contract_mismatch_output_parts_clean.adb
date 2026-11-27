--  Precision regression for Global_Contract_Mismatch (FP-189, tokeneer's
--  KeyStore.Init): an Output global of a record type written a component
--  at a time, each component read only after it is written, on every
--  path. Must not fire.
procedure Precision_Global_Contract_Mismatch_Output_Parts_Clean
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
         Info.Present := Key /= 0;
         if Info.Present then
            Info.Owner := Key;
         else
            Info.Owner := 0;
         end if;
      end Init;
   end Store;
begin
   Store.Init (1);
end Precision_Global_Contract_Mismatch_Output_Parts_Clean;
