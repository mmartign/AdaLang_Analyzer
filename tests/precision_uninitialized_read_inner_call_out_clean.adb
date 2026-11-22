--  Uninitialized_Read: a call that is an actual of another call, with the
--  object as its out actual, gives it a value. The shapes of ravenadm,
--  "HT.USS (Unix.piped_command (command, status))", in a declaration and
--  in an assignment, and of BBS-BBB-Ada, "uint8_to_status (self.hw.read
--  (addr, reg, err))", a dispatching call in prefix notation (FP-171).

procedure Precision_Uninitialized_Read_Inner_Call_Out_Clean
  (Command : String; Code : out Integer)
is
   package Unix is
      function Piped_Command
        (Command : String; Status : out Integer) return String;
   end Unix;

   package body Unix is
      function Piped_Command
        (Command : String; Status : out Integer) return String is
      begin
         Status := Command'Length;
         return Command;
      end Piped_Command;
   end Unix;

   package Devices is
      type Bus is abstract tagged null record;
      type Bus_Access is access all Bus'Class;
      function Read
        (Self : Bus; Address : Natural; Error : out Integer)
         return Natural is abstract;

      type Loopback is new Bus with null record;
      overriding function Read
        (Self : Loopback; Address : Natural; Error : out Integer)
         return Natural;
   end Devices;

   package body Devices is
      overriding function Read
        (Self : Loopback; Address : Natural; Error : out Integer)
         return Natural is
      begin
         Error := 0;
         return Address;
      end Read;
   end Devices;

   function Wrap (S : String) return String is (S & "!");
   function Twice (N : Natural) return Natural is (2 * N);

   Device : constant Devices.Bus_Access := new Devices.Loopback;

   Status   : Integer;
   Result   : constant String := Wrap (Unix.Piped_Command (Command, Status));
   Again    : Integer;
   Error    : Integer;
   Doubled  : Natural;
   Text_Len : Natural;
begin
   Text_Len := Wrap (Unix.Piped_Command (Command, Again))'Length;
   Doubled := Twice (Device.Read (16#20#, Error));
   Code := Status + Again + Error + Result'Length + Text_Len + Doubled;
end Precision_Uninitialized_Read_Inner_Call_Out_Clean;
