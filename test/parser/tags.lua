return {
ink=[[
# author: Joseph Humfrey
# title: My Wonderful Ink Story

=== content 
# location: Germany
# overview: munich.ogg
# require: Train ticket

This is the line of content. # the third tag # really_monsieur.ogg
#tag
aaa
]],
expected={
    {"tag", "global", "author: Joseph Humfrey"},
    {"tag", "global", "title: My Wonderful Ink Story"},
    {"knot", "content"},
    {"tag", "above", "location: Germany"},
    {"tag", "above", "overview: munich.ogg"},
    {"tag", "above", "require: Train ticket"},
    {"para", "This is the line of content. "},
    {"tag", "end", "the third tag "},
    {"tag", "end", "really_monsieur.ogg"},
    {"tag", "above", "tag"},
    {"para", "aaa"}
}
}

