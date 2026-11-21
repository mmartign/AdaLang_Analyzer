--  FP-150 to FP-155: objects given a value that a read of them used to miss,
--  each found by a run on Alire crates. None of the reads below is of an
--  object without a value; the last two subprograms keep a read of one, and
--  an assertion of False reached for sure, which stay definite errors.

with Ada.Streams.Stream_IO; use Ada.Streams.Stream_IO;
with Interfaces;            use Interfaces;
with System;
with System.Machine_Code;   use System.Machine_Code;

procedure Verification_FP150_Outside_Writes (F : File_Type) is

   --  FP-150: T'Read stores into its item (gid, Zip-Ada, wisitoken).
   function Read_Header return Integer is
      B : Unsigned_8;
      C : Character;
   begin
      Unsigned_8'Read (Stream (F), B);
      Character'Read (Stream (F), C);
      return Integer (B) + Character'Pos (C);
   end Read_Header;

   --  The index of the item keeps its value (tokeneer's File.GetString).
   procedure Read_Text (Text : out String; Stop : out Natural) is
   begin
      Stop := Text'First - 1;
      loop
         exit when End_Of_File (F);
         Stop := Stop + 1;
         Character'Read (Stream (F), Text (Stop));
         exit when Stop = Text'Last;
      end loop;
   end Read_Text;

   --  FP-150: T'Asm_Output stores into its object (HiRTOS, rp2040_hal).
   function Interrupt_Number return Unsigned_32 is
      IPSR : Unsigned_32;
   begin
      Asm ("mrs %0, ipsr", Unsigned_32'Asm_Output ("=r", IPSR),
           Volatile => True);
      return IPSR;
   end Interrupt_Number;

   --  FP-151: a call through an access value has out parameters too
   --  (utilada's tokenizer, OpenGLAda's loaded entry points).
   procedure Tokens
     (Process : not null access procedure (Done : out Boolean);
      Result  : out Boolean)
   is
      Done : Boolean;
   begin
      Process (Done => Done);
      Result := Done;
   end Tokens;

   --  FP-152: a view conversion as an out actual is not read (sdlada,
   --  stephes_ada_library, simple_components).
   procedure Scale (X : out Float) is
      procedure Get (V : out Long_Float) is
      begin
         V := 1.0;
      end Get;
      Y : Float;
   begin
      Get (Long_Float (Y));
      X := Y;
   end Scale;

   --  FP-153: an object whose access value or address is given away can
   --  be given a value through it (simple_components' OpenSSL binding).
   function Written_Count return Integer is
      procedure Fill (P : access Integer)
        with Import, Convention => C, External_Name => "fill";
      procedure Fill_Address (A : System.Address)
        with Import, Convention => C, External_Name => "fill_address";
      Count : aliased Integer;
      Size  : Integer;
   begin
      Fill (Count'Access);
      Fill_Address (Size'Address);
      return Count + Size;
   end Written_Count;

   --  FP-153: an imported object has the value the other language gives
   --  it, and the pragma that imports it reads nothing (clic).
   function Separator return Character is
      Sep : Character;
      pragma Import (C, Sep, "__gnat_dir_separator");
   begin
      return Sep;
   end Separator;

   --  FP-154: a renaming names an object; it reads no value
   --  (simple_components' Unbounded_Unsigneds).
   procedure Borrow_Out (Borrow : out Integer) is
   begin
      declare
         Result : Integer renames Borrow;
      begin
         Result := 1;
      end;
   end Borrow_Out;

   --  FP-155: after a call, an assertion of False is reached only if the
   --  call returns (HiRTOS, after its first context switch).
   procedure Switch is
   begin
      null;
   end Switch;

   procedure Start is
   begin
      Switch;
      pragma Assert (False);
   end Start;

   --  Still definite errors.
   function Really_Uninitialized return Integer is
      Y : Integer;
   begin
      return Y;
   end Really_Uninitialized;

   procedure Never_Here is
   begin
      pragma Assert (False);
      null;
   end Never_Here;

   Flag : Boolean;
   Real : Float;
   Out1 : Integer;
   Text : String (1 .. 8);
   Last : Natural;
begin
   Read_Text (Text, Last);
   Tokens (null, Flag);
   Scale (Real);
   Borrow_Out (Out1);
   Start;
   Never_Here;
   if Read_Header + Integer (Interrupt_Number) + Written_Count +
     Character'Pos (Separator) + Really_Uninitialized > 0
   then
      null;
   end if;
end Verification_FP150_Outside_Writes;
