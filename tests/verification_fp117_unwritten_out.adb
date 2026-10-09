--  FP-117: an out actual was taken to be initialized after a call whose
--  callee has a path that returns without writing the parameter. The
--  statements of a body were read as writing it on every path where a
--  return sits in a loop or in a block, where a goto passes the write, and
--  where a handler of a block ends what was raised before the write.
--  Each of After_Loop, After_Jump, After_Block and After_Handler reads an
--  object that has no value when the driver below calls it.
procedure Verification_FP117_Unwritten_Out is

   procedure Return_In_Loop (X : out Integer; N : Integer) is
   begin
      for I in 1 .. N loop
         if I = 3 then
            return;
         end if;
      end loop;
      X := 1;
   end Return_In_Loop;

   procedure Jump_Over (X : out Integer; C : Boolean) is
   begin
      if C then
         goto Done;
      end if;
      X := 1;
      <<Done>>
      null;
   end Jump_Over;

   procedure Return_In_Block (X : out Integer; C : Boolean) is
   begin
      begin
         if C then
            return;
         end if;
      end;
      X := 1;
   end Return_In_Block;

   procedure Handled_Before (X : out Integer) is
   begin
      declare
      begin
         raise Program_Error;
      exception
         when Program_Error =>
            null;
      end;
   end Handled_Before;

   --  Every path writes it.
   procedure Written (X : out Integer; C : Boolean) is
   begin
      if C then
         X := 1;
      else
         declare
            Twice : constant Integer := 2;
         begin
            X := Twice;
         end;
      end if;
   end Written;

   procedure After_Loop (N : Integer; R : out Integer) is
      Looped : Integer;
   begin
      Return_In_Loop (Looped, N);
      R := Looped;
   end After_Loop;

   procedure After_Jump (C : Boolean; R : out Integer) is
      Jumped : Integer;
   begin
      Jump_Over (Jumped, C);
      R := Jumped;
   end After_Jump;

   procedure After_Block (C : Boolean; R : out Integer) is
      Blocked : Integer;
   begin
      Return_In_Block (Blocked, C);
      R := Blocked;
   end After_Block;

   procedure After_Handler (R : out Integer) is
      Swallowed : Integer;
   begin
      Handled_Before (Swallowed);
      R := Swallowed;
   end After_Handler;

   procedure After_Written (C : Boolean; R : out Integer) is
      Whole : Integer;
   begin
      Written (Whole, C);
      R := Whole;
   end After_Written;

   V : Integer;
begin
   After_Loop (5, V);
   After_Jump (True, V);
   After_Block (True, V);
   After_Handler (V);
   After_Written (True, V);
end Verification_FP117_Unwritten_Out;
