return {
ink=[[
=== back_in_london ===

We arrived into London at 9.45pm exactly.

*   "There is not a moment to lose!"[] I declared.
    -> hurry_outside

*   "Monsieur, let us savour this moment!"[] I declared.
    My master clouted me firmly around the head and dragged me out of the door.
    -> dragged_outside

*   [We hurried home] -> hurry_outside


=== hurry_outside ===
We hurried home to Savile Row -> as_fast_as_we_could


=== dragged_outside ===
He insisted that we hurried home to Savile Row
-> as_fast_as_we_could


=== as_fast_as_we_could ===
<> as fast as we could.
]],
expected= {
    {
        "knot",
        "back_in_london",
        {"para", "We arrived into London at 9.45pm exactly."},
        {
            "choice",
            {
                "option",
                '"There is not a moment to lose!"',
                "",
                " I declared.",
                {"divert", "hurry_outside"}
            },
            {
                "option",
                '"Monsieur, let us savour this moment!"',
                "",
                " I declared.",
                {
                    "para",
                    "My master clouted me firmly around the head and dragged me out of the door."
                },
                {"divert", "dragged_outside"}
            },
            {"option", "", "We hurried home", " ", {"divert", "hurry_outside"}}
        }
    },
    {
        "knot",
        "hurry_outside",
        {"para", "We hurried home to Savile Row "},
        {"divert", "as_fast_as_we_could"}
    },
    {
        "knot",
        "dragged_outside",
        {"para", "He insisted that we hurried home to Savile Row"},
        {"divert", "as_fast_as_we_could"}
    },
    {"knot", "as_fast_as_we_could", "glue", {"para", "as fast as we could."}}
}
}
