procedure Dead_Store_Renaming_Of_Parameter_Field_Clean is
   type Details is (None, Some_Error);
   type State is record
      Error_Detail : Details := None;
   end record;

   --  A renaming declaration is lexically local to its enclosing
   --  subprogram, but a write through it is not: "Info" here is just
   --  another name for "Self.Error_Detail", which persists after the
   --  call returns and is read by other code entirely outside this
   --  subprogram (observed in the wild: AWS.HTTP2.Stream.Received_Frame's
   --  "Info : Error_Details renames Self.Error_Detail;", where Self is an
   --  in-out parameter). This must not be reported as a dead store.
   procedure Process (Self : in out State) is
      Info : Details renames Self.Error_Detail;
   begin
      Info := Some_Error;
   end Process;

   S : State;
begin
   Process (S);
end Dead_Store_Renaming_Of_Parameter_Field_Clean;
