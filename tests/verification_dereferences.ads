--  Dereference checks: an access value that is dereferenced, explicitly
--  (".all") or implicitly (as the prefix of a component, of an indexed
--  component, of a slice or of an array attribute), is not null. The
--  dereferences of the subprograms named Ok_* are of access values known
--  not to be null: by a precondition, by the operand or the condition that
--  guards them, by a callee's postcondition, across a write through the
--  access value or to another part of the object holding it. Those of the
--  subprograms named Bad_* are not: the test comes after the dereference
--  (Bad_Order), there is none (Bad_Unguarded, Bad_Cell), the guard does not
--  cover the dereference (Bad_Branch), a call or an assignment may have
--  changed the access value since (Bad_Call, Bad_Moved, Bad_Shelf, the last
--  by a write to the element of an array the access value is in). Sure
--  dereferences an access value whose subtype excludes null: no check is
--  raised there, as GNATprove raises none. GNATprove proves the checks of
--  the Ok_* subprograms and none of those of the Bad_* ones.
package Verification_Dereferences with SPARK_Mode is

   type Bytes is array (Positive range <>) of Integer;
   type Bytes_Ptr is access Bytes;
   subtype Sure_Ptr is not null Bytes_Ptr;

   type Cell is record
      Value : Integer;
   end record;
   type Cell_Ptr is access Cell;

   type Holder is record
      Buffer : Bytes_Ptr;
      Marks  : Bytes (1 .. 4);
      Count  : Integer;
   end record;

   --  Not subject to ownership: a value is copied, never moved.
   type Bytes_View is access constant Bytes;

   type View_Holder is record
      View  : Bytes_View;
      Count : Integer;
   end record;

   type View_Holders is array (1 .. 2) of View_Holder;

   type Shelf is record
      Items : View_Holders;
   end record;

   function Ok_Guard (Ok_G : Bytes_Ptr) return Boolean is
     (Ok_G /= null and then Ok_G'Length > 0);

   function Bad_Order (Bad_O : Bytes_Ptr) return Boolean is
     (Bad_O'Length > 0 and then Bad_O /= null);

   function Ok_Pre (Ok_P : Bytes_Ptr) return Natural is (Ok_P'Length)
     with Pre => Ok_P /= null;

   function Bad_Unguarded (Bad_U : Bytes_Ptr) return Natural is
     (Bad_U'Length);

   function Ok_Slice (Ok_S : Bytes_Ptr) return Bytes is
     (Ok_S (Ok_S'First .. Ok_S'Last))
     with Pre => Ok_S /= null;

   function Sure (Sure_B : Sure_Ptr) return Natural is (Sure_B'Length);

   function Ok_Cell (Ok_C : Cell_Ptr) return Integer is (Ok_C.Value)
     with Pre => Ok_C /= null;

   function Bad_Cell (Bad_C : Cell_Ptr) return Integer is (Bad_C.all.Value);

   procedure Ok_Write (Ok_W : in out Holder)
     with Pre => Ok_W.Buffer /= null and then Ok_W.Buffer'Length > 0;

   procedure Ok_Branch (Ok_B : in out Holder);

   procedure Bad_Branch (Bad_B : in out Holder);

   --  No contract: what it leaves of its parameter is not known.
   procedure Touch (T : in out Holder);

   procedure Bad_Call (Bad_K : in out Holder)
     with Pre => Bad_K.Buffer /= null;

   procedure Bad_Moved (Bad_M : in out Holder; Moved : out Bytes_Ptr)
     with Pre => Bad_M.Buffer /= null;

   procedure Take (From : in out Holder; Taken : out Bytes_Ptr)
     with Pre  => From.Buffer /= null,
          Post => Taken /= null and From.Buffer = null;

   procedure Ok_Take (Ok_T : in out Holder; N : out Natural)
     with Pre => Ok_T.Buffer /= null;

   procedure Bad_Shelf (Bad_S : in out Shelf)
     with Pre => Bad_S.Items (1).View /= null;

end Verification_Dereferences;
