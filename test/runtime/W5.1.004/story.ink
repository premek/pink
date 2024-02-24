LIST kettleState = cold, boiling, recently_boiled
~ kettleState = cold
-(top)
*	[Turn on kettle]
	The kettle begins to bubble and boil.
	~ kettleState = boiling
	->top
+	[Touch the kettle]
	{ kettleState == cold:
		The kettle is cool to the touch.
	- else:
	 	The outside of the kettle is very warm!
	 	->END
	}
	->top
