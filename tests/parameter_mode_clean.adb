with Ada.Containers.Vectors;

--  Negative fixture: the parameters' incoming and outgoing values are both
--  semantically relevant, including writes through components and prefixed
--  container operations.
procedure Parameter_Mode_Clean is
   package Int_Vectors is new Ada.Containers.Vectors
     (Index_Type => Positive, Element_Type => Integer);

   type State_Record is record
      Value : Integer := 0;
   end record;

   procedure Consume_And_Update (Value : in out Integer) is
   begin
      Value := Value + 1;
   end Consume_And_Update;

   procedure Update_Component (State : in out State_Record) is
   begin
      State.Value := State.Value + 1;
   end Update_Component;

   procedure Append_Value
     (Values : in out Int_Vectors.Vector; Value : Integer) is
   begin
      Values.Append (Value);
   end Append_Value;

   procedure Clear_Values (Values : in out Int_Vectors.Vector) is
   begin
      Values.Clear;
   end Clear_Values;

   Item   : Integer := 1;
   State  : State_Record;
   Values : Int_Vectors.Vector;
begin
   Consume_And_Update (Item);
   Update_Component (State);
   Append_Value (Values, Item);
   Clear_Values (Values);
end Parameter_Mode_Clean;
