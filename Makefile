all: src/calc.l src/calc.y
		make clear
		make yacc
		make lex
		make compile

clear:
		rm -r build
		mkdir build
yacc: src/calc.y
		yacc src/calc.y -d -b build/y
lex: src/calc.l
		lex -o build/lex.yy.c src/calc.l
compile: build/lex.yy.c build/y.tab.c
		gcc build/lex.yy.c build/y.tab.c -o calc.exe

test:
		make all
		./calc.exe