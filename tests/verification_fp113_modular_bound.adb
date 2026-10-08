package body Verification_FP113_Modular_Bound with SPARK_Mode is

   procedure Store
     (Summed, Negated, Doubled, Chained, Fitting, Small : Byte;
      Sum      : out To_Sum;
      Negation : out To_Negation;
      Product  : out To_Product;
      Constant_Bound : out To_Constant;
      Plain    : out To_Plain_Sum;
      Least    : out To_Sum) is
   begin
      Sum := Summed;
      Negation := Negated;
      Product := Doubled;
      Constant_Bound := Chained;
      Plain := Fitting;
      Least := Small;
   end Store;

   procedure Store_Numbers
     (Numbered, Passed, Tiny : Byte;
      Number : out To_Number;
      Past   : out To_Past;
      Few    : out To_Past) is
   begin
      Number := Numbered;
      Past := Passed;
      Few := Tiny;
   end Store_Numbers;

   function Pick (Data : Table; Position, Inside : Byte) return Integer is
   begin
      return Data (Position) + Data (Inside);
   end Pick;

end Verification_FP113_Modular_Bound;
