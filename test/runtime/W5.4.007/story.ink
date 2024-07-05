LIST DoctorsInSurgery = (Adams), Bernard, (Cartwright), Denver, Eamonn

~ DoctorsInSurgery = DoctorsInSurgery + Adams
~ DoctorsInSurgery += Adams  // this is the same as the above
~ DoctorsInSurgery -= Eamonn
~ DoctorsInSurgery += (Eamonn, Denver)
~ DoctorsInSurgery -= (Adams, Eamonn, Denver)

{DoctorsInSurgery}
