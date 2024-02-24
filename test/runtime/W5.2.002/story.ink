LIST heatedWaterStates = cold, boiling, recently_boiled
VAR kettleState = cold
VAR potState = cold

*	{kettleState == cold} [Turn on kettle]
	The kettle begins to boil and bubble.
	~ kettleState = boiling
*	{potState == cold} [Light stove]
 	The water in the pot begins to boil and bubble.
 	~ potState = boiling

- {kettleState}
