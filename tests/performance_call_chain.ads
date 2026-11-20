--  A chain of calls in prefix notation, as Alire writes its lists of
--  switches (Alire.Utils.Switches, 23 long): "Empty.Append (A).Append (B)".
--  Under --verify each link was walked twice, as the name of its call and
--  as its first actual, in a time that doubled with each link: 12 links
--  took a second, 23 half an hour. See tests/run_performance_smoke.sh.
package Performance_Call_Chain is

   type List is tagged record
      Count : Natural := 0;
   end record;

   Empty : constant List := (Count => 0);

   function Append (L : List; S : String) return List;

   function Switches return List;

end Performance_Call_Chain;
