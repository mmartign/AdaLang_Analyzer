--  The length check of an array that is given to a target: an assignment,
--  an initial value, a returned value, an actual parameter, the operand of
--  a conversion, the operands of "and", "or" and "xor". Each procedure
--  makes one of them, so that no check is decided on the strength of
--  another.
procedure Verification_Length_Check with SPARK_Mode is

   type Index is range 0 .. 1000;
   type Bytes is array (Index range <>) of Natural;
   subtype Five is Bytes (1 .. 5);
   subtype Word is Bytes (0 .. 7);
   type Flags is array (Index range <>) of Boolean;
   subtype Four_Flags is Flags (1 .. 4);
   type Colour is (Red, Green, Blue);
   type Palette is array (Colour) of Natural;

   function Word_Of (Slot : Index) return Word
   is (Word'(others => Natural (Slot)));

   procedure Take_Five (Item : Five) is null;

   --  Proved: the lengths are the same, whatever they are.

   procedure Fill (Target : out Bytes)
     with Global => null
   is
   begin
      Target := (others => 0);
   end Fill;

   procedure Copy_Front (Left : in out Bytes; Right : Bytes; Count : Index)
     with Global => null,
          Pre => Left'First = 1 and then Right'First = 1
                 and then Count <= Left'Last and then Count <= Right'Last
   is
   begin
      Left (1 .. Count) := Right (1 .. Count);
   end Copy_Front;

   procedure Shift (Data : in out Bytes; Count : Index)
     with Global => null,
          Pre => Data'First = 1 and then Count in 1 .. Data'Last
   is
   begin
      Data (2 .. Count) := Data (1 .. Count - 1);
   end Shift;

   procedure Same_By_Contract (Whole : out Bytes; Other : Bytes)
     with Global => null,
          Pre => Whole'Length = Other'Length
   is
   begin
      Whole := Other;
   end Same_By_Contract;

   procedure Five_By_Contract (Kept : out Five; Source : Bytes)
     with Global => null,
          Pre => Source'Length = 5
   is
   begin
      Kept := Source;
   end Five_By_Contract;

   procedure Chunk (Buffer : in out Bytes; Slot : Index)
     with Global => null,
          Pre => Buffer'First = 0 and then Slot <= 100
                 and then Buffer'Last >= 8 * Slot + 7
   is
   begin
      Buffer (8 * Slot .. 8 * Slot + 7) := Word_Of (Slot);
   end Chunk;

   procedure Declared_Filled (Count : Index; Total : out Natural)
     with Global => null
   is
      Local : constant Bytes (1 .. Count) := (others => 0);
   begin
      Total := Local'Length;
   end Declared_Filled;

   procedure Both_Static (Mask, Other : Four_Flags; Result : out Four_Flags)
     with Global => null
   is
   begin
      Result := Mask and Other;
   end Both_Static;

   --  An object declared with an unconstrained subtype has the bounds of
   --  its initial value, which no declaration makes static: the check is
   --  there, and those bounds prove it.
   procedure Bounds_Of_Value (Sized : out Five; Model : Five)
     with Global => null
   is
      Loose : constant Bytes := Model;
   begin
      Sized := Loose;
   end Bounds_Of_Value;

   --  Not proved: nothing says the lengths are the same, or they are not.

   procedure One_More (Front : in out Bytes; Back : Bytes; Count : Index)
     with Global => null,
          Pre => Front'First = 1 and then Back'First = 1
                 and then Count < Front'Last and then Count < Back'Last
   is
   begin
      Front (1 .. Count) := Back (1 .. Count + 1);
   end One_More;

   procedure One_Less (Head : in out Bytes; Tail : Bytes; Count : Index)
     with Global => null,
          Pre => Head'First = 1 and then Tail'First = 1
                 and then Count in 2 .. Head'Last and then Count <= Tail'Last
   is
   begin
      Head (2 .. Count) := Tail (1 .. Count);
   end One_Less;

   procedure Unrelated (Sink : out Bytes; Origin : Bytes)
     with Global => null
   is
   begin
      Sink := Origin;
   end Unrelated;

   procedure Into_Five (Fixed : out Five; Given : Bytes)
     with Global => null
   is
   begin
      Fixed := Given;
   end Into_Five;

   --  A slice of an array of five is not an array of five.
   procedure Slice_Of_Five (All_Five : out Five; Part : Five; Count : Index)
     with Global => null,
          Pre => Count in 1 .. 5
   is
   begin
      All_Five := Part (1 .. Count);
   end Slice_Of_Five;

   procedure Six_Into_Five (Short : out Five; Long : Bytes)
     with Global => null,
          Pre => Long'Length = 6
   is
   begin
      Short := Long;
   end Six_Into_Five;

   procedure Short_Chunk (Store : in out Bytes; Place, Last : Index)
     with Global => null,
          Pre => Store'First = 0 and then Place <= 100
                 and then Last = 8 * Place + 6 and then Last <= Store'Last
   is
   begin
      Store (8 * Place .. Last) := Word_Of (Place);
   end Short_Chunk;

   procedure Declared_From (Count : Index; Seed : Bytes; Total : out Natural)
     with Global => null
   is
      Start : constant Bytes (1 .. Count) := Seed;
   begin
      Total := Start'Length;
   end Declared_From;

   function Returned (Result_Source : Bytes) return Five
     with Global => null
   is
   begin
      return Result_Source;
   end Returned;

   procedure Passed (Argument : Bytes)
     with Global => null
   is
   begin
      Take_Five (Argument);
   end Passed;

   procedure Converted (Operand : Bytes; Total : out Natural)
     with Global => null
   is
   begin
      Total := Five (Operand)'Length;
   end Converted;

   procedure Either_Length (Bits, More : Flags; Outcome : out Four_Flags)
     with Global => null,
          Pre => Bits'Length = 4
   is
   begin
      Outcome := Bits or More;
   end Either_Length;

   --  No check: the lengths are static and the same, or there is no
   --  constrained subtype to give the value to.

   procedure Unchecked
     (Kept, Again : in out Five; Plenty : Bytes;
      Shades, Tints : in out Palette; Total : out Natural)
     with Global => null,
          Pre => Plenty'First = 1 and then Plenty'Last >= 5
   is
      Copy : constant Bytes := Plenty;
   begin
      Kept := Again;
      Again := (others => 0);
      Kept := Plenty (1 .. 5);
      Kept (1 .. 2) := Plenty (3 .. 4);
      Again := (1, 2, 3, 4, 5);
      Shades := Tints;
      Tints := (others => 1);
      Kept := (if Plenty'Last = 5 then Again else Kept);
      Take_Five (Kept);
      Total := Copy'Length;
   end Unchecked;

begin
   null;
end Verification_Length_Check;
