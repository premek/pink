/*
Turn counting is still buggy. It will give a count, but doesn't always match
what Inklecate expects.
*/
Counting turns

-> start

=== start

{TURNS()}

Text doesn't increment the turn

{TURNS()}
{TURNS_SINCE(-> start)}

 * But choosing here
 * does increment

- {TURNS()}
{TURNS_SINCE(-> start)}

A default choice does not count as a turn

 * -> ending

=== ending

{TURNS()}

However a single non-default choice does

* only choice

- They lived happily ever after.

{TURNS()}

    -> END
