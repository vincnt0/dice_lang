# DICE LANG

This Repository includes a YACC/LEX compiler for a simple dice calculator.
A testfile with some testing data is also included.

# Features:
- Floating point or integer numbers
- Standard calculator operators: + , *
- Standard brackets: (, )
- Define dice structures with the "d" operator (2d6 represents 2 six-sided dice)
- Special dice functions:
	- roll(dice): generates a random number from the given dice structures
	- avg(dice): returns the average value of the dice structure
	- prob(number, dice): returns the probability of the given number in the dice structure
- Dice structures can be combined in any syntactically valid way
	(see testfile for examples)
	
# Usage:
- Compile using makefile (make all)
- Execute calc.exe: 
	If no argument is specified, expects input via console.
	Otherwise, takes the first input as filename of the input file, reads each line as one statement
	(e.g. ./calc.exe testfile)
- Program execution will stop when any error occurs.
- Testfile should be terminated using an "END"-Token