-> test_gather

=== go(-> return_to) ===
inside go
-> return_to

// Case 1a: gather label directly in a knot
=== test_gather ===
test gather start
-> go(-> after)
- (after)
test gather done
-> test_stitch_label

// Case 1b: gather label inside a stitch inside a knot
=== test_stitch_label ===
= body
test stitch label start
-> go(-> done_here)
- (done_here)
test stitch label done
-> test_knot

// Case 2: knot name (globally resolvable, regression guard)
=== test_knot ===
test knot start
-> go(-> done)

=== done ===
test knot done
-> END
