--  FP-113: a bound written with the arithmetic of a modular type wraps,
--  as that arithmetic does.
package Verification_FP113_Modular_Bound with SPARK_Mode is

   type Byte is mod 256;

   Two_Hundred : constant Byte := 200;
   One_Hundred : constant Byte := 100;
   Wrapped_Sum : constant Byte := Two_Hundred + One_Hundred;

   --  200 + 100 is 44, - 100 is 156 and 200 * 2 is 144.
   subtype To_Sum is Byte range 0 .. Two_Hundred + One_Hundred;
   subtype To_Negation is Byte range 0 .. -One_Hundred;
   subtype To_Product is Byte range 0 .. Two_Hundred * 2;
   subtype To_Constant is Byte range 0 .. Wrapped_Sum;

   --  A named number has the value its expression has in the type of
   --  that expression: 44 again, and 255 + 1 is 0.
   Sum_Number  : constant := Two_Hundred + One_Hundred;
   Past_Number : constant := Byte'Last + 1;
   subtype To_Number is Byte range 0 .. Sum_Number;
   subtype To_Past is Byte range 0 .. Past_Number + 5;

   --  Nothing wraps here: 100 + 50 is 150.
   subtype To_Plain_Sum is Byte range 0 .. One_Hundred + 50;

   type Table is array (To_Sum) of Integer;

   procedure Store
     (Summed, Negated, Doubled, Chained, Fitting, Small : Byte;
      Sum      : out To_Sum;
      Negation : out To_Negation;
      Product  : out To_Product;
      Constant_Bound : out To_Constant;
      Plain    : out To_Plain_Sum;
      Least    : out To_Sum)
     with Pre => Summed <= 100 and then Negated <= 200
                 and then Doubled <= 200 and then Chained <= 100
                 and then Fitting <= 120 and then Small <= 40;

   procedure Store_Numbers
     (Numbered, Passed, Tiny : Byte;
      Number : out To_Number;
      Past   : out To_Past;
      Few    : out To_Past)
     with Pre => Numbered <= 100 and then Passed <= 100 and then Tiny <= 5;

   function Pick (Data : Table; Position, Inside : Byte) return Integer
     with Pre => Position <= 100 and then Inside <= 40;

end Verification_FP113_Modular_Bound;
