with Abstract_Ops.Operators;
with Abstract_Ops.Operations;
package Abstract_Ops_User with SPARK_Mode, Always_Terminates is
   type My_Index is range 1 .. 100;
   type My_Length is range 0 .. 100;
   package T is new Abstract_Ops (My_Index, My_Length);
   package O is new T.Operators;
   package P is new T.Operations (O);
   procedure Use_It (C : out Natural);
end Abstract_Ops_User;
