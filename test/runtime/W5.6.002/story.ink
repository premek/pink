LIST Characters = Alfred, Batman, Robin
LIST Props = champagne_glass, newspaper

VAR currentRoomState = (Alfred, Batman, newspaper)

*	{ currentRoomState ? (Batman, Alfred) } [Talk to Alfred and Batman]
	'Say, do you two know each other?'
