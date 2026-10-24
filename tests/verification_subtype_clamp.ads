--  A value stored in a scalar object belongs to the object's subtype: the
--  range check of the store raises for any other. The Ok_* subprograms
--  have checks that follow from that subtype alone, whatever the range of
--  what was stored; those of the Bad_* subprograms do not, because the
--  subtype that the store is checked against is wider than the name it is
--  stored through, or than the value read back allows.
package Verification_Subtype_Clamp
  with SPARK_Mode
is
   subtype Small is Integer range 0 .. 100;

   procedure Ok_Assigned (A : Integer; X : out Integer);
   procedure Ok_Initial (A : Integer; X : out Integer);
   procedure Ok_Constraint (A : Integer; X : out Integer);
   procedure Ok_Named (A : Integer; X : out Integer);
   procedure Ok_Loop (Limit : Natural; X : out Integer);
   procedure Bad_Top (A : Integer; X : out Integer);
   procedure Bad_Renaming (A : Integer; X : out Integer);
   procedure Bad_Moved_Bound (A : Integer; X : out Integer);
end Verification_Subtype_Clamp;
