VAR stamina = 100
~harm(40)
{stamina}

=== function harm(x) ===
	{ stamina < x:
		~ stamina = 0
	- else:
		~ stamina = stamina - x
	}
