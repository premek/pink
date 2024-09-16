LIST DoctorsInSurgery = (Adams), (Bernard), Cartwright, Denver, (Eamonn)

{DoctorsInSurgery ? (Adams, Bernard)}
{DoctorsInSurgery has (Adams, Bernard)}

{DoctorsInSurgery ? (Adams, Cartwright)}
{DoctorsInSurgery has (Adams, Cartwright)}

{DoctorsInSurgery has Eamonn}
{DoctorsInSurgery ? Eamonn}

{DoctorsInSurgery has Denver}
{DoctorsInSurgery ? Denver}

// true when both not present
{DoctorsInSurgery hasnt (Adams, Bernard)}
{DoctorsInSurgery !? (Adams, Bernard)}

{DoctorsInSurgery hasnt (Adams, Cartwright)}
{DoctorsInSurgery !? (Adams, Cartwright)}
