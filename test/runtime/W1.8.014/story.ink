->next
==next
{met_blofeld: "I saw him. Only for a moment. His real name was {met_blofeld.learned_his_name: Franz|kept a secret}." | "I missed him. Was he particularly evil?" }

* [meet] ->met_blofeld
* [learn name] ->met_blofeld.learned_his_name
* -> END

==met_blofeld
->next
=learned_his_name
->next
