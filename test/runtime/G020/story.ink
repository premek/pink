VAR stamina = 11

-> fall_down_cliff

=== fall_down_cliff
You fall down a cliff!
-> hurt(5) ->
You're still alive! You pick yourself up and walk on.
-> fall_down_cliff

=== hurt(x)
	~ stamina -= x
	{ stamina <= 0:
		->-> youre_dead
	}
	->->

=== youre_dead
Suddenly, there is a white light all around you. Fingers lift an eyepiece from your forehead. 'You lost, buddy. Out of the chair.'
-> DONE
