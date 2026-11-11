--  Each subprogram leaks an owning access value, and GNATprove says the
--  leak check might fail: none may be proved.
--  - Twice: the second allocation overwrites the first;
--  - Lost: an allocated local is never freed;
--  - Busy_Out: a non-null component given as an out actual;
--  - Give_Blind: a component overwritten with no precondition that it is
--    null;
--  - Half_Move: a local moved on one path only;
--  - Overwrite: an aggregate over an in out parameter;
--  - Kept_Silent: a call that says nothing of the value it is given;
--  - Init_Over: an in out parameter given as an out actual;
--  - Tmp_Lost: a _Tmp copy never moved back;
--  - Slots_Over: slots of an in out parameter given as an out actual;
--  - Half_Free: freed on one path only;
--  - Update_Over: 'Update replaces the owning component, which is lost.
with Ada.Unchecked_Deallocation;

package body Verification_Mutation_Resource_Leaks with SPARK_Mode is

   procedure Dealloc is new Ada.Unchecked_Deallocation (Bytes, Bytes_Ptr);

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

   procedure Keep (B : in out Bytes_Ptr) is
   begin
      if B'Length > 0 then
         B.all (B'First) := 0;
      end if;
   end Keep;

   procedure Alloc (S : out Slots) is
   begin
      S := (S1 => new Bytes'(1 .. 8 => 0), S2 => new Bytes'(1 .. 8 => 0));
   end Alloc;

   procedure Twice (X : out Bytes_Ptr) is
   begin
      X := new Bytes'(1 .. 2 => 0);
      X := new Bytes'(1 .. 3 => 0);
   end Twice;

   procedure Lost is
      Lost_Buffer : constant Bytes_Ptr := new Bytes'(1 .. 2 => 0);
   begin
      pragma Assert (Lost_Buffer /= null);
   end Lost;

   procedure Busy_Out (Ctx : in out Context) is
      Holder : Context := (Buffer => new Bytes'(1 .. 2 => 0), Last => 0);
   begin
      Take_Buffer (Ctx, Holder.Buffer);
      Give_Back (Ctx, Holder.Buffer);
   end Busy_Out;

   procedure Give_Blind (Into : in out Context; From : in out Bytes_Ptr) is
   begin
      Into.Buffer := From;
      From := null;
   end Give_Blind;

   procedure Half_Move (Ctx : in out Context; C : Boolean) is
      Half_Buffer : Bytes_Ptr := new Bytes'(1 .. 2 => 0);
   begin
      if C then
         Ctx.Buffer := Half_Buffer;
      end if;
   end Half_Move;

   procedure Overwrite (Ctx : in out Context) is
   begin
      Ctx := (Buffer => null, Last => 0);
   end Overwrite;

   procedure Kept_Silent is
      Silent_Buffer : Bytes_Ptr := new Bytes'(1 .. 2 => 0);
   begin
      Keep (Silent_Buffer);
   end Kept_Silent;

   procedure Init_Over (Ctx : in out Context; Buffer : in out Bytes_Ptr) is
   begin
      Initialize (Ctx, Buffer);
   end Init_Over;

   procedure Tmp_Lost (O : in out Outer) is
      Lost_Tmp : constant Context := O.Inner;
   begin
      O.Inner := (Buffer => null, Last => 0);
   end Tmp_Lost;

   procedure Slots_Over (S : in out Slots) is
   begin
      Alloc (S);
   end Slots_Over;

   procedure Half_Free (C : Boolean) is
      Half_Freed : Bytes_Ptr := new Bytes'(1 .. 2 => 0);
   begin
      if C then
         Dealloc (Half_Freed);
      end if;
   end Half_Free;

   procedure Update_Over (Ctx : in out Context; Buffer : in out Bytes_Ptr) is
   begin
      Ctx := Ctx'Update (Buffer => Buffer);
      Buffer := null;
   end Update_Over;

end Verification_Mutation_Resource_Leaks;
