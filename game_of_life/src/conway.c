#include <stdbool.h>
#include <stdio.h>
#include <assert.h>

#define IMHT 16
#define IMWD 16

/*
program that will take in a rectangular slice of conways and process it
assuming the top and bottom rows are 'ghost rows' and the screen loops
*/

//returns x mod y
int mod(int x, int y){
    return (x+y)%y;
}


//ARRAY is specified as [y][x]
//Takes in conway with ghost rows and returns without
void conway(char out[IMHT][IMWD] , char in[IMHT+2][IMWD]){
    for (int i = 1; i < IMHT+1; i++)
    {
        for (int j = 0; j < IMWD; j++)
        {
            char neighbours = in[i-1][mod(j-1,IMWD)] + in[i-1][j] + in[i-1][mod(j+1,IMWD)] 
                            + in[i][mod(j-1,IMWD)]                + in[i][mod(j+1,IMWD)]
                            + in[i+1][mod(j-1,IMWD)] + in[i+1][j] + in[i+1][mod(j+1,IMWD)];
            if ((in[i][j] == 1 && (neighbours < 2 || neighbours > 3)) || (in[i][j] == 0 && neighbours != 3))
            {
                out[i-1][j] = 0;
            }
            else
            {
                out[i-1][j] = 1;
            }
        }
    }
}

void test_conway(){
    assert(mod(-1,10) == 9);
    assert(mod(1,2) == 1);
    assert(mod(20,2) == 0);
    printf("Passed mod tests\n");
    char in[IMHT+2][IMWD] = {};
    char out[IMHT][IMWD] = {};
    char result[IMHT][IMWD] = {};
    for (int i = 0; i < IMHT +2; i++){
        for (int j = 0; j < IMWD; j++){
            assert(in[i][j] == 0);
        }
    }
    printf("Passed initialisation test\n");
    in[1][1] = 1;
    in[2][2] = 1;
    in[3][0] = 1;
    in[3][1] = 1;
    in[3][2] = 1;
    out[1][0] = 1;
    out[1][2] = 1;
    out[2][1] = 1;
    out[2][2] = 1;
    out[3][1] = 1;
    conway(result,in);
    for (int i = 0; i < IMHT; i++){
        for (int j = 0; j < IMWD; j++){
            assert(result[i][j] == out[i][j]);
        }
    }
    printf("Passed conway test\n");
    
}
