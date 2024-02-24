LIST kettleState = (cold), boiling, recently_boiled
LIST kettleState2 = (cold2), boiling2, (recently_boiled2)

{kettleState==kettleState2}
{kettleState==cold2}
{kettleState==cold}
{cold==kettleState}

{cold+1}
{cold}
{cold+cold2}
{boiling2-cold}
