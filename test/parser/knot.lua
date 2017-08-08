return {
ink=[[
=== the_orient_express ===
= in_first_class
    ...
= in_third_class
    ...
= in_the_guards_van
    ...
    ...
= missed_the_train
    ...
== the_orient_express =
======== the_orient_express ===
=stitch

]],
expected={
	{ "knot", "the_orient_express"},
	{"stitch", "in_first_class"},
	{"para", "..."},
	{"stitch", "in_third_class"}, 
	{"para", "..."},
	{"stitch", "in_the_guards_van"},
	{"para", "..."},
	{"para", "..."},
	{"stitch", "missed_the_train"},
	{"para", "..."},
	{"knot", "the_orient_express"},
	{"knot", "the_orient_express"},
	{"stitch", "stitch"}
}
}
