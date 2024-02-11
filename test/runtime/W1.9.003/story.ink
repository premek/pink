// TODO better testcase
*	{TURNS_SINCE(-> sleeping.intro) > 10} You are feeling tired... -> sleeping
* 	{TURNS_SINCE(-> laugh) == 0}  You try to stop laughing.
    ->laugh
=laugh
->END
==sleeping
=intro
->END
