LIST heatedWaterStates = cold, boiling, recently_boiled
VAR kettleState = cold
VAR potState = cold
VAR microwaveState = cold

-> do_cooking

=== function boilSomething(ref thingToBoil, nameOfThing)
	The {nameOfThing} begins to heat up.
	~ thingToBoil = boiling

=== do_cooking
*	{kettleState == cold} [Turn on kettle]
	{boilSomething(kettleState, "kettle")}
*	{potState == cold} [Light stove]
	{boilSomething(potState, "pot")}
*	{microwaveState == cold} [Turn on microwave]
	{boilSomething(microwaveState, "microwave")}
-{kettleState}->END
