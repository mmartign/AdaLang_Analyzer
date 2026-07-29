procedure Verification_Diff_Modular_Call
  (Input  : Integer;
   Result : out Integer)
  with SPARK_Mode,
       Pre  => Input < Integer'Last,
       Post => Result = Input + 1
is
   procedure Add_One
     (Value  : Integer;
      Output : out Integer)
     with Global => null,
          Pre    => Value < Integer'Last,
          Post   => Output = Value + 1;

   procedure Add_One
     (Value  : Integer;
      Output : out Integer)
   is
   begin
      Output := Value + 1;
   end Add_One;
begin
   Add_One (Input, Result);
end Verification_Diff_Modular_Call;
