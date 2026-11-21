--  FP-154: a renaming of an object reads no value of it, but a renaming of
--  what a function call or a dereference gives reads the objects the call
--  or the dereference reads (gnatcoll's "Str : String renames Data.Token
--  (Event.First, Event.Last);", SPARKlib's "SN : Node_Type renames
--  Source.Content.Nodes (Source_Node);" with Content an access value).

procedure Verification_Renaming_Reads (Out1 : out Integer; R : out Integer) is
   type Rec is record
      F : Integer;
   end record;
   type Arr is array (1 .. 3) of Integer;
   type Ptr is access Integer;
   type Rec_Ptr is access Rec;
   type Arr_Ptr is access Arr;
   package P is
      type T is tagged record
         V : Integer;
      end record;
      function Get (Self : T) return Integer is (Self.V);
   end P;
   function Twice (X : Integer) return Integer is (2 * X);
   Obj  : Rec;
   A    : Arr;
   Item : P.T;
   Ref  : Ptr;
   RP   : Rec_Ptr;
   AP   : Arr_Ptr;
   N    : Integer;
begin
   declare
      Whole : Integer renames Out1;           --  no read of Out1
      Comp  : Integer renames Obj.F;          --  no read of Obj
      Elem  : Integer renames A (2);          --  no read of A
      Own   : Rec_Ptr renames RP;             --  no read of RP
      Res   : Integer renames Twice (N);      --  reads N
      Pre   : Integer renames Item.Get;       --  reads Item
      Deref : Integer renames Ref.all;        --  reads Ref
      Sel   : Integer renames RP.F;           --  reads RP
      Idx   : Integer renames AP (1);         --  reads AP
   begin
      Whole := 1;
      Comp := 1;
      Elem := 1;
      R := Res + Pre + Deref + Sel + Idx + Own.F;
   end;
end Verification_Renaming_Reads;
