--  A name written with its package in front of it is the entity it names,
--  an enumeration literal or a named number as much as an object. A named
--  number is its value.
package Verification_Named_Values with SPARK_Mode is

   type Field is (F_A, F_B, F_C);
   type Byte is mod 256;

   Limit   : constant := 10;
   Half    : constant := 7 / 2;
   Wrapped : constant := Byte'(200) + Byte'(100);
   Ratio   : constant := 2.5;

   type Context is private;

   function Ready (Ctx : Context; Fld : Field) return Boolean;

   function Size (Ctx : Context; Fld : Field) return Natural with
     Pre => Verification_Named_Values.Ready (Ctx, Fld);

   --  The precondition says it of the literal the call is given.
   procedure Same (Ctx : Context; Result : out Natural) with
     Pre => Verification_Named_Values.Ready
              (Ctx, Verification_Named_Values.F_B);

   --  The precondition says it of another literal.
   procedure Other (Ctx : Context; Result : out Natural) with
     Pre => Verification_Named_Values.Ready
              (Ctx, Verification_Named_Values.F_B);

   procedure Literals (Fld, Copy : Field) with
     Pre => Fld = Verification_Named_Values.F_B and then Copy = Fld;

   --  Limit is 10 and Half is 3.
   procedure Numbers (Value, Small : Integer; Result : out Integer) with
     Pre => Value in 0 .. Verification_Named_Values.Limit - 1
            and then Small < Half;

   --  Nine is not below nine, two is below Half, Wrapped is 44 and not
   --  300, Ratio is no integer, and Exact - Limit + 1 is zero at nine.
   procedure Not_Numbers
     (Above, Middle, Exact : Integer; Octet : Byte; Result : out Integer)
     with
     Pre => Above in 0 .. Limit - 1
            and then Middle < Half
            and then Exact in 0 .. Limit - 1
            and then Octet <= 100;

private

   type Flags is array (Field) of Boolean;

   type Context is record
      Set : Flags := (others => False);
   end record;

   function Ready (Ctx : Context; Fld : Field) return Boolean is
     (Ctx.Set (Fld));

   function Size (Ctx : Context; Fld : Field) return Natural is
     (if Ctx.Set (Fld) then 1 else 0);

end Verification_Named_Values;
