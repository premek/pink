return {
ink=[[
INCLUDE dir/file.ink
text! text, text
#  tag
* opt // comm
* opt2
** * nested
-gather
- - - nested gather
/*
c
comment*/
TODO: test
=== knot2
== knot_name ==
para<>
gluedpara
=stitch
->knot_name
#t
	* * 	'Ah[.'],' I replied, uncertain what I thought.
== the_orient_express =
=st
]],
expected= {
    {column=1, line=1, text="INCLUDE", type="include"},
    {column=9, line=1, text="dir/file.ink", type="text"},
    {column=1, line=2, text="text! text, text", type="text"},
    {column=1, line=3, text="#", type="tag"},
    {column=4, line=3, text="tag", type="text"},
    {column=1, line=4, text="*", type="option"},
    {column=3, line=4, text="opt ", type="text"},
    {column=1, line=5, text="*", type="option"},
    {column=3, line=5, text="opt2", type="text"},
    {column=1, line=6, text="*", type="option"},
    {column=2, line=6, text="*", type="option"},
    {column=4, line=6, text="*", type="option"},
    {column=6, line=6, text="nested", type="text"},
    {column=1, line=7, text="-", type="gather"},
    {column=2, line=7, text="gather", type="text"},
    {column=1, line=8, text="-", type="gather"},
    {column=3, line=8, text="-", type="gather"},
    {column=5, line=8, text="-", type="gather"},
    {column=7, line=8, text="nested gather", type="text"},
    {column=1, line=12, text="TODO:", type="todo"},
    {column=7, line=12, text="test", type="text"},
    {column=1, line=13, text="===", type="knot"},
    {column=5, line=13, text="knot2", type="text"},
    {column=1, line=14, text="==", type="knot"},
    {column=4, line=14, text="knot_name ", type="text"},
    {column=14, line=14, text="==", type="knot"},
    {column=1, line=15, text="para", type="text"},
    {column=5, line=15, text="<>", type="glue"},
    {column=1, line=16, text="gluedpara", type="text"},
    {column=1, line=17, text="=", type="stitch"},
    {column=2, line=17, text="stitch", type="text"},
    {column=1, line=18, text="->", type="divert"},
    {column=3, line=18, text="knot_name", type="text"},
    {column=1, line=19, text="#", type="tag"},
    {column=2, line=19, text="t", type="text"},
    {column=2, line=20, text="*", type="option"},
    {column=4, line=20, text="*", type="option"},
    {column=7, line=20, text="'Ah", type="text"},
    {column=10, line=20, text="[", type="squareLeft"},
    {column=11, line=20, text=".'", type="text"},
    {column=13, line=20, text="]", type="squareRight"},
    {
        column=14,
        line=20,
        text=",' I replied, uncertain what I thought.",
        type="text"
    },
    {column=1, line=21, text="", type="eof"}
}}
