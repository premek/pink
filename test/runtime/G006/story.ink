/*
Test consuming leading & trailing whitespace within the function
as well as returning without an explicit return statement.
*/
{surround_foo_bar("hello")} baz

{void_return()}

=== function surround_foo_bar(x)
foo
{x}
bar

=== function void_return
should have "void" return
~ return
