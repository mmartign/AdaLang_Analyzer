--  Mutations of verification_access_contexts: claims about a record that
--  holds an access value that do not hold, or that nothing given here
--  shows. None may be proved; GNATprove proves none of them.
package Verification_Mutation_Access_Contexts
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

   --  F_A made invalid while F_B may still be well formed.
   procedure Reset_A (Broken_Order : in out Context);

   --  Verified_Last lowered below the cursors it bounds.
   procedure Lower (Lowered : in out Context);

   --  A cursor made well formed past Verified_Last.
   procedure Overrun_C (Overrun : in out Context)
   with Pre => Overrun.First <= Overrun.Verified_Last
               and then Overrun.Verified_Last < Overrun.Last;

   --  The buffers of two contexts.
   procedure Two_Buffers (Left, Right : Context; Same : out Boolean)
   with Pre => Has_Buffer (Left) and then Has_Buffer (Right);

   --  The access formal given the buffer of the other context.
   procedure Other_Formal (Mine, Theirs : Context; Same : out Boolean)
   with Pre => Has_Buffer (Mine) and then Has_Buffer (Theirs);

   --  The first bound of the buffer is not its last.
   procedure Wrong_Bound (Holder : Context)
   with Pre => Has_Buffer (Holder);

   --  The buffer given away is null after.
   procedure Drop (Gone : in out Context)
   with Pre => Has_Buffer (Gone);

   --  No cursor is well formed.
   procedure None_Formed (Idle : Context)
   with Pre => (for all F in Field => Idle.Cursors (F).State = S_Invalid);

   --  An allocation made in a loop is another value each time round.
   procedure Grow (Final : out Index);
end Verification_Mutation_Access_Contexts;
