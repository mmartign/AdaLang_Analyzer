--  Subtypes whose bounds are written with "/", "mod" or "rem" over an
--  attribute, as libkeccak's "Positive range 1 .. Positive'Last / 8". Each
--  bound is static, and the overflow checks of the Ok_* subprograms follow
--  from the subtype of the component alone; those of the Bad_* subprograms
--  fail at a bound one past what the subtype allows.
package Verification_Declared_Bound_Division
  with SPARK_Mode
is
   subtype Block_Size_Number is Positive range 1 .. Positive'Last / 8;
   subtype Half is Integer range 0 .. Integer'Last / 2;
   subtype Half_Plus is Integer range 1 .. Integer'Last / 2 + 1;
   subtype Last_Digit is Integer range 0 .. Integer'Last mod 10;
   subtype First_Digit is Integer range Integer'First rem 10 .. 0;

   type Context is record
      Block_Size : Block_Size_Number;
      H          : Half;
      HP         : Half_Plus;
      M          : Last_Digit;
      R          : First_Digit;
   end record;

   procedure Ok_Block (Ctx : Context; X : out Integer);
   procedure Ok_Initial (Ctx : Context; X : out Integer);
   procedure Ok_Half (Ctx : Context; X : out Integer);
   procedure Ok_Digits (Ctx : Context; X : out Integer);
   procedure Bad_Half_Plus (Ctx : Context; X : out Integer);
   procedure Bad_Last_Digit (Ctx : Context; X : out Integer);
   procedure Bad_First_Digit (Ctx : Context; X : out Integer);
end Verification_Declared_Bound_Division;
