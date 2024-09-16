LIST fruitBowl = (apple), (banana), (melon)
~pop_random(fruitBowl)
{LIST_COUNT(fruitBowl)}
~pop_random(fruitBowl)
{LIST_COUNT(fruitBowl)}
~pop_random(fruitBowl)
{LIST_COUNT(fruitBowl)}
~pop_random(fruitBowl)
{LIST_COUNT(fruitBowl)}

=== function pop_random(ref _list) 
    ~ temp el = LIST_RANDOM(_list) 
    ~ _list -= el
    ~ return el 
    
