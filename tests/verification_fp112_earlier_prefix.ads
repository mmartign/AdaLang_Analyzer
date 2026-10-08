--  FP-112: the prefix of 'Old is evaluated when the subprogram is entered
--  and that of 'Loop_Entry when the loop is. What the place where the
--  attribute is written knows of an object says nothing of the checks
--  inside the prefix.
package Verification_FP112_Earlier_Prefix with SPARK_Mode is

   subtype Small is Integer range 1 .. 10;

   function Positive_Only (Value : Integer) return Integer is (Value)
     with Pre => Value > 0;

   --  Each of these bodies leaves its parameter at one. Nothing says what
   --  it holds on entry.
   procedure Old_Division (Divisor : in out Integer) with
     Post => Integer'(10 / Divisor)'Old <= 10 or else Divisor = 1;

   procedure Old_Overflow (Addend : in out Integer) with
     Post => Integer'(Addend + 1)'Old > 0 or else Addend = 1;

   procedure Old_Range (Converted : in out Integer) with
     Post => Small (Converted)'Old <= 10 or else Converted = 1;

   procedure Old_Precondition (Passed : in out Integer) with
     Post => Positive_Only (Passed)'Old <= 5 or else Passed = 1;

   --  The precondition is what holds on entry, and these bodies leave
   --  zero.
   procedure Old_Required (Required : in out Integer) with
     Pre  => Required > 0,
     Post => Positive_Only (Required)'Old > 0 or else Required = 0;

   procedure Old_Nonzero (Nonzero : in out Integer) with
     Pre  => Nonzero > 0,
     Post => Integer'(10 / Nonzero)'Old <= 10 or else Nonzero = 0;

   procedure Loops (Kept : in out Integer);

end Verification_FP112_Earlier_Prefix;
