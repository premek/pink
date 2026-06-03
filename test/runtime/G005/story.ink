/*
The function `get` ends with a `/ev` statement.
We need to check for this as a possible return point.
*/
LIST Inventory = (none), cane, knife

Have {Inventory}
~ get(cane)
Have {Inventory}

=== function get(x)
    ~ Inventory += x
