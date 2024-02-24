LIST kettleState = cold, boiling, recently_boiled
~ kettleState = cold

*	[Turn on kettle]
	The kettle begins to bubble and boil.
	~ kettleState = boiling
	
	{kettleState}

