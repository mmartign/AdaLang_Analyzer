--  Values that fit the type of the target but not the constraint its
--  declaration adds (FP-107): each check below can fail, so none may be
--  proved.
procedure Verification_Mutation_Declared_Constraint
  with SPARK_Mode
is
   subtype Small is Integer range 1 .. 10;
   type Rec is record
      Level : Integer range 1 .. 5 := 1;
   end record;
   type Vec is array (1 .. 4) of Integer range 0 .. 9;

   --  The trivial preconditions make GNATprove check each subprogram on
   --  its own: at the calls below the values happen to fit.

   procedure Into_Object (Wide : Integer; Result : out Integer)
     with Pre => True
   is
      Held : Integer range 1 .. 5 := 1;
   begin
      Held := Wide;
      Result := Held;
   end Into_Object;

   procedure At_Declaration (Initial : Small; Result : out Integer)
     with Pre => True
   is
      Held : constant Integer range 1 .. 5 := Initial;
   begin
      Result := Held;
   end At_Declaration;

   --  A conversion to Small says nothing about 2 .. 3.
   procedure Into_Narrowed (Cast : Integer; Result : out Integer)
     with Pre => Cast in 1 .. 10
   is
      Kept : Small range 2 .. 3 := 2;
   begin
      Kept := Small (Cast);
      Result := Kept;
   end Into_Narrowed;

   procedure Into_Component (Excess : Small; Item : in out Rec)
     with Pre => True
   is
   begin
      Item.Level := Excess;
   end Into_Component;

   procedure Into_Element (Loose : Integer; Data : in out Vec)
     with Pre => Loose in 0 .. 10
   is
   begin
      Data (2) := Loose;
   end Into_Element;

   procedure Through_Renaming (Above : Small; Result : out Integer)
     with Pre => True
   is
      Store : Integer range 1 .. 5 := 1;
      Alias : Integer renames Store;
   begin
      Alias := Above;
      Result := Store;
   end Through_Renaming;

   Item    : Rec;
   Data    : Vec := (others => 0);
   Outcome : Integer;
begin
   Into_Object (3, Outcome);
   At_Declaration (3, Outcome);
   Into_Narrowed (2, Outcome);
   Into_Component (4, Item);
   Into_Element (7, Data);
   Through_Renaming (5, Outcome);
end Verification_Mutation_Declared_Constraint;
