limited with Circular_Dependency_Limited_With_A;

package Circular_Dependency_Limited_With_B is
   type Info is null record;
   type Back_Ref is access all Circular_Dependency_Limited_With_A.Ref;
end Circular_Dependency_Limited_With_B;
