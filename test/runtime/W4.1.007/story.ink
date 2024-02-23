VAR stamina = 1
->fall_down_cliff
=== fall_down_cliff 
-> hurt(5) -> 
You're still alive! You pick yourself up and walk on.
->END

=== hurt(x)
	~ stamina -= x 
	{ stamina <= 0:
		->-> youre_dead
	}
->->

=== youre_dead
Suddenly, there is a white light all around you. Fingers lift an eyepiece from your forehead. 'You lost, buddy. Out of the chair.'
-> END
