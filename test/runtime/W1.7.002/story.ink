// Fallback choices are never displayed to the player, but are 'chosen' by the game if no other options exist.
// A fallback choice is simply a "choice without choice text":
// *	-> out_of_options
// And, in a slight abuse of syntax, we can make a default choice with content in it, using an "choice then arrow":

-> find_help
=== find_help ===

	You search desperately for a friendly face in the crowd.
	*	The woman in the hat[?] pushes you roughly aside. -> find_help
	*	The man with the briefcase[?] looks disgusted as you stumble past him. -> find_help
	*	->
		But it is too late: you collapse onto the station platform. This is the end.
		-> END
