VAR money = 120 
- (bet_opts)
Money: {money}
    +   [choice count: {CHOICE_COUNT()}] ->END
    +   [ Bet 50 ]
        ~ money -=  50
    +   [choice count: {CHOICE_COUNT()}]
    +   {money >= 100} [ Bet 100   ] 
        ~ money -= 100
    +   [choice count: {CHOICE_COUNT()}]

- ->bet_opts
