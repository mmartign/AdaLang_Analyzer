--  The length of an array is a universal integer. Where the context
--  expects a value of an integer type it is converted to that type, and
--  the conversion is checked: against the base range of the type where
--  the length is an operand of one of the type's own operators, against
--  the subtype anywhere else. Each array below is used once, so that its
--  name tells the places apart.
procedure Verification_Length_Conversion with SPARK_Mode is

   type Byte is mod 256;
   type Index is range 0 .. 1000;
   type Short is range 0 .. 100;

   --  As many as 2 ** 31 components: one more than Integer has values for.
   type Bytes is array (Natural range <>) of Byte;

   --  No more than 1001.
   type Row is array (Index range <>) of Byte;

   --  No more than 50.
   subtype Slot is Short range 1 .. 50;
   type Cells is array (Slot range <>) of Byte;

   --  An addition that stops at the last value, in the place of the
   --  predefined one.
   function "+" (Left, Right : Index) return Index
   is (Index (Integer'Min (Integer (Left) + Integer (Right), 1000)));

   Limit : constant := 10;
   Fixed : constant Row (1 .. 5) := (others => 0);

   procedure Take (Size : Natural) is null;

   --  A conversion, and its check, at each length.
   procedure Converted
     (Compared, Added, Bound, Tested, Counted, Scaled, Qualified,
      Shortened, Capped : Bytes;
      Brief  : Row;
      Few    : Cells;
      Count  : Natural;
      Place  : Index;
      Step   : Short;
      Result : out Boolean)
     with Global => null
   is
   begin
      --  An operand of an operator of Integer: the base range of Integer.
      Result := Count < Compared'Length;
      Result := Count < Natural'Last and then Count + 1 = Added'Length;
      Result := Count in 1 .. Bound'Length;
      Result := (if Count < Tested'Length then Result else False);
      for Item in 1 .. Counted'Length loop
         Result := not Result;
      end loop;
      Result := Count = Scaled'Length - 1;

      --  No operator: the subtype.
      Result := Count = Natural'(Qualified'Length);

      --  The base range of Short is the implementation's to choose.
      Result := Step < Shortened'Length;

      --  An operand of the function that stands for "+": the subtype of
      --  its formal.
      Result := Place + Capped'Length = Place;

      --  No more than 1001: that is within the base range of Integer.
      Result := Count < Brief'Length;

      --  No more than 50: every base range Short can have holds that.
      Result := Step < Few'Length;
   end Converted;

   --  No conversion, or one that is the business of another check.
   procedure Unconverted
     (Universal, Summed, Other, Assigned, Passed, Cast : Bytes;
      Count  : in out Natural;
      Place  : Index;
      Result : out Boolean)
     with Global => null
   is
   begin
      --  Universal operands of a universal operator.
      Result := Universal'Length > 0;
      Result := Summed'Length + Other'Length > Limit;

      --  A static value, to a compiler as much as to a reader.
      Result := Place < Fixed'Length;

      --  The check of the assignment, of the actual parameter and of the
      --  conversion: one each, as before.
      Count := Assigned'Length;
      Take (Passed'Length);
      Count := Natural (Cast'Length);
   end Unconverted;

   Count  : Natural := 3;
   Result : Boolean;
begin
   Converted
     (Compared  => (0 .. 2 => 0), Added     => (0 .. 2 => 0),
      Bound     => (0 .. 2 => 0), Tested    => (0 .. 2 => 0),
      Counted   => (0 .. 2 => 0), Scaled    => (0 .. 2 => 0),
      Qualified => (0 .. 2 => 0), Shortened => (0 .. 2 => 0),
      Capped    => (0 .. 2 => 0), Brief     => (0 .. 2 => 0),
      Few       => (1 .. 2 => 0),
      Count     => Count, Place => 3, Step => 3, Result => Result);
   Unconverted
     (Universal => (0 .. 2 => 0), Summed => (0 .. 2 => 0),
      Other     => (0 .. 2 => 0), Assigned => (0 .. 2 => 0),
      Passed    => (0 .. 2 => 0), Cast => (0 .. 2 => 0),
      Count     => Count, Place => 3, Result => Result);
   pragma Unreferenced (Count, Result);
end Verification_Length_Conversion;
