with Ada.Text_IO;

procedure Precision_References (Code : in Integer; Flag : in Boolean) is
   subtype Even is Integer with Dynamic_Predicate => Even mod 2 = 0;
   type Colour is (Red, Green, Blue);
   Total   : Integer := 0;
   Scratch : Integer;
   Shade   : constant Colour := Green;

   protected Guard is
      procedure Bump;
   private
      Count : Integer := 0;
   end Guard;

   protected body Guard is
      procedure Bump is
      begin
         Count := Count + 1;
         Total := Count;
      end Bump;
   end Guard;

   procedure Fill (Target : out Integer; Step : Integer);

   procedure Fill (Target : out Integer; Step : in Integer) is
   begin
      Target := Total + Step + Code;
   end Fill;

   procedure Risky is
      Local_Error : exception;
      Other_Error : exception;
      Value : Integer := 0;
   begin
      Fill (Value, 1);
      if Value > 10 then
         raise Other_Error;
      end if;
   exception
      when Other_Error =>
         Ada.Text_IO.Put_Line (Integer'Image (Value));
         raise;
   end Risky;
begin
   if Code = 1 and Code = 2 then
      Total := 1;
   end if;
   if Shade /= Red or Shade /= Blue then
      Total := 2;
   end if;
   if Flag and Code > 3 and Flag then
      Total := 3;
   end if;
   if Code in Even then
      Total := 4;
   end if;

   declare
   begin
      Scratch := Total;
      Total := Scratch + 1;
   end;

   Guard.Bump;
   Risky;
end Precision_References;
