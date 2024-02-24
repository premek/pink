LIST volumeLevel = off, quiet, medium, loud, deafening
VAR lecturersVolume = quiet
VAR murmurersVolume = quiet

-(top)
{ lecturersVolume < deafening:
	~ lecturersVolume++

	{ lecturersVolume > murmurersVolume:
		~ murmurersVolume++
		The murmuring gets louder.
	}
}
The lecturer's voice becomes {lecturersVolume}.
The murmurer's voice becomes {murmurersVolume}.

{->top|->top|->top|}

