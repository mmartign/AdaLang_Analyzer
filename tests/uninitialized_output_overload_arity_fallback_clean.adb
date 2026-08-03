with System;
procedure Uninitialized_Output_Overload_Arity_Fallback_Clean is

   --  Two same-named overloads, one forwarding to the other with purely
   --  positional actuals, where the wider overload carries a
   --  System.Address-typed formal. Libadalang's own imprecise-fallback
   --  resolution of the call's callee name (Call.F_Name.P_Referenced_Decl)
   --  resolves this shape back to the *enclosing* (narrower) overload
   --  itself rather than the sibling actually being called -- a further
   --  instance of the general resolution fragility already documented for
   --  FP-008/FP-012/FP-018. Forwarding Status positionally to the 6-arg
   --  sibling must still count as writing it.
   type Status_T is (Ok, Err);

   procedure Transmit_And_Check
     (Command  : String;
      Expect   : String;
      Received : System.Address;
      Length   : Natural;
      Status   : out Status_T);

   procedure Transmit_And_Check
     (Command : String;
      Expect  : String;
      Status  : out Status_T);

   procedure Transmit_And_Check
     (Command  : String;
      Expect   : String;
      Received : System.Address;
      Length   : Natural;
      Status   : out Status_T)
   is
   begin
      Status := Ok;
   end Transmit_And_Check;

   procedure Transmit_And_Check
     (Command : String;
      Expect  : String;
      Status  : out Status_T)
   is
   begin
      Transmit_And_Check
        (Command, Expect, System.Null_Address, Expect'Length, Status);
   end Transmit_And_Check;

   S : Status_T;
begin
   Transmit_And_Check ("a", "b", S);
end Uninitialized_Output_Overload_Arity_Fallback_Clean;
