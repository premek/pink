// temp vars in nested function calls must not clobber each other
{outer()}

=== function outer()
    ~ temp x = 1
    ~ temp inner_result = inner()
    ~ return x + inner_result

=== function inner()
    ~ temp x = 100
    ~ return x
