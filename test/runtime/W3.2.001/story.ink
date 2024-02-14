VAR knows_about_wager=false
VAR x=12
VAR y=10
VAR c=-42.8

->set_some_variables
=== set_some_variables ===
	~ knows_about_wager = true
	~ x = (x * x) - (y * y) + c
	~ y = 2 * x * y
	
{ x == 1.2 }
{ x / 2 > 4 }
{ y - 1 <= x * x }
->END
