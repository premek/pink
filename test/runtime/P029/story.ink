LIST DoctorsInSurgery = (Adams), Bernard, Cartwright, (Denver), Eamonn
LIST DoctorsInPub = (Franta)

VAR fastestDoctor = Bernard
VAR drunkDoctors = (Denver, Eamonn, Franta)

~temp randomFastest = LIST_RANDOM(fastestDoctor)
~temp randomInSurgery = LIST_RANDOM(DoctorsInSurgery)
~temp randomDrunk = LIST_RANDOM(drunkDoctors)

{randomInSurgery == Adams or randomInSurgery == Denver}
{randomFastest==Bernard}
{randomDrunk==Denver or randomDrunk==Eamonn or randomDrunk==Franta}
