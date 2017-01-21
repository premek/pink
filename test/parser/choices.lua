return {
ink=[[
== start ==
*   I dont know
*   "I am somewhat tired[."]," I repeated.
    "Really," he responded.
    "How deleterious."
*   "Nothing, Monsieur!"[] I replied.
    "Very good, *then."
*  I said no more
    "Ah,". "I see you"
== finale ==
]],
expected= {
    {
        "knot",
        "start",
        {
            "choice",
            {"option", "I dont know", "", ""},
            {
                "option",
                '"I am somewhat tired',
                '."',
                '," I repeated.',
                {"para", '"Really," he responded.'},
                {"para", '"How deleterious."'}
            },
            {
                "option",
                '"Nothing, Monsieur!"',
                "",
                " I replied.",
                {"para", '"Very good, *then."'}
            },
            {"option", "I said no more", "", "", {"para", '"Ah,". "I see you"'}}
        }
    },
    {"knot", "finale"}
}
}
