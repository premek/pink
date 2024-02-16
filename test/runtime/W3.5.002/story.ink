VAR x = -1

~ x = lerp(2, 8, 0.3)

*	{say_yes_to_everything()} 'Yes.' {x}


=== function say_yes_to_everything ===
	~ return true

=== function lerp(a, b, k) ===
	~ return ((b - a) * k) + a
