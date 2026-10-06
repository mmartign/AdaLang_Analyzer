--  FP-110: the formal Checked is at line 5, column 17. In the body the
--  formal Other is at line 5, column 17 too.
package Verification_FP110_Same_Position is
   --
   procedure P (Checked : Integer; Other : Integer) with Pre => Checked > 5;
end Verification_FP110_Same_Position;
