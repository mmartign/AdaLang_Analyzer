procedure Access_To_Subprogram_Actuals_Guard is
   type Status_T is (Ready, Failed);

   type Receiver
     (Receive : not null access procedure (Status : out Status_T))
   is null record;

   procedure Forward
     (This      : Receiver;
      Status    : out Status_T;
      Untouched : out Status_T)
   is
   begin
      This.Receive (Status);
      --  Untouched must remain reported: resolving the indirect-call profile
      --  must credit only the actual that is really forwarded.
   end Forward;

   procedure Set_Status (Status : out Status_T) is
   begin
      Status := Ready;
   end Set_Status;

   Device : Receiver (Set_Status'Access);
   A, B   : Status_T;
begin
   Forward (Device, A, B);
end Access_To_Subprogram_Actuals_Guard;
