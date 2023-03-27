return {
  ink=[[
Hello?
TODO: this is a test todo-item

"What do you make of this?" she asked.

// Something unprintable...

"I couldn't possibly comment," I replied.

/*
    ... or an unlimited block of text
*/
we <> /* he
asdf
*/ hurr ied-> to_savile_row //  comm


]],
  expected= {
    {"para", "Hello?"},
    {"todo", "this is a test todo-item"},
    {"para", '"What do you make of this?" she asked.'},
    --    {"comment", "Something unprintable..."},
    {"para", "\"I couldn't possibly comment,\" I replied."},
    --    {"comment", "... or an unlimited block of text\n"},
    {"para", "we "},
    {"glue"},
    --    {"comment", "he\nasdf\n"},
    {"para", "hurr ied"},
    {"divert", "to_savile_row"},
  --    {"comment", "comm"},
  }}
