LIST OnOff = on, off
LIST HotCold = cold, warm, hot

VAR kettleState = (off, cold)

~turnOnKettle()
{can_make_tea()}
~wait()
{can_make_tea()}


=== function turnOnKettle() ===
{ kettleState ? hot:
	You turn on the kettle, but it immediately flips off again.
- else:
	The water in the kettle begins to heat up.
	~ kettleState -= off
	~ kettleState += on
	// note we avoid "=" as it'll remove all existing states
}

=== function can_make_tea() ===
	~ return kettleState ? (hot, off)
	
=== function wait() ===
{ kettleState ? on:
~ kettleState = (hot, off)
}
