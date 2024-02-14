VAR 	current_epilogue = -> everybody_dies
-> continue_or_quit

=== continue_or_quit ===
Give up now, or keep trying to save your Kingdom?
*  [Keep trying!] 	-> more_hopeless_introspection
*  [Give up] 		-> current_epilogue

=== more_hopeless_introspection
more hopeless introspection
-> continue_or_quit

=== everybody_dies
everyboy dies ->END
