--  Each resource leak check here holds, and GNATprove proves it:
--  - an assignment over an out parameter on entry, over what was moved
--    just before, and over a component a precondition says is null;
--  - an assignment whose value moves the target's own owning parts first
--    (a named or positional aggregate of them, 'Update);
--  - an out actual: a local declared without a value, a component of
--    which a precondition says it is null, an out parameter on entry, a
--    buffer a postcondition says is null;
--  - a local at the end of its scope, on every way out of it (a goto
--    among them): moved, given back, freed by Free or by an instance of
--    Ada.Unchecked_Deallocation itself, null on one path and moved on the
--    other.
--  verification_mutation_resource_leaks has what does not hold.
with Ada.Unchecked_Deallocation;

package body Verification_Resource_Leaks with SPARK_Mode is

   procedure Dealloc is new Ada.Unchecked_Deallocation (Bytes, Bytes_Ptr);

   procedure Free (P : in out Bytes_Ptr) is
   begin
      Dealloc (P);
   end Free;

   procedure Initialize (Ctx : out Context; Buffer : in out Bytes_Ptr) is
   begin
      Ctx := (Buffer => Buffer, Last => 0);
      Buffer := null;
   end Initialize;

   procedure Take_Buffer (Ctx : in out Context; Buffer : out Bytes_Ptr) is
   begin
      Buffer := Ctx.Buffer;
      Ctx.Buffer := null;
   end Take_Buffer;

   procedure Give_Back (Ctx : in out Context; Buffer : in out Bytes_Ptr) is
   begin
      Ctx.Buffer := Buffer;
      Buffer := null;
   end Give_Back;

   procedure Bump (Ctx : in out Context) is
   begin
      if Ctx.Last < Natural'Last then
         Ctx.Last := Ctx.Last + 1;
      end if;
   end Bump;

   procedure Reset_Named (Ctx : in out Context) is
   begin
      Ctx := (Buffer => Ctx.Buffer, Last => 0);
   end Reset_Named;

   procedure Reset_Update (Ctx : in out Context) is
   begin
      Ctx := Ctx'Update (Last => 1);
   end Reset_Update;

   procedure Reset_Positional (Ctx : in out Context) is
   begin
      Ctx := (Ctx.Buffer, 2);
   end Reset_Positional;

   procedure Switch (Ctx : in out Context; Elem : out Context) is
      Switch_Buffer : Bytes_Ptr := Ctx.Buffer;
   begin
      Ctx.Buffer := null;
      Initialize (Elem, Switch_Buffer);
   end Switch;

   procedure Switch_Data (Pdu : in out Context; Sdu : out Context) is
      Data_Buffer : Bytes_Ptr;
   begin
      Take_Buffer (Pdu, Data_Buffer);
      Initialize (Sdu, Data_Buffer);
   end Switch_Data;

   procedure Update (Ctx : in out Context; Elem : in out Context) is
      Update_Buffer : Bytes_Ptr;
   begin
      Take_Buffer (Elem, Update_Buffer);
      Ctx.Buffer := Update_Buffer;
   end Update;

   procedure Step (O : in out Outer; Fail : Boolean) is
   begin
      declare
         Step_Tmp : Context := O.Inner;
      begin
         if Fail then
            O.State := 1;
            O.Inner := Step_Tmp;
            goto Done;
         end if;
         Bump (Step_Tmp);
         O.Inner := Step_Tmp;
      end;
      <<Done>>
   end Step;

   procedure Alloc (S : out Slots) is
   begin
      S := (S1 => new Bytes'(1 .. 8 => 0), S2 => new Bytes'(1 .. 8 => 0));
   end Alloc;

   procedure Free_Slots (S : in out Slots) is
   begin
      Free (S.S1);
      Free (S.S2);
   end Free_Slots;

   procedure Start (M : in out Machine) is
      Start_1 : Bytes_Ptr;
      Start_2 : Bytes_Ptr;
   begin
      Alloc (M.Slot);
      Start_1 := M.Slot.S1;
      M.Slot.S1 := null;
      Initialize (M.A, Start_1);
      Start_2 := M.Slot.S2;
      M.Slot.S2 := null;
      Initialize (M.B, Start_2);
   end Start;

   procedure Stop (M : in out Machine) is
      Stop_1 : Bytes_Ptr;
      Stop_2 : Bytes_Ptr;
   begin
      Take_Buffer (M.A, Stop_1);
      pragma Assert (M.Slot.S1 = null);
      M.Slot.S1 := Stop_1;
      Take_Buffer (M.B, Stop_2);
      M.Slot.S2 := Stop_2;
      Free_Slots (M.Slot);
   end Stop;

   procedure Encode (N : Positive) is
      Enc_Cxt : Context;
      Enc_Buf : Bytes_Ptr := new Bytes'(1 .. N => 0);
   begin
      Initialize (Ctx => Enc_Cxt, Buffer => Enc_Buf);
      Bump (Enc_Cxt);
      Take_Buffer (Ctx => Enc_Cxt, Buffer => Enc_Buf);
      Free (Enc_Buf);
   end Encode;

   procedure Join (Ctx : in out Context; C : Boolean) is
      Join_Buffer : Bytes_Ptr := new Bytes'(1 .. 4 => 0);
   begin
      if C then
         Ctx.Buffer := Join_Buffer;
      else
         Free (Join_Buffer);
      end if;
   end Join;

   procedure Free_Direct is
      Direct_Buffer : Bytes_Ptr := new Bytes'(1 .. 2 => 0);
   begin
      Dealloc (Direct_Buffer);
   end Free_Direct;

end Verification_Resource_Leaks;
