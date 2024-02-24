LIST heatedWaterStates = cold, boiling, recently_boiled
VAR kettleState = cold
VAR potState = cold
VAR microwaveState = recently_boiled

->do_cooking
=== cook_with(nameOfThing, ref thingToBoil)
+ 	{thingToBoil == cold} [Turn on {nameOfThing}]
  	The {nameOfThing} begins to heat up.
	~ thingToBoil = boiling
	-> do_cooking.done

=== do_cooking
<- cook_with("kettle", kettleState)
<- cook_with("pot", potState)
<- cook_with("microwave", microwaveState)
- (done)->DONE
