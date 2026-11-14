--  AdaLang Analyzer
--
--  Copyright (C) 2026, Spazio IT
--
--  SPDX-License-Identifier: GPL-3.0-or-later

--  FP-143: the value an expression function returns, in parentheses, is
--  computed with an overflow that always occurs, so the range check of the
--  returned value against the result subtype is never reached: the
--  overflow is the one definite error there (SPARK testsuite unit
--  M927-010__bad_function). A value returned without overflow that is
--  outside the result subtype still fails its range check.
package Verification_FP143_Overflow_Before_Result with SPARK_Mode is
   function Ident (X : Integer) return Integer is (X);
   function Bad return Natural is (Ident (Integer'Last) + 1);
   function Below return Natural is (Ident (-5) + 2);
end Verification_FP143_Overflow_Before_Result;
