procedure Uninitialized_Output_Prefixed_Clear_Clean is

   --  A parameterless prefixed procedure call ("Object.Operation;") has no
   --  Call_Expr node in Libadalang: it is represented as a bare Dotted_Name.
   --  Writing an out parameter this way (observed with AWS.Server.Push's
   --  "Queue.Clear;", forwarding to Ada.Containers.Ordered_Maps.Clear) must
   --  still count as initializing it.
   type Queue_Type is limited record
      Count : Natural := 0;
   end record;

   procedure Clear (Self : in out Queue_Type) is
   begin
      Self.Count := 0;
   end Clear;

   procedure Reset (Queue : out Queue_Type) is
   begin
      Queue.Clear;
   end Reset;

begin
   null;
end Uninitialized_Output_Prefixed_Clear_Clean;
