CONST HASTINGS = "Hastings"
CONST POIROT = "Poirot"
CONST JAPP = "Japp"

VAR current_chief_suspect = HASTINGS

-> found_japps_bloodied_glove

=== found_japps_bloodied_glove
-> review_evidence

=== review_evidence ===
	{ found_japps_bloodied_glove:
		~ current_chief_suspect = JAPP
	}
	Current Suspect: {current_chief_suspect}
	->END
