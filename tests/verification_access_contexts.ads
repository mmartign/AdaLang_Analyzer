--  The predicate of a record that holds an access value, as the contexts
--  RecordFlux generates have it: the bounds of the array the access value
--  designates are functions of that value, an access formal of an
--  expression function stands for its actual, a write of an access value
--  (null among them) keeps what is known of the rest, and a quantified
--  expression over a few values that gives a record formal an element at
--  the parameter is taken value by value. Each predicate check of an
--  assignment to a part of the record follows from the predicate on entry,
--  and so do the postconditions and the assertions below. Every claim here
--  holds; GNATprove proves each. verification_mutation_access_contexts has
--  those that do not.
package Verification_Access_Contexts
  with SPARK_Mode
is
   type Index is range 1 .. 2 ** 31 - 2;
   type Bit_Length is range 0 .. 2 ** 34 - 8;
   subtype Bit_Index is Bit_Length range 1 .. Bit_Length'Last;
   type Byte is mod 2 ** 8;
   type Bytes is array (Index range <>) of Byte;
   type Bytes_Ptr is access Bytes;

   type Field is (F_A, F_B, F_C);
   type Cursor_State is (S_Valid, S_Well_Formed, S_Invalid, S_Incomplete);
   type Field_Cursor is record
      State : Cursor_State := S_Invalid;
      First : Bit_Index := Bit_Index'First;
      Last  : Bit_Length := Bit_Length'First;
   end record;
   type Field_Cursors is array (Field) of Field_Cursor;

   function Well_Formed (C : Field_Cursor) return Boolean is
     (C.State = S_Valid or C.State = S_Well_Formed);

   function Cursors_Invariant
     (Cursors : Field_Cursors; First : Bit_Index; Verified_Last : Bit_Length)
      return Boolean
   is (for all F in Field =>
         (if Well_Formed (Cursors (F))
          then Cursors (F).First >= First
               and Cursors (F).Last <= Verified_Last
               and Cursors (F).First <= Cursors (F).Last + 1));

   function Valid_Context
     (Buffer_First, Buffer_Last : Index; First : Bit_Index; Last : Bit_Length;
      Verified_Last, Written_Last : Bit_Length; Buffer : Bytes_Ptr;
      Cursors : Field_Cursors) return Boolean
   is ((if Buffer /= null then
          Buffer'Length > 0
          and Buffer'First = Buffer_First
          and Buffer'Last = Buffer_Last)
       and then First <= Last + 1
       and then Last < Bit_Index'Last
       and then First - 1 <= Verified_Last
       and then Verified_Last <= Written_Last
       and then Written_Last <= Last
       and then Cursors_Invariant (Cursors, First, Verified_Last)
       and then (if Well_Formed (Cursors (F_B))
                 then Well_Formed (Cursors (F_A))));

   type Context
     (Buffer_First, Buffer_Last : Index := Index'First;
      First : Bit_Index := Bit_Index'First;
      Last : Bit_Length := Bit_Length'First) is
   record
      Verified_Last : Bit_Length := First - 1;
      Written_Last  : Bit_Length := First - 1;
      Buffer        : Bytes_Ptr := null;
      Cursors       : Field_Cursors := (others => <>);
   end record
   with Dynamic_Predicate =>
     Valid_Context (Context.Buffer_First, Context.Buffer_Last, Context.First,
                    Context.Last, Context.Verified_Last, Context.Written_Last,
                    Context.Buffer, Context.Cursors);

   function Has_Buffer (Ctx : Context) return Boolean is (Ctx.Buffer /= null);

   function Ends_At (Buffer : Bytes_Ptr; Last : Index) return Boolean is
     (Buffer /= null and then Buffer'Last = Last);

   --  The access component given away and set to null.
   procedure Take_Buffer (Taken : in out Context; Buffer : out Bytes_Ptr)
   with Pre  => Has_Buffer (Taken),
        Post => not Has_Buffer (Taken)
                and then Buffer /= null
                and then Buffer'Length > 0
                and then Taken.Buffer_First = Buffer'First
                and then Taken.Buffer_Last = Buffer'Last;

   --  A cursor made invalid.
   procedure Reset_C (Cleared : in out Context);

   --  A scalar component moved up to another that bounds it.
   procedure Verify_All (Verified : in out Context);

   --  Two scalar components given by 'Update.
   procedure Set_Last (Updated : in out Context; L : Bit_Length)
   with Pre => L in Updated.Verified_Last .. Updated.Last;

   --  A cursor made well formed within the bounds; then one of the cursors
   --  is.
   procedure Set_C (Placed : in out Context)
   with Pre => Placed.First <= Placed.Verified_Last;

   --  The bounds of the buffer, from the predicate on entry; an access
   --  formal of an expression function.
   procedure Read_Bounds (Holder : Context; Last : out Index)
   with Pre  => Has_Buffer (Holder),
        Post => Last = Holder.Buffer_Last
                and then Ends_At (Holder.Buffer, Holder.Buffer_Last);
end Verification_Access_Contexts;
