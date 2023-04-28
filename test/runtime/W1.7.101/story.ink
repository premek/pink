//Fallback choices can be sticky too. 
-> conversation_loop
=== conversation_loop
	*	[Talk about the weather] -> chat_weather
	*	[Talk about the children] -> chat_children
	+	-> sit_in_silence_again

=== chat_weather
weather -> conversation_loop
=== chat_children
children -> conversation_loop
=== sit_in_silence_again
(silence) -> END
