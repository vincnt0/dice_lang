%{

#include <math.h>
#include <stdlib.h>
#include <stdio.h>

int yyparse(void);
int yyerror(char* errmsg);
int yylex();

typedef enum { false, true } bool;

/**
*   Keeps track of active distributions.
*   A warning is displayed if a distribution remains after the program is done
*   (indicates a memory leak).
*/
int active_distribution_count;

/**
*   Prints the Result in a clean format. 
*/
double printResult(double result);

/**
*   Represents a distribution of any dice or combination of dice.
*
*   The member "distribution" is a dynamic array, mapping each possible value to the
*   probability that the distribution resolves to that value when rolled.
*   For Example: A Distribution representing "1d6" would contain a array with size 6
*   and 0.1666... in each cell.
*   (NOTE:  The probabilities might be weighted, to get the real probability (summing to 1)
*           you have to divide all values by the sum of all values.)
*
*   The member "constant" is a constant value added to the total value when resolved.
*   With this member, the distribution can represent a single number by setting 
*   the size and distribution to 0.
*/
typedef struct Distribution
{
    double constant;

    double* distribution;
    int size;
} Distribution;

/**
*   Creates a new distribution on the heap with the given size and constant.
*   Initializes all possible values with initVal. 
*/
Distribution * createDistribution(int size, double initVal, double constant);

/**
*   Deletes a distribution that was allocated on the heap.
*   All Distributions created by createDistribution or any of the functions
*   returning a Distribution Pointer should be deleted with this function.
*/
void deleteDistribution(Distribution * dist);

/**
*   Indicates wheather the distribution has an uncertain part.
*   (True if distribution array is being used, so if size > 0;
*   false if distribution represents a constant value.)
*/
bool isUncertain(Distribution * dist);
/**
*   Returns the maximal possible value the distribution could resolve to.
*   (Effectively equals size + constant) 
*/
double getMax(Distribution * dist);
/**
*   Returns the sum of all weights of the distribution.
*   (usually 1 unless the array is weighted).
*/
double getTotalWeight(Distribution * dist);

/**
*   Prints the distribution in a nice format.
*/
void print(Distribution * dist);

/**
*   Resolves the final distribution before displaying the resulting double.
*   (Rolls the distribution if uncertain, returns the constant otherwise)
*/
double resolve(Distribution* dist);

/**
*   Adds two Distributions, creating a new distribution.
*   (e.g. add(1d6, 1d6) := 1d6+1d6 = 2d6)
*/
Distribution* add(Distribution* d1, Distribution* d2);

/**
*   Multiplies two Distributions, creating a new distribution.
*   (e.g. times(1d6, 1d6) := 1d6 * 1d6)
*/
Distribution* times(Distribution* d1, Distribution* d2);

/**
*   Applies the dice operator to two Distributions, creating a new distribution.
*   The default case is with two constants, generating a distribution for a given dice:
*   dice(1, 6) := 1d6
*   
*   If one of the two arguments are uncertain distributions, rolls them first to get
*   a constant value and use that to generate the new distribution.
*   dice(1d6, 1d8) := 4d7 (could equal 1d1, 1d2, ..., 1d8, 2d1, ..., 6d8)
*   
*   NOTE: This could be improved, so that the resulting probability distributions represent the probability
*   of the combined expression. This requires some more complex algorithms however.
*/
Distribution* dice(Distribution* d1, Distribution* d2);

/**
*   Returns the average of the distribution as a constant inside a new distribution.
*/
Distribution* avg(Distribution* d);

/**
*   Rolls the distribution (generates a random value using the stored probabilities for that value)
*   and returns the rolled value as a constant inside a new distribution.
*/
Distribution* roll(Distribution* d);

/**
*   Recursive helper function for rolling a distribution.
*/
int divideAndRoll(double* prob, int start_index, int end_index, double sectionWeight);

/**
*   Returns the probability that the value of the second distribution resolves to the constant 
*   of the first distribution. 
*   If the first distribution is uncertain, rolls it to reduce it to a constant value.
*   (e.g. prob(1d6, 1d8) would roll 1d6 to get 4 and return the probability that 1d8 rolls 4).
*/
Distribution* prob(Distribution* d1, Distribution* d2);


%}


%union {
  double f;
  int i;
  struct Distribution * d;
}

%token INTEGER DOUBLE
%token ROLL AVG PROB SEPERATOR
%token PLUS TIMES DICE
%token BRACKET_OPEN BRACKET_CLOSE EOL

%type <f> DOUBLE line
%type <i> INTEGER

%type <d> expr mult dice term function

%start syntax

%%

syntax: syntax line EOL | line EOL;

line: 
  expr {
    double result = resolve($1); 
    $$ = result; 
    deleteDistribution($1);

    printResult(result);
  }
;

expr: 
  expr PLUS mult {
    $$ = add($1, $3); 
    deleteDistribution($1); 
    deleteDistribution($3);
  }
| mult
;

mult:
  mult TIMES dice {
    $$ = times($1, $3); 
    deleteDistribution($1); 
    deleteDistribution($3);
  }
| dice
;

dice:
  dice DICE dice {
    $$ = dice($1, $3); 
    deleteDistribution($1); 
    deleteDistribution($3);
  }
| DICE dice {
    Distribution* d1 = createDistribution(0, 0, 1); 
    $$ = dice(d1, $2); 
    deleteDistribution(d1);
    deleteDistribution($2);
  }
| term
;

term:
  INTEGER {$$ = createDistribution(0, 0, $1);}
| DOUBLE {$$ = createDistribution(0, 0, $1);}
| BRACKET_OPEN expr BRACKET_CLOSE {$$ = $2;}
| function
;

function:
  ROLL BRACKET_OPEN expr BRACKET_CLOSE {$$ = roll($3); deleteDistribution($3);}
| AVG BRACKET_OPEN expr BRACKET_CLOSE {$$ = avg($3); deleteDistribution($3);}
| PROB BRACKET_OPEN expr SEPERATOR expr BRACKET_CLOSE {
    $$ = prob($3, $5); 
    deleteDistribution($3); 
    deleteDistribution($5);
  }
;

%%

int active_distribution_count = 0;


double printResult(double result){
  printf("--------------------\n"); 
  printf("RESULT: %f\n", result); 
  if(active_distribution_count > 0x0) printf("WARNING: Leaking distributions: %d\n", active_distribution_count);
  printf("--------------------\n"); 
  printf("Enter new Expression:\n"); 
}

Distribution * createDistribution(int size, double initVal, double constant){
  Distribution * newDist = (Distribution *) malloc(sizeof(Distribution));
  //printf("New Distribution [%ld]: Size: %d, InitVal: %f, Constant: %f\n", (long)newDist, size, initVal, constant);
  newDist->size = size;
  newDist->constant = constant;
  if (size > 0x0){
    newDist->distribution = (double*) malloc(sizeof(double) * size);
    for(int i = 0x0; i < size; ++i){
      newDist->distribution[i] = initVal;
      //printf("creating: %d: %f\n", i, newDist->distribution[i]);
    }
  }else{
    newDist->distribution = NULL;
  }
  //print(newDist);
  active_distribution_count++;
  return newDist;
}


void deleteDistribution(Distribution * dist){
  //printf("deleting %ld\n", (long)dist);
  if(dist->distribution != 0){
    free(dist->distribution);
  }
  free(dist);
  active_distribution_count--;
  //printf("Remaining active distributions: %d\n", active_distribution_count);
}


bool isUncertain(Distribution * dist){
  return dist->size > 0x0;
}


double getMax(Distribution * dist){
  return dist->size + dist->constant;
}


double getTotalWeight(Distribution * dist){
  double totalWeight = 0;
  for(int i = 0; i < dist->size; i++){
    totalWeight += dist->distribution[i];
  }
  return totalWeight;
}


void print(Distribution * dist){
  printf("----- PRINTING %ld -----\n", (long)dist);
  if(isUncertain(dist)){
    printf("Distribution: \n");
    double totalWeight = getTotalWeight(dist);
    for(int i = 0; i < dist->size; ++i){
      printf("%i: %.80f\n", (int)(i + dist->constant + 1), dist->distribution[i], totalWeight == 0 ? 0 : (dist->distribution[i] / totalWeight));
    }
  }else{
    printf("Constant: %f\n", dist->constant);
  }
  printf("--------------------\n");
}



double resolve(Distribution * d){
  ///printf("resolving... \n");
  print(d);
  double result = d->constant;
  if(isUncertain(d)){
    //print(d);
    Distribution * dn = roll(d);
    result = dn->constant;
    deleteDistribution(dn);
  }
  return result;
}


Distribution * add(Distribution * d1, Distribution * d2){
  ///printf("adding... \n");
  Distribution * d3 = createDistribution(d1->size + d2->size, 0x0, d1->constant + d2->constant);
  double weight1 = getTotalWeight(d1);
  double weight2 = getTotalWeight(d2);
  if(isUncertain(d1) && isUncertain(d2)){
    for(int i = 0x0; i < d1->size; ++i){
      for(int j = 0x0; j < d2->size; ++j){
        int index = i + j + 0x1; // (i+1) + (j+1) - 1 wegen Indizierung
        d3->distribution[index] += d1->distribution[i]/weight1 * d2->distribution[j]/weight2;
      }
    }
  }else if(isUncertain(d1)){
    for(int i = 0x0; i < d1->size; ++i){
      d3->distribution[i] = d1->distribution[i];
    }
  }else if(isUncertain(d2)){
    for(int i = 0x0; i < d2->size; ++i){
      d3->distribution[i] = d2->distribution[i];
    }
  }
  
  return d3;
}


Distribution* times(Distribution* d1, Distribution* d2){
  ///printf("multiplying... \n");
  if(!isUncertain(d1) && !isUncertain(d2)){
    return createDistribution(0x0, 0x0, d1->constant * d2->constant);
  }else{
    Distribution * d3 = createDistribution(getMax(d1) * getMax(d2), 0x0, 0x0);
    double weight1, weight2; 

    if(isUncertain(d1) && isUncertain(d2)){
      weight1 = getTotalWeight(d1);
      weight2 = getTotalWeight(d2);
      for(int i = 0; i < d1->size; ++i){
        for(int j = 0; j < d2->size; ++j){
          int value = (i + ((int)d1->constant) + 1) * (j + ((int)d2->constant) + 1);
          d3->distribution[(int)(value - 1)] += d1->distribution[i]/weight1 * d2->distribution[j]/weight2;
        }
      }
    }else if(isUncertain(d1)){
      weight1 = getTotalWeight(d1);
      for(int i = 0x0; i < d1->size; ++i){
        d3->distribution[(int)(((i + d1->constant) + 1)*d2->constant) - 1] = d1->distribution[i]/weight1;
      }
    }else if(isUncertain(d2)){
      weight2 = getTotalWeight(d2);
      for(int i = 0x0; i < d2->size; ++i){
        d3->distribution[(int)(((i + d2->constant) + 1)*d1->constant) - 1] = d2->distribution[i]/weight2;
      }
    }
    return d3;
  }
}


Distribution* dice(Distribution* d1, Distribution* d2){
  //printf("dice operator, d1: (size: %d, const: %f), d2: (size: %d, const: %f)\n", d1->size, d1->constant, d2->size, d2->constant);
  Distribution * d3, * d_temp, * d3_temp, * d_add;
  int const_1 = 0;
  int const_2 = 0;

  if(isUncertain(d1)){
    d_temp = roll(d1);
    const_1 = d_temp->constant;
    deleteDistribution(d_temp);
  }else{
    const_1 = d1->constant;
  }

  if(isUncertain(d2)){
    d_temp = roll(d2);
    const_2 = d_temp->constant;
    deleteDistribution(d_temp);
  }else{
    const_2 = d2->constant;
  }

  if(const_1 == 0 | const_2 == 0) return createDistribution(0, 0, 0);
  d3 = createDistribution(const_2, 0x1, 0x0);
  d_add = createDistribution(const_2, 1, 0);
  for(int i = 1; i < const_1; i++){
    d3_temp = add(d3, d_add);
    deleteDistribution(d3);
    d3 = d3_temp;
  }
  deleteDistribution(d_add);
  //print(d3);
  return d3;
}


Distribution* avg(Distribution* d){
  ///printf("averaging... \n");
  if(!isUncertain(d)) return createDistribution(0, 0, d->constant);
  double sum = 0;
  double totalWeight = 0;
  for(int i = 0x0; i < d->size; i++){
    sum += d->distribution[i] * (i + d->constant);
    totalWeight += d->distribution[i];
  }
  return createDistribution(0, 0, sum / totalWeight);
}


Distribution* roll(Distribution* d) {
  ///printf("rolling... \n");
  double result = d->constant;
  if(isUncertain(d)){
    double totalWeight = getTotalWeight(d);
    result += 1 + divideAndRoll(d->distribution, 0, d->size-1, totalWeight);
  }
  return createDistribution(0, 0, result);
}

/*
*   The c rand() function can only generate values between 0 and RAND_MAX (the integer limit).
*   because of that, probabilities smaller than 1/RAND_MAX could never be represented.
*
*   Solution:
*   I divide up the array of probabilities recursively, grouping it into sections which have
*   a combined probability of ~50% of the total array probability.
*   
*   prob: complete array of probabilities
*   start_index: starting index of the section of this iteration
*   end_index: ending index (inclusive) of the section
*   sectionWeight: 
*   
*/
int divideAndRoll(double* prob, int start_index, int end_index, double sectionWeight){
  //printf("start_index: %d, end_index: %d\n", start_index, end_index);
  double weight_section1 = 0;
  double weight_section2 = 0;
  int divider = -1;

  if(start_index == end_index) return start_index;

  /*
    Divide the array into sections [start_index, divider] and [divider+1, end_index].
    Calculate the partial weights of these subsections
  */
  for(int i = start_index; i <= end_index; i++){
    if(divider == -1){
      weight_section1 += prob[i];
      if(weight_section1 > 0.5 * sectionWeight){
        divider = i;
      }
    }else{
      weight_section2 += prob[i];
    }
  }

  //Proportional probabilites
  double prop_prob_section1, prop_prob_section2;

  /* Edge Case: if the first section needs all elements summed up to reach the threshhold
  *  (when the last element on its own has > 50% of the total probability)
  *  -> move last element to second section
  */
  if(weight_section2 == 0){
    weight_section1 -= prob[divider];
    weight_section2 += prob[divider];
    divider -= 1;
  }

  if(start_index == divider){
    start_index++;
  }else if(end_index == divider){
    end_index--;
  }

  prop_prob_section1 = weight_section1 / sectionWeight;
  int rand_part1 = (int) RAND_MAX * prop_prob_section1;

  if(rand() <= rand_part1){
    return divideAndRoll(prob, start_index, divider, weight_section1);
  }else{
    return divideAndRoll(prob, divider+0x1, end_index, weight_section2);
  }
}


Distribution* prob(Distribution* d1, Distribution* d2){
  //printf("prob\n");
  double probability = 0;
  double const_1 = 0;
  if(isUncertain(d1)){
    //if d1 is a dice, roll it first
    Distribution * d_temp = roll(d1);
    const_1 = d1->constant;
    deleteDistribution(d_temp);
  }else{
    //if d1 is a constant
    const_1 = d1->constant;
  }

  if(isUncertain(d2)){
    if(const_1 < getMax(d2)){
      probability = d2->distribution[(int)(const_1 - d2->constant)];
      probability /= getTotalWeight(d2);
    }
  }else {
    if(const_1 == d2->constant){
      probability = 1;
    }
  }
  
  return createDistribution(0, 0, probability);
}

