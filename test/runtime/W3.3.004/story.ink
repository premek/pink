VAR x = 9
VAR y = -99

{
	- x == 0:
		~ y = 0
	- x > 0:
		~ y = x - 1
	- else:
		~ y = x + 1
}

{y}
