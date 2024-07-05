-> scene

=== function fn1()
    ~return

=== function fn2()
    ~temp a = 3

=== scene
* one
    ~ fn1()
    * * two
        ~ fn2()
        *** three
            {fn1()}text
            **** four
                ->END
