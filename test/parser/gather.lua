return {
ink=[[
I looked at Monsieur Fogg
*	... and I could contain myself no longer.
	'What is the purpose of our journey, Monsieur?'
	'A wager,' he replied.
	* * 	'A wager!'[] I returned.
			He nodded.
			* * * 	'But surely that is foolishness!'
			* * *  'A most serious matter then!'
			- - - 	He nodded again.
			* * *	'But can we win?'
					'That is what we will endeavour to find out,' he answered.
			* * *	'A modest wager, I trust?'
					'Twenty thousand pounds,' he replied, quite flatly.
			* * * 	I asked nothing further of him then[.], and after a final, polite cough, he offered nothing more to me. <>
	* * 	'Ah[.'],' I replied, uncertain what I thought.
	- - 	After that, <>
*	... but I said nothing[] and <>
- we passed the day in silence.
- -> END
]], expected= {
    {"para", "I looked at Monsieur Fogg"},
    {"option", 1, "... and I could contain myself no longer.", "", ""},
    {"para", "'What is the purpose of our journey, Monsieur?'"},
    {"para", "'A wager,' he replied."},
    {"option", 2, "'A wager!'", "", " I returned."},
    {"para", "He nodded."},
    {"option", 3, "'But surely that is foolishness!'", "", ""},
    {"option", 3, "'A most serious matter then!'", "", ""},
    {"gather", 3, "He nodded again."},
    {"option", 3, "'But can we win?'", "", ""},
    {"para", "'That is what we will endeavour to find out,' he answered."},
    {"option", 3, "'A modest wager, I trust?'", "", ""},
    {"para", "'Twenty thousand pounds,' he replied, quite flatly."},
    {
        "option",
        3,
        "I asked nothing further of him then",
        ".",
        ", and after a final, polite cough, he offered nothing more to me. "
    },
    {"glue"},
    {"option", 2, "'Ah", ".'", ",' I replied, uncertain what I thought."},
    {"gather", 2, "After that, "},
    {"glue"},
    {"option", 1, "... but I said nothing", "", " and "},
    {"glue"},
    {"gather", 1, "we passed the day in silence."},
    {"gather", 2, "> END"} -- FIXME!


}
}
