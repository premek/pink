return {
ink=[[
INCLUDE another.ink
    INCLUDE     dir/file.ink

hello world

INCLUDE     dir file.ink
]],
expected={
    {"include", "another.ink"},
    {"include", "dir/file.ink"},
    {"para", "hello world"},
    {"include", "dir file.ink"} -- not the best but ok
}
}
