procedure Access_To_Subprogram_Actuals_Clean is
   type Status_T is (Ready, Failed);

   type Receiver
     (Receive : not null access procedure
        (Status : out Status_T;
         Count  : in out Natural))
   is null record;

   type Receive_Access is not null access procedure
     (Status : out Status_T;
      Count  : in out Natural);

   type Component_Receiver is record
      Receive : Receive_Access;
   end record;

   procedure Set_Values
     (Status : out Status_T;
      Count  : in out Natural)
   is
   begin
      Status := Ready;
      Count := Count + 1;
   end Set_Values;

   procedure Forward_Output
     (This   : Receiver;
      Status : out Status_T)
   is
      Count : Natural := 0;
   begin
      This.Receive (Status, Count);
      if Status = Failed or else Count = 0 then
         null;
      end if;
   end Forward_Output;

   procedure Forward_In_Out
     (This  : Receiver;
      Count : in out Natural)
   is
      Status : Status_T;
   begin
      This.Receive (Status, Count);
      if Status = Failed or else Count = 0 then
         null;
      end if;
   end Forward_In_Out;

   procedure Forward_Component
     (This   : Component_Receiver;
      Status : out Status_T)
   is
      Count : Natural := 0;
   begin
      This.Receive (Status => Status, Count => Count);
      if Status = Failed or else Count = 0 then
         null;
      end if;
   end Forward_Component;

   Device            : Receiver (Set_Values'Access);
   Component_Device  : Component_Receiver := (Receive => Set_Values'Access);
   Status            : Status_T;
   Count             : Natural := 0;
begin
   Device.Receive (Status, Count);
   if Status = Failed then
      Count := Count + 1;
   end if;
   Forward_Output (Device, Status);
   if Status = Failed then
      Count := Count + 1;
   end if;
   Forward_In_Out (Device, Count);
   if Count = 0 then
      null;
   end if;
   Forward_Component (Component_Device, Status);
   if Status = Failed then
      null;
   end if;
end Access_To_Subprogram_Actuals_Clean;
