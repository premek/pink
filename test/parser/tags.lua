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
    {"tag", "author: Joseph Humfrey"},
    {"tag", "title: My Wonderful Ink Story"},
    {"knot", "content"},
    {"tag", "location: Germany"},
    {"tag", "overview: munich.ogg"},
    {"tag", "require: Train ticket"},
    {"para", "This is the line of content."},
    {"tag", "the third tag"},
    {"tag", "really_monsieur.ogg"},
    {"tag", "tag"},
    {"para", "aaa"}
}
}

