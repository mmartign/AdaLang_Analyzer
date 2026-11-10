--  Discriminant checks (see the body): the components of a variant part
--  read, written or given as an actual under what selects their variant,
--  and assignments to records with discriminants.
with Ada.Strings.Unbounded;

package Verification_Discriminants with SPARK_Mode is

   type Kind is (A, B, C);

   --  No default: every object is constrained.
   type Shape (K : Kind) is record
      Common : Integer := 0;
      case K is
         when A =>
            X : Integer;
         when B | C =>
            Y : Integer;
      end case;
   end record;

   --  A default: an object declared with the name of the type alone is
   --  not constrained.
   type Option (Exists : Boolean := False) is record
      case Exists is
         when True =>
            V : Integer;
         when False =>
            null;
      end case;
   end record;

   type Holder is record
      O : Option;
      N : Integer := 0;
   end record;

   type Context (First, Last : Integer := 0) is record
      Cur : Integer := 0;
   end record;

   type Bytes is array (Positive range <>) of Integer;

   type Resource (Last : Natural) is record
      Data : Bytes (1 .. Last);
      Fmt  : Integer;
   end record;

   --  A variant holds an Unbounded_String, whose objects run code
   --  implicitly: code declared elsewhere, which sees none of the objects
   --  of a subprogram that declares one.
   type Setting (Named : Boolean := False) is record
      case Named is
         when True =>
            Device : Ada.Strings.Unbounded.Unbounded_String;
         when False =>
            Level : Integer;
      end case;
   end record;

   type Channel (Is_Secure : Boolean) is limited private;

   procedure Touch (Item : in out Shape) with Global => null;

   procedure By_If (Item_If : in out Shape) with Global => null;

   procedure By_Pre (Item_Pre : in out Shape)
   with Global => null, Pre => Item_Pre.K = A;

   procedure After_Call (Item_Call : in out Shape) with Global => null;

   procedure By_Return (Opt_Ret : Option; Z : out Integer)
   with Global => null;

   function By_And (Opt_And : Option) return Boolean is
     (Opt_And.Exists and then Opt_And.V > 0);

   function By_Case (Item_Case : Shape) return Integer is
     (case Item_Case.K is
         when A     => Item_Case.X,
         when B | C => Item_Case.Y);

   procedure Component_Target (Hold : in out Holder) with Global => null;

   procedure Local_Target (Z : out Integer) with Global => null;

   procedure Init (Ctx_Init : out Context; F, L : Integer)
   with Global => null, Pre => not Ctx_Init'Constrained;

   procedure Set_Cur (Ctx_Upd : in out Context) with Global => null;

   procedure Move (Ctx_Same : in out Context; F : Integer)
   with Global => null;

   procedure Restore (Hold_Tmp : in out Holder) with Global => null;

   function To_Resource (Data : Bytes; Fmt : Integer) return Resource
   with Global => null, Pre => Data'First = 1;

   procedure Out_Read (Item_Out : out Shape)
   with Global => null, Relaxed_Initialization => Item_Out;

   procedure Configure (Chan : out Channel; Server : Boolean)
   with Global => null, Relaxed_Initialization => Chan;

   procedure Report (Chan_Pre : Channel; Z : out Integer)
   with Global => null, Pre => Chan_Pre.Is_Secure;

   procedure Out_Actual (Chan_Out : in out Channel) with Global => null;

   function Is_Valid (Chan_Valid : Channel) return Boolean
   with Global => null;

   --  The discriminants of a function's value, and those of a target given
   --  on entry by nothing, are not known: the check of such an assignment
   --  to a constrained object holds or not, it is never a definite error.
   subtype Some_Option is Option (Exists => True);

   function Made (V : Integer) return Some_Option is (Exists => True, V => V);

   Shared : Option (Exists => True);

   procedure From_Call (V : Integer; Z : out Integer) with Global => null;

   procedure Set_Shared (V : Integer) with Global => (Output => Shared);

private

   type Channel (Is_Secure : Boolean) is limited record
      Attached : Option;
      case Is_Secure is
         when True =>
            Ssl    : Integer;
            Result : Integer;
         when False =>
            Client : Integer;
      end case;
   end record;

   function Is_Valid (Chan_Valid : Channel) return Boolean is
     (Chan_Valid.Attached.Exists
      and then (if Chan_Valid.Is_Secure then Chan_Valid.Result = 0));

end Verification_Discriminants;
