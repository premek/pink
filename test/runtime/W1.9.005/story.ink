// these seeds does not need to give the same results in different implementations
// but these 2 match the current ink implementation
// We could also test if it repeatedly gives the same result
~ SEED_RANDOM(10)
{~Heads|Tails}
~ SEED_RANDOM(3)
{~Heads|Tails}

