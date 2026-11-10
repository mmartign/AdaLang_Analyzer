--  Each discriminant check here holds, and GNATprove proves it:
--  - a component read or written under an if, an else, an "and then", a
--    case alternative or a precondition that selects its variant, after a
--    return on the other variant, and after a call on an object whose type
--    has no default (its discriminants never change);
--  - a discriminant of an out parameter, which is its actual's;
--  - a component given as an out actual;
--  - a private type, whose contracts read the partial view's discriminant
--    and whose body the full view's;
--  - an assignment to a component or a local that is not constrained, to
--    a formal that a precondition says is not, of 'Update, of an aggregate
--    of the target's own discriminants, of a copy of a component, and of
--    an aggregate to a local declared with the same constraint;
--  - after an aggregate, its discriminants;
--  - with a local of a type whose objects run code declared elsewhere.
--  verification_mutation_discriminants has what does not hold.
package body Verification_Discriminants with SPARK_Mode is

   procedure Touch (Item : in out Shape) is
   begin
      Item.Common := 0;
   end Touch;

   procedure By_If (Item_If : in out Shape) is
   begin
      if Item_If.K = A then
         Item_If.X := 1;
      else
         Item_If.Y := 2;
      end if;
   end By_If;

   procedure By_Pre (Item_Pre : in out Shape) is
   begin
      Item_Pre.X := 3;
   end By_Pre;

   procedure After_Call (Item_Call : in out Shape) is
   begin
      if Item_Call.K = A then
         Touch (Item_Call);
         Item_Call.X := 4;
      end if;
   end After_Call;

   procedure By_Return (Opt_Ret : Option; Z : out Integer) is
   begin
      if not Opt_Ret.Exists then
         Z := 0;
         return;
      end if;
      Z := Opt_Ret.V;
   end By_Return;

   procedure Component_Target (Hold : in out Holder) is
   begin
      Hold.O := (Exists => True, V => 1);
      Hold.N := Hold.O.V;
   end Component_Target;

   procedure Local_Target (Z : out Integer) is
      Local : Option;
   begin
      Local := (Exists => True, V => 5);
      Z := Local.V;
   end Local_Target;

   procedure Init (Ctx_Init : out Context; F, L : Integer) is
   begin
      Ctx_Init := (F, L, 0);
   end Init;

   procedure Set_Cur (Ctx_Upd : in out Context) is
   begin
      pragma Warnings (Off, "attribute Update is an obsolescent feature");
      Ctx_Upd := Ctx_Upd'Update (Cur => 1);
      pragma Warnings (On, "attribute Update is an obsolescent feature");
   end Set_Cur;

   procedure Move (Ctx_Same : in out Context; F : Integer) is
   begin
      Ctx_Same := (Ctx_Same.First, Ctx_Same.Last, F);
   end Move;

   procedure Restore (Hold_Tmp : in out Holder) is
      Saved : constant Option := Hold_Tmp.O;
   begin
      Hold_Tmp.N := 1;
      Hold_Tmp.O := Saved;
   end Restore;

   function To_Resource (Data : Bytes; Fmt : Integer) return Resource is
      Made : Resource (Last => Data'Length);
   begin
      Made := (Last => Data'Length, Data => Data, Fmt => Fmt);
      return Made;
   end To_Resource;

   procedure Out_Read (Item_Out : out Shape) is
   begin
      Item_Out.Common := 0;
      if Item_Out.K = A then
         Item_Out.X := 0;
      else
         Item_Out.Y := 0;
      end if;
   end Out_Read;

   procedure Create (Opt : in out Option) with Global => null;

   procedure Create (Opt : in out Option) is
   begin
      if not Opt'Constrained then
         Opt := (Exists => True, V => 1);
      end if;
   end Create;

   procedure Configure (Chan : out Channel; Server : Boolean) is
      Choice : Setting;
   begin
      Chan.Attached := (Exists => False);
      Create (Chan.Attached);
      if not Chan.Attached.Exists then
         return;
      end if;
      Choice := (Named => False, Level => 1);
      if not Chan.Is_Secure then
         Chan.Client := Choice.Level;
      else
         Chan.Result := 0;
         Chan.Ssl := (if Server then Chan.Attached.V else 0);
      end if;
   end Configure;

   procedure Report (Chan_Pre : Channel; Z : out Integer) is
   begin
      Z := Chan_Pre.Ssl;
   end Report;

   procedure Set_Out (N : out Integer) with Global => null;

   procedure Set_Out (N : out Integer) is
   begin
      N := 3;
   end Set_Out;

   procedure Out_Actual (Chan_Out : in out Channel) is
   begin
      if Chan_Out.Is_Secure then
         Set_Out (Chan_Out.Ssl);
      else
         Set_Out (Chan_Out.Client);
      end if;
   end Out_Actual;

   procedure From_Call (V : Integer; Z : out Integer) is
      Kept : Option (Exists => True);
   begin
      Kept := Made (V);
      Z := Kept.V;
   end From_Call;

   procedure Set_Shared (V : Integer) is
      Copy : Option (Exists => True);
   begin
      Shared := (Exists => True, V => 16);
      Copy := Made (Shared.V);
      if Copy.V = 16 then
         Shared := (Exists => True, V => V);
      end if;
   end Set_Shared;

end Verification_Discriminants;
