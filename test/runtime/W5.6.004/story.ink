LIST OnOff = on, off
LIST HotCold = cold, warm, hot

VAR kettleState = (off, cold)

{kettleState}
~ changeStateTo(kettleState, on)
~ changeStateTo(kettleState, warm)
{kettleState}


=== function changeStateTo(ref stateVariable, stateToReach)
	// remove all states of this type
	~ stateVariable -= LIST_ALL(stateToReach)
	// put back the state we want
	~ stateVariable += stateToReach
