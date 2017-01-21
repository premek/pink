return {
ink=[[
        *   "Murder!"
            ** A
        *   "Suicide!"
]], expected= {
    {
        "choice",
        {
            "option",
            '"Murder!"',
            "",
            "",
            {"choice", {"option", "A", "", ""}}
        },
        {"option", '"Suicide!"', "", ""}
    }
}
}
