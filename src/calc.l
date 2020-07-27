%option noyywrap
%{

//#include "../src/distribution.cc"
#include <stdio.h>
#include "../build/y.tab.h"

int yyparse(void);
int yyerror(char* errmsg);

%}

DIGIT [0-9]
NONZERO [1-9]
INTEGER ({DIGIT}|{NONZERO}{DIGIT}+)
DOUBLE ({INTEGER}"."{DIGIT}+)

%%
{INTEGER} { 
  ///printf("Integer: %s\n", yytext); 
  yylval.i = atoi(yytext);
  return INTEGER;
}

{DOUBLE} { 
  ///printf("Double: %s\n", yytext); 
  yylval.f = atof(yytext);
  return DOUBLE;
}

"roll" { 
  ///printf("Roll Function Operator: %s\n", yytext);
  return ROLL; 
}

"avg" { 
  ///printf("Average Function Operator: %s\n", yytext);
  return AVG; 
}

"prob" { 
  ///printf("Probability Function Operator: %s\n", yytext);
  return PROB; 
}

"," { 
  ///printf("Argument Seperator: %s\n", yytext); 
  return SEPERATOR;
}

"+" { 
  ///printf("Addition Operator: %s\n", yytext); 
  return PLUS; 
}

"*" { 
  ///printf("Multiplication Operator: %s\n", yytext); 
  return TIMES; 
}

"d" { 
  ///printf("Dice Operator: %s\n", yytext); 
  return DICE; 
}

"(" { 
  ///printf("Opening Bracket: %s\n", yytext); 
  return BRACKET_OPEN; 
}

")" { 
  ///printf("Closing Bracket: %s\n", yytext);
  return BRACKET_CLOSE; 
}

[\n] { 
  printf("End of Line.\n"); 
  return EOL;
}

[ \r\t]+ {
  /* Remove whitespaces and tabs */
}

"END" {
  printf("Ending Evaluation.\n");
  return 0;
}

. {
  printf("Unrecognized token: %s, Exiting!\n", yytext); /* Is there anything else? Fail on it! */ 
  return 1; 
}

%%



int yyerror(char *errmsg) {
  printf("YYERROR\n");
  printf("%s\n", errmsg);
  exit(100);
}


int main(int argc, char **argv)
{
  ++argv, --argc; // skip over program name 
  if ( argc > 0 ) {
    yyin = fopen( argv[0], "r" ); // Is the input file given?
  }else{
    yyin = stdin;
  }
  yyparse();
  return 0;
}