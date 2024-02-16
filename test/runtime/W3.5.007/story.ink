VAR health = 4
VAR foggs_health = 8

*	I ate a biscuit[] and felt refreshed. {alter(health, 2)}
* 	I gave a biscuit to Monsieur Fogg[] and he wolfed it down most undecorously. {alter(foggs_health, 1)}
-	<> Then we continued on our way.
{health}

=== function alter(ref x, k) ===
	~ x = x + k
