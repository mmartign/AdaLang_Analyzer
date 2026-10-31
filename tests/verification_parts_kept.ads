--  What a statement does not touch stays known, and what names a value says
--  what is known of it. GNATprove proves every check here.
package Verification_Parts_Kept
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
      First  : Positive;
   end record;

   --  A write through an access value reaches no named part.
   procedure Element_Through_Pointer (Ctx : in out Context)
     with Pre => Ctx.Buffer /= null
                 and then Ctx.Buffer'First = 1
                 and then Ctx.Buffer'Last >= 2
                 and then Ctx.Cursor (F_B).State = 7
                 and then Ctx.First = 3,
          Post => Ctx.Cursor (F_B).State = 7;

   procedure Slice_Through_Pointer (Ctx : in out Context; Data : Bytes)
     with Pre => Ctx.Buffer /= null
                 and then Ctx.Buffer'First = 1
                 and then Ctx.Buffer'Last >= 2
                 and then Data'Length = 2
                 and then Ctx.Cursor (F_B).State = 7,
          Post => Ctx.Cursor (F_B).State = 7;

   procedure Fill (Data : out Bytes)
     with Post => (for all I in Data'Range => Data (I) = 0);

   procedure Call_Through_Pointer (Ctx : in out Context)
     with Pre => Ctx.Buffer /= null
                 and then Ctx.Cursor (F_B).State = 7,
          Post => Ctx.Cursor (F_B).State = 7;

   --  An alternative of a case expression is evaluated when its choice
   --  holds.
   function Needs_B (F : Field) return Integer
     with Pre => F = F_B;
   function Needs_Late (F : Field) return Integer
     with Pre => F /= F_A;
   function Needs_Small (N : Integer) return Integer
     with Pre => N in 1 .. 5;
   function Needs_Other (N : Integer) return Integer
     with Pre => N < 1 or else N > 5;

   function By_Choice (F : Field) return Integer
   is (case F is
          when F_A        => 1,
          when F_B        => Needs_B (F),
          when F_C | F_D  => 3);

   function By_Others (F : Field) return Integer
   is (case F is
          when F_A    => 1,
          when others => Needs_Late (F));

   function By_Range (N : Integer) return Integer
   is (case N is
          when 1 .. 5 => Needs_Small (N),
          when others => Needs_Other (N));

   --  The operands of a declared operator are its actuals.
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

   procedure Added (I : Index; N : Length; R : out Index)
     with Pre => I <= 10 and then N <= 10;
   procedure Taken (I, J : Index; R : out Length)
     with Pre => I >= J;
   procedure Negated (N : Length; R : out Length)
     with Pre => N >= 2;

   --  A copy of a record says what the record says.
   type Pair is record
      X, Y : Integer;
   end record;
   type Holder is record
      P, Q : Pair;
   end record;

   procedure Copied_Declaration (H : Holder)
     with Pre => H.P.X = 1;
   procedure Copied_Back (H : in out Holder)
     with Pre => H.P.X = 1, Post => H.P.X = 1 and then H.Q.X = 1;

   --  A formal of the subtype of its actual, constrained, reads the actual.
   function Ready (Cursor : Slots) return Natural
     with Pre => Cursor (F_B).State = 0;
   function Ready_Of (Ctx : Context) return Natural
     with Pre => Ctx.Cursor (F_B).State = 0;

   --  A slice has the bounds it is written with.
   procedure Log (Text : String)
     with Pre => Text'Length = 4 and then Text'First = 2;
   procedure Slice_Given (S : String)
     with Pre => S'First <= 2 and then S'Last >= 5;
   procedure Empty_Given (S : String)
     with Pre => S'First <= 1;
   procedure Log_Nothing (Text : String)
     with Pre => Text'Length = 0;
end Verification_Parts_Kept;
