return {
ink=[[
*   "Monsieur, let us savour this moment!"[] I declared.
    My master clouted me firmly around the head and dragged me out of the door.  <>
    -> dragged_outside
*   [We hurried home] -> hurry_outside
=== as_fast_as_we_could ===
<> as fast as we could.

]],
expected={
    {
        "choice",
        {
            "option",
            '"Monsieur, let us savour this moment!"',
            "",
            " I declared.",
            {
                "para",
                "My master clouted me firmly around the head and dragged me out of the door.  "
            },
            "glue",
            {"divert", "dragged_outside"}
        },
        {"option", "", "We hurried home", " ", {"divert", "hurry_outside"}}
    },
    {"knot", "as_fast_as_we_could", "glue", {"para", "as fast as we could."}}  -- TODO should be space before 'as'
}
}
