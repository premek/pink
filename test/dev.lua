return {
ink=[[
we <> /* he
asdf
*/ hurr ied-> to_savile_row //  comm


  === to_savile_row ===

to Savile Row
 =st
stiiii

=st2
222stiiii ->END
]],
expected= {
    {"para", "we "},
    "glue",
    {"para", "hurr ied"},
    {"divert", "to_savile_row"},
    {
        "knot",
        "to_savile_row",
        {"para", "to Savile Row"},
        {"stitch", "st", {"para", "stiiii"}},
        {"stitch", "st2", {"para", "222stiiii "}, "END"}
    }
}}
