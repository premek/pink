*	{say_no_to_nothing()} 'Yes.'


=== function say_yes_to_everything ===
	~ return true

=== function say_no_to_nothing ===
	~ return say_yes_to_everything()
