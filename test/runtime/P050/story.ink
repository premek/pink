// temp declared inside a gather body must remain accessible after the gather ends
- (start)
    ~ temp x = 10
- (after)
    {x}
-> END
