package body Verification_Operator_Calls
  with SPARK_Mode
is
   package body Types is
      package body User is
         function Next (I : Index) return Index is
         begin
            return I + 9;
         end Next;

         function Count (L, R : Index) return Natural is
            Result : Natural := 0;
         begin
            for I in L .. R - 1 loop
               if Result < Natural'Last then
                  Result := Result + 1;
               end if;
            end loop;
            return Result;
         end Count;

         function Span (L, R : Index) return Length is
         begin
            return R - L;
         end Span;

         function Converted (L, R : Index) return Natural is
         begin
            return Natural (R - L);
         end Converted;
      end User;
   end Types;

   package T is new Types (Idx, Len);
   package O is new T.Operators;
   package U is new T.User (O);
end Verification_Operator_Calls;
