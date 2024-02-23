-> plains
=== plains ===
= night_time
	The dark grass is soft under your feet.
	+	[Sleep]
		-> sleep_here -> wake_here -> day_time
= day_time
	It is time to move on.
	-> END

=== wake_here ===
	You wake as the sun rises.
	+	[Eat something]
		-> eat_something ->
	+	[Make a move]
	-	->->

=== sleep_here ===
	You lie down and try to close your eyes.
	-> monster_attacks ->
	Then it is time to sleep.
	-> dream ->
	->->

=== monster_attacks ===
    monster attacks
	->->
=== dream ===
    dream
	->->
=== eat_something ===
    eat something
	->->
