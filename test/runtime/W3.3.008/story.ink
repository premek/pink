VAR door_open = false
-> knot
===open_door
~door_open=true
->knot
===go_outside
->END

===knot
{ door_open:
	* 	I strode out of the compartment[] and I fancied I heard my master quietly tutting to himself. 			-> go_outside
- else:
	*	I asked permission to leave[] and Monsieur Fogg looked surprised. 	-> open_door
	* 	I stood and went to open the door[]. Monsieur Fogg seemed untroubled by this small rebellion. -> open_door
}
