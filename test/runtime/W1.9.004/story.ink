*nice->nice_welcome
*nasty->nasty_welcome

==nice_welcome
:) ->next
==nasty_welcome
:( ->next
==next
* {came_from(->  nice_welcome)} 'I'm happy to be here!' ->END
* {came_from(->  nasty_welcome)} 'Let's keep this quick.' ->END

=== function came_from(-> x)
	~ return TURNS_SINCE(x) == 0
	
