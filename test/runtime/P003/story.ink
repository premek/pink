// && and || has the same precedence
~temp x = true || false && false
{x}
~x = true or false and false
{x}
{ true or (false and false) }
{ true or false and false }
{ false and false or true}
{2 or 0}
{1 and 2}
{2.0 or true}
