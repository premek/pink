2+2={2+2}
5-3={5-3}
7/2={7/2}
2*3={2*3}
9%5={9%5}

~ temp i = 7
neg 7={-i}

~ temp f = 7.5
neg 7.5={-f}

1 == 1 = {1 == 1}

1>2 = {1>2}
2>1 = {2>1}
2>2 = {2>2}

1<2 = {1<2}
2<1 = {2<1}
2<2 = {2<2}

1>=2 = {1>=2}
2>=1 = {2>=1}
2>=2 = {2>=2}

1<=2 = {1<=2}
2<=1 = {2<=1}
2<=2 = {2<=2}

1 != 1 = {1!=1}
1 != 0 = {1!=0}

~ temp not_one = !1
~ temp not_zero = !0
not 1 = {not_one}
not 0 = {not_zero}
/*
*/

1 and 0 = {1 && 0}

/*
use a varible to work around special meaning of
"|" in {} expressions
*/
~ temp x = 0 || 1
1 or 0 = {x}

MIN(3, 2) = {MIN(3, 2)}
MAX(3, 2) = {MAX(3, 2)}
