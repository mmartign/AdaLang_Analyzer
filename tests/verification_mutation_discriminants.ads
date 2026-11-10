--  Discriminant checks that do not hold, or that nothing shows to hold
--  (see the body): verification_discriminants without what makes each one
--  hold.
with Ada.Finalization;

package Verification_Mutation_Discriminants with SPARK_Mode is

   type Kind is (A, B, C);

   type Shape (K : Kind) is record
      Common : Integer := 0;
      case K is
         when A =>
            X : Integer;
         when B | C =>
            Y : Integer;
      end case;
   end record;

   type Option (Exists : Boolean := False) is record
      case Exists is
         when True =>
            V : Integer;
         when False =>
            null;
      end case;
   end record;

   type Context (First, Last : Integer := 0) is record
      Cur : Integer := 0;
   end record;

   type Channel (Is_Secure : Boolean) is record
      case Is_Secure is
         when True =>
            Ssl : Integer;
         when False =>
            Client : Integer;
      end case;
   end record;

   procedure Wrong_Guard (Wrong : in out Shape) with Global => null;

   procedure No_Guard (Bare : in out Shape) with Global => null;

   procedure Maybe_Constrained (Ctx_Bad : out Context; F : Integer)
   with Global => null;

   procedure After_Aggregate (Gone : in out Option; Z : out Integer)
   with Global => null;

   procedure Constrained_Local (Z : out Integer) with Global => null;

   procedure Touch_Option (Opt : in out Option) with Global => null;

   procedure After_Mutable_Call (Flip : in out Option; Z : out Integer)
   with Global => null;

   procedure Other_Kind (Other : in out Shape) with Global => null;

   procedure Out_No_Guard (Plain : in out Channel) with Global => null;

   generic
      type Formal (D : Boolean) is private;
      with procedure Change (Formal_Item : in out Formal);
   procedure Keep_Formal (Formal_Item : in out Formal);

   --  Its Finalize changes Counter.
   Counter : Integer := 0;

   type Guard is new Ada.Finalization.Controlled with null record;
   overriding procedure Finalize (Object : in out Guard);

   type Guarded (Held : Boolean := False) is record
      case Held is
         when True =>
            Item : Guard;
         when False =>
            null;
      end case;
   end record;

   procedure Implicit_Code (Z : in out Integer) with Global => (In_Out => Counter);

end Verification_Mutation_Discriminants;
