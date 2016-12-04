return {
ink=[[
"Well, Poirot? Murder or suicide?"
    *   "Murder"
        "And who did it?"
        * *     "Detective-Inspector Japp!"
        * *     "Captain Hastings!"
        * *     "Myself!"
    *   "Suicide"
]],
expected = {
    {"para", '"Well, Poirot? Murder or suicide?"'},
    {
        "choice",
        {
            "option",
            '"Murder"',
            "",
            "",
            {"para", '"And who did it?"'},
            {
                "choice",
                {"option", '"Detective-Inspector Japp!"', "", ""},
                {"option", '"Captain Hastings!"', "", ""},
                {"option", '"Myself!"', "", ""}
            }
        },
        {"option", '"Suicide"', "", ""}
    }
}
}
