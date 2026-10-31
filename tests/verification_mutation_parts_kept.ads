--  The claims of verification_parts_kept that do not follow. Each comment in
--  the body says why; a Proved_Safe on any of them is a false-safe.
package Verification_Mutation_Parts_Kept
  with SPARK_Mode
is
   type Byte is mod 256;
   type Bytes is array (Positive range <>) of Byte;
   type Bytes_Ptr is access Bytes;

   type Field is (F_A, F_B, F_C, F_D);
   type Slot is record
      State : Integer;
      Size  : Natural;
   end record;
   type Slots is array (Field) of Slot;

   type Context is record
      Buffer : Bytes_Ptr;
      Cursor : Slots;
   end record;

   function Head (P : Bytes_Ptr) return Byte
   is (P (1)) with Pre => P /= null and then P'First = 1;
   function First_Byte (Ctx : Context) return Byte
   is (Ctx.Buffer (1))
     with Pre => Ctx.Buffer /= null and then Ctx.Buffer'First = 1;

   procedure Written_Element (Ctx : in out Context; Value : Byte)
     with Pre => Ctx.Buffer /= null and then Ctx.Buffer'First = 1
                 and then Ctx.Buffer'Last >= 1;
   procedure Written_Slice (Ctx : in out Context; Data : Bytes)
     with Pre => Ctx.Buffer /= null and then Ctx.Buffer'First = 1
                 and then Ctx.Buffer'Last >= 2 and then Data'Length = 2;
   procedure Read_By_Function (Ctx : in out Context; Value : Byte)
     with Pre => Ctx.Buffer /= null and then Ctx.Buffer'First = 1
                 and then Ctx.Buffer'Last >= 1;
   procedure Read_By_Pointer (Ctx : in out Context; Value : Byte)
     with Pre => Ctx.Buffer /= null and then Ctx.Buffer'First = 1
                 and then Ctx.Buffer'Last >= 1;
   procedure Fill (Data : out Bytes);
   procedure Written_By_Call (Ctx : in out Context)
     with Pre => Ctx.Buffer /= null and then Ctx.Buffer'First = 1
                 and then Ctx.Buffer'Last >= 1;
   procedure Named_Element_Written (Ctx : in out Context; State : Integer);

   function Needs_B (F : Field) return Integer
     with Pre => F = F_B;
   function Needs_Late (F : Field) return Integer
     with Pre => F /= F_A;
   function Needs_Small (N : Integer) return Integer
     with Pre => N in 1 .. 4;
   function Needs_Big (N : Integer) return Integer
     with Pre => N > 5;

   --  Two choices, and the callee takes one of them.
   function Both_Choices (F : Field) return Integer
   is (case F is
          when F_A | F_B => Needs_B (F),
          when F_C | F_D => 3);

   --  "others" is three values here, F_A among them.
   function Other_Values (F : Field) return Integer
   is (case F is
          when F_B    => 1,
          when others => Needs_Late (F));

   --  5 is in the range, not in what the callee takes.
   function Range_End (N : Integer) return Integer
   is (case N is
          when 1 .. 5 => Needs_Small (N),
          when others => 0);

   --  "others" is below the range as well as above it.
   function Others_Both_Sides (N : Integer) return Integer
   is (case N is
          when 1 .. 5 => 0,
          when others => Needs_Big (N));

   --  What the alternative knows stops at its end: the next one is reached
   --  with another value, and so is what follows the expression.
   function After_Case (F : Field) return Integer
   is ((case F is
           when F_A    => 1,
           when others => 2)
       + Needs_B (F));

   type Index is range 1 .. 100;
   type Length is range 0 .. 100;

   function "+" (Left : Index; Right : Length) return Index
   is (Index (Length (Left) + Right))
     with Pre => Length (Left) <= Length'Last - Right;
   function "-" (Left, Right : Index) return Length
   is (Length (Left) - Length (Right))
     with Pre => Left >= Right;
   function "-" (Right : Length) return Length
   is (Length'Last - Right)
     with Pre => Right >= 1;

   procedure Too_Much (I : Index; N : Length; R : out Index);
   procedure Swapped (I, J : Index; R : out Length)
     with Pre => I >= J;
   procedure Negated_Zero (N : Length; R : out Length);

   type Pair is record
      X, Y : Integer;
   end record;
   type Holder is record
      P, Q : Pair;
   end record;
   type Row is array (1 .. 3) of Integer;
   type With_Row is record
      Data : Row;
   end record;

   function Sum (P : Pair) return Integer
   with Pre => P.X in -1000 .. 1000 and then P.Y in -1000 .. 1000;

   procedure Source_Written (H : in out Holder; V : Integer)
     with Pre => H.P.X = 1;
   procedure Source_Forgets (H : in out Holder; V : Integer)
     with Pre => H.P.X = 1;
   procedure Target_Written (H : in out Holder; V : Integer)
     with Pre => H.P.X = 1;
   procedure Target_Forgets (H : in out Holder; V : Integer)
     with Pre => H.P.X = 1;
   procedure Other_Component (H : in out Holder)
     with Pre => H.P.X = 1;
   procedure Whole_Then_Written (A : in out Pair)
     with Pre => A.X = 1;
   procedure Function_Of_Copy (A : in out Pair)
     with Pre => A.X = 1 and then A.Y = 1;
   procedure Element_After_Copy (A : in out With_Row);
   procedure Assigned_Over (H : in out Holder; V : Pair)
     with Pre => H.P.X = 1;

   procedure Log (Text : String)
     with Pre => Text'Length = 4;
   procedure Log_First (Text : String)
     with Pre => Text'First = 1;
   procedure Log_Empty (Text : String)
     with Pre => Text'Length > 0;
   subtype Four is String (1 .. 4);
   procedure Log_Four (Text : Four)
     with Pre => Text'First = 2;

   procedure Wrong_Length (S : String)
     with Pre => S'First <= 2 and then S'Last >= 6;
   procedure Wrong_First (S : String)
     with Pre => S'First <= 2 and then S'Last >= 6;
   procedure Empty_Slice (S : String)
     with Pre => S'First <= 1;
   procedure Slid_Slice (S : String)
     with Pre => S'First <= 2 and then S'Last >= 5;
end Verification_Mutation_Parts_Kept;
