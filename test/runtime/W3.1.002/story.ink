VAR mood = 1
VAR knows_about_wager=false
->the_train
=== the_train ===
	The train jolted and rattled. { mood > 0:I was feeling positive enough, however, and did not mind the odd bump|It was more than I could bear}.
	*	{ not knows_about_wager } 'But, Monsieur, why are we travelling?'[] I asked.
	* 	{ knows_about_wager} I contemplated our strange adventure[]. Would it be possible?
	- ->END
