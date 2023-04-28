// The first stitch is the default

*	[Travel in first class]
	"First class, Monsieur. Where else?"
	-> the_orient_express

*	[Travel in second class]
	-> the_orient_express.in_second_class

=== the_orient_express ===

= in_first_class
	first
	-> END
= in_second_class
	second
	-> END
