--  A target name, "@" (RM 5.2.1), reads the target of its assignment: it
--  has an initialization check, as any read of the object, which an
--  object without a value fails (before, "@" raised none).

procedure Verification_Target_Name_Read (X : Integer; R : out Integer) with SPARK_Mode is
   type Pair is record
      A, B : Integer;
   end record;

   function Uninitialized return Integer is
      T : Integer;
   begin
      T := @ + 1;
      return T;
   end Uninitialized;

   function Initialized return Integer is
      T : Integer := X;
   begin
      T := @ + 1;
      return T;
   end Initialized;

   function In_Loop return Integer is
      T : Integer := 0;
   begin
      for I in 1 .. 3 loop
         T := @ + I;
      end loop;
      return T;
   end In_Loop;

   function Maybe (C : Boolean) return Integer is
      T : Integer;
   begin
      if C then
         T := 1;
      end if;
      T := @ + 1;
      return T;
   end Maybe;

   function Component return Integer is
      P : Pair;
   begin
      P.A := 1;
      P.A := @ + 1;
      P.B := @ + 1;
      return P.A;
   end Component;

   procedure Param (V : in out Integer) is
   begin
      V := @ * 2;
   end Param;

   Y : Integer := 1;
begin
   Param (Y);
   R := Uninitialized + Initialized + In_Loop + Maybe (X > 0) + Component + Y;
end Verification_Target_Name_Read;
