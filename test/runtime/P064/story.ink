-> test

=== go(-> return_to) ===
inside go
-> return_to

=== wrapper(-> return_to) ===
-> go(return_to)

=== test ===
before
-> wrapper(-> done)
- (done)
after
-> END
