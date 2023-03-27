return {
  ink=[[
        *   "Murder!"
            ** A
            * 	* A
            * * 	* B
            *** B
        *   "Suicide!"
]], expected= {

    {"option", 1, '"Murder!"', "", ""},
    {"option", 2, "A", "", ""},
    {"option", 2, "A", "", ""},
    {"option", 3, "B", "", ""},
    {"option", 3, "B", "", ""},
    {"option", 1, '"Suicide!"', "", ""}

}
}
