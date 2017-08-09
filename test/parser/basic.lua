return {
ink=[[
Hello, world!
Hello?
"What do you make of this?" she asked.
"I couldn't possibly comment," I replied.
we <> 
hurr ied-> to_savile_row 

  === to_savile_row ===

to Savile Row
 =st
stiiii

=st2
222stiiii ->END
]],
expected= {
    {"para", "Hello, world!"},
    {"para", "Hello?"},
    {"para", '"What do you make of this?" she asked.'},
    {"para", "\"I couldn't possibly comment,\" I replied."},
    {"para", "we "},
    {"glue"},
    {"para", "hurr ied"},
    {"divert", "to_savile_row"},
    {"knot", "to_savile_row"},
    {"para", "to Savile Row"},
    {"stitch", "st"},
    {"para", "stiiii"},
    {"stitch", "st2"},
    {"para", "222stiiii "},
    {"end"}
}}
