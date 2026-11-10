--  Each named discriminant check, and the assertions, may fail:
--  - Wrong.X under the guard of the other variant (fails wherever reached);
--  - Bare.Y with no guard;
--  - an aggregate given to an out parameter that may be constrained;
--  - Gone given another discriminant, which fails if the actual is
--    constrained, then Gone.V (fails wherever reached);
--  - a local constrained to True given False (fails wherever reached);
--  - Flip.V after a call on a parameter whose type has defaults, which
--    may change its discriminant;
--  - Other given another kind;
--  - Plain.Ssl, an out actual, with no guard;
--  - a discriminant of a generic formal type after a call: the actual may
--    have defaults, and an instance's parameter be unconstrained;
--  - Counter, which Finalize of a component of a local changes where the
--    source shows no call (Z, which that code cannot see, stands).
package body Verification_Mutation_Discriminants with SPARK_Mode is

   procedure Wrong_Guard (Wrong : in out Shape) is
   begin
      if Wrong.K = B then
         Wrong.X := 1;
      end if;
   end Wrong_Guard;

   procedure No_Guard (Bare : in out Shape) is
   begin
      Bare.Y := 1;
   end No_Guard;

   procedure Maybe_Constrained (Ctx_Bad : out Context; F : Integer) is
   begin
      Ctx_Bad := (F, F, 0);
   end Maybe_Constrained;

   procedure After_Aggregate (Gone : in out Option; Z : out Integer) is
   begin
      Z := 0;
      if Gone.Exists then
         Gone := (Exists => False);
         Z := Gone.V;
      end if;
   end After_Aggregate;

   procedure Constrained_Local (Z : out Integer) is
      Fixed : Option (True) := (Exists => True, V => 1);
   begin
      Fixed := (Exists => False);
      Z := 0;
   end Constrained_Local;

   procedure Touch_Option (Opt : in out Option) is
   begin
      if not Opt'Constrained then
         Opt := (Exists => False);
      end if;
   end Touch_Option;

   procedure After_Mutable_Call (Flip : in out Option; Z : out Integer) is
   begin
      Z := 0;
      if Flip.Exists then
         Touch_Option (Flip);
         Z := Flip.V;
      end if;
   end After_Mutable_Call;

   procedure Other_Kind (Other : in out Shape) is
   begin
      Other := (K => B, Common => 0, Y => 0);
   end Other_Kind;

   procedure Set_Out (N : out Integer) with Global => null;

   procedure Set_Out (N : out Integer) is
   begin
      N := 3;
   end Set_Out;

   procedure Out_No_Guard (Plain : in out Channel) is
   begin
      Set_Out (Plain.Ssl);
   end Out_No_Guard;

   procedure Keep_Formal (Formal_Item : in out Formal) is
      Before : constant Boolean := Formal_Item.D;
   begin
      Change (Formal_Item);
      pragma Assert (Formal_Item.D = Before);
   end Keep_Formal;

   overriding procedure Finalize (Object : in out Guard) is
   begin
      Counter := Counter + 1;
   end Finalize;

   procedure Implicit_Code (Z : in out Integer) is
      Seen  : constant Integer := Counter;
      Kept  : constant Integer := Z;
      Local : Guarded;
   begin
      Local := (Held => False);
      pragma Assert (Counter = Seen);
      pragma Assert (Z = Kept);
   end Implicit_Code;

end Verification_Mutation_Discriminants;
