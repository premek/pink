VAR fear = 100
->visited_snakes
=== visited_snakes
-> dream_about_snakes
===dream_about_snakes
-> visited_poland
===visited_poland
->dream
===dream_about_polish_beer
mhmm... {fear}
->END
===dream_about_marmalade
->END

=== dream ===
	{
		- visited_snakes && not dream_about_snakes:
			~ fear++
			-> dream_about_snakes

		- visited_poland && not dream_about_polish_beer:
			~ fear--
			-> dream_about_polish_beer

		- else:
			// breakfast-based dreams have no effect
			-> dream_about_marmalade
	}
