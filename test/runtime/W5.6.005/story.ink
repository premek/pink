LIST Letters = a,b,c
LIST Numbers = one, two, three

VAR mixedList = (a, three, c)

{LIST_ALL(mixedList)}   // a, one, b, two, c, three
{LIST_COUNT(mixedList)} // 3
{LIST_MIN(mixedList)}   // a
~ temp max =LIST_MAX(mixedList)   // three or c, albeit unpredictably
{max == three or max == c}

{mixedList ? (a,b) }        // false
{mixedList ^ LIST_ALL(a)}   // a, c

{ mixedList >= (one, a) }   // true
{ mixedList < (three) }     // false

{ LIST_INVERT(mixedList) }            // one, b, two
