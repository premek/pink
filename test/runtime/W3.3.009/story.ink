-(loop)

// Sequence: go through the alternatives, and stick on last
{ stopping:
	-	I entered the casino.
	-  Once more, I went inside.
}

// Shuffle: show one at random
At the table, I drew a card. <>
{ shuffle:
	- 	Ace of Hearts.
	- 	2 of Diamonds.
		'You lose this time!' crowed the croupier.
}

// Cycle: show each in turn, and then cycle
{ cycle:
	- I held my breath.
	- I waited impatiently.
}

// Once: show each, once, in turn, until all have been shown
{ once:
	- Would my luck hold?
	- Could I win the hand?
}

{->loop|->loop|->loop|}
