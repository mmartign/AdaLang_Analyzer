with System;
procedure Uninitialized_Output_Overload_Arity_Fallback_Guard is

   --  Same resolution-fragile overload shape as the clean sibling, but the
   --  narrower overload has a second out parameter that the 4-arg call
   --  never forwards at all. The arity-based fallback must not spuriously
   --  credit "Unused" as written just because "Status" was.
   type Status_T is (Ok, Err);

   procedure Transmit_And_Check
     (Command  : String;
      Received : System.Address;
      Length   : Natural;
      Status   : out Status_T);

   procedure Transmit_And_Check
     (Command : String;
      Status  : out Status_T;
      Unused  : out Status_T);

   procedure Transmit_And_Check
     (Command  : String;
      Received : System.Address;
      Length   : Natural;
      Status   : out Status_T)
   is
   begin
      Status := Ok;
   end Transmit_And_Check;

   procedure Transmit_And_Check
     (Command : String;
      Status  : out Status_T;
      Unused  : out Status_T)
   is
   begin
      Transmit_And_Check
        (Command, System.Null_Address, Command'Length, Status);
   end Transmit_And_Check;

   S, U : Status_T;
begin
   Transmit_And_Check ("a", S, U);
end Uninitialized_Output_Overload_Arity_Fallback_Guard;
