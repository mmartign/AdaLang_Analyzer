--  Pieces of the scalar VC language. The subprograms named Ok_* have
--  claims that hold and are proved: an operator a declaration defines,
--  called where Libadalang takes an abstract function that hides a
--  predefined operator for it (Ok_Distance, Ok_Context); T'Pos and T'Val
--  (Ok_Pos, Ok_Val); X'Constrained of a component of a variable whose
--  declaration gives the name of a type with defaulted discriminants
--  (Ok_Plain, Ok_Same); F'Result in the postcondition of a function
--  (Ok_Next, Ok_Half, Ok_Negation); X and a mask of low bits, and a power
--  of known operands (Ok_Mask, Ok_Power); Interfaces.Shift_Right and
--  Shift_Left by a known amount (Ok_Right, Ok_Left). Those of the
--  subprograms named Bad_* do not hold, or are not known to (the component
--  is constrained by its declaration, Bad_Fixed, Bad_Named), and are not
--  proved. GNATprove proves the claims of the Ok_* subprograms and none of
--  those of the Bad_* ones but Bad_Aliased, which GNATprove proves and
--  --verify leaves unproved: an aliased component is kept apart.
with Interfaces; use Interfaces;

package Verification_Translation_Pieces with SPARK_Mode is

   type Idx is range 1 .. 1_000;
   type Len is range 0 .. 1_000;

   --  Hides the predefined "-" of Idx.
   function "-" (Left, Right : Idx) return Idx is abstract;

   package Operators is
      function "-" (Left : Idx; Right : Idx) return Len is
        (Len (Left) - Len (Right))
      with Pre => Len (Left) >= Len (Right);

      function "-" (Left : Idx; Right : Len) return Idx is
        (Idx (Len (Left) - Right))
      with Pre => Len (Left) > Right;
   end Operators;
   use Operators;

   procedure Ok_Distance (A, B : Idx; D : out Len)
   with Pre => A >= B;

   procedure Ok_Context (A, B : Idx; D : out Len)
   with Pre => A >= B;

   procedure Bad_Distance (A, B : Idx; D : out Len)
   with Pre => A >= B;

   type Color is (Red, Green, Blue);

   procedure Ok_Pos (C : Color; P : out Natural)
   with Post => P <= 2;

   procedure Bad_Pos (C : Color; P : out Natural)
   with Post => P <= 1;

   procedure Ok_Val (N : Natural; C : out Color)
   with Pre => N = 1, Post => C = Green;

   type Ctx (Size : Natural := 0) is private;
   subtype Ctx5 is Ctx (5);
   subtype Same_Ctx is Ctx;

   type Holder is record
      Plain   : Ctx;
      Same    : Same_Ctx;
      Fixed   : Ctx (5);
      Named   : Ctx5;
      Aliased_Part : aliased Ctx;
   end record;

   type Outer is record
      Inner : Holder;
   end record;

   procedure Reset (X : in out Ctx)
   with Pre => not X'Constrained;

   procedure Ok_Plain (O : in out Outer);
   procedure Ok_Same (H : in out Holder);
   procedure Bad_Fixed (H : in out Holder);
   procedure Bad_Named (H : in out Holder);
   procedure Bad_Aliased (H : in out Holder);

   subtype Small is Integer range 0 .. 100;

   function Ok_Next (X : Small) return Integer is (X + 1)
   with Post => Ok_Next'Result = X + 1;

   function Ok_Half (X : Natural) return Natural
   with Post => Ok_Half'Result <= X;

   function Ok_Negation (B : Boolean) return Boolean is (not B)
   with Post => Ok_Negation'Result = not B;

   function Bad_Next (X : Small) return Integer
   with Post => Bad_Next'Result = X;

   function Bad_Split (X : Integer) return Integer
   with Post => Bad_Split'Result = 1;

   subtype Byte_Range is Unsigned_32 range 0 .. 255;

   procedure Ok_Mask (Y : Unsigned_32; R : out Byte_Range);
   procedure Bad_Mask (Y : Unsigned_32; R : out Byte_Range);

   procedure Bad_Masked_Claim (Y : Unsigned_32; R : out Unsigned_32)
   with Post => R <= 100;

   procedure Ok_Power (Y : Unsigned_32; R : out Unsigned_32)
   with Post => R * 2 ** 8 <= Y;

   procedure Ok_Right (Y : Unsigned_32; R : out Byte_Range);
   procedure Bad_Right (Y : Unsigned_32; R : out Byte_Range);

   procedure Ok_Left (Y : Unsigned_8; R : out Unsigned_8)
   with Post => R mod 2 = 0;

   procedure Bad_Left (Y : Unsigned_8; R : out Unsigned_8)
   with Post => R < 128;

private

   type Ctx (Size : Natural := 0) is record
      Value : Integer := 0;
   end record;

end Verification_Translation_Pieces;
