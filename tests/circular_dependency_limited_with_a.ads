with Circular_Dependency_Limited_With_B;

package Circular_Dependency_Limited_With_A is
   type Ref is access all Circular_Dependency_Limited_With_B.Info;
end Circular_Dependency_Limited_With_A;
