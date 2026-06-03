VAR global = 1
~ alter(global, 10)
{global}

~ temp local = 2
~ alter(local, 20)
{local}

=== function alter(ref x, k) ===
	~ x = x + k
