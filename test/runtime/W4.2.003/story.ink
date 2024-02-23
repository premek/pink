->outside_the_house
=== outside_the_house
The front step. The house smells. Of murder. And lavender.
- (top)
	<- review_case_notes(-> top)
	+	[Go through the front door]
		I stepped inside the house.
		-> the_hallway
	+ 	[Sniff the air]
		I hate lavender. It makes me think of soap, and soap makes me think about my marriage.
		-> top

=== the_hallway
The hallway. Front door open to the street. Little bureau.
- (top)
	<- review_case_notes(-> top)
	+	[Go through the front door]
		I stepped out into the cool sunshine.
		-> outside_the_house
	+ 	[Open the bureau]
		Keys. More keys. Even more keys. How many locks do these people need?
		-> END

=== review_case_notes(-> go_back_to)
+	{not done || TURNS_SINCE(-> done) > 10}
	[Review my case notes]
	// the conditional ensures you don't get the option to check repeatedly
 	{I|Once again, I} flicked through the notes I'd made so far. Still not obvious suspects.
- 	(done) -> go_back_to
