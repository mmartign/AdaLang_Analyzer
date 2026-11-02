package body Verification_Mutation_Operator_Calls
  with SPARK_Mode
is
   package body Types is
      package body User is
         function Crossed (I : Index) return Index is
         begin
            return I + 1;
         end Crossed;

         function Unchecked (I : Index) return Index is
         begin
            return I + 1;
         end Unchecked;

         function Bound (L, R : Index) return Natural is
            Result : Natural := 0;
         begin
            for I in L .. R - 1 loop
               if Result < Natural'Last then
                  Result := Result + 1;
               end if;
            end loop;
            return Result;
         end Bound;

         function Reversed (L, R : Index) return Length is
         begin
            return R - L;
         end Reversed;
      end User;
   end Types;

   package T is new Types (Idx, Len);
   package O is new T.Operators;
   package U is new T.User (O);
end Verification_Mutation_Operator_Calls;
