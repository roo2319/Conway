#include <stdio.h>
#include <assert.h>
#include <stdbool.h>

//Turns a list of 32 chars into a single 32bit int
int pack(char chars[32])
{
    int out = 0;
    
    for(int i = 0; i < 32; i++){
        out |= ((chars[i] & 255)/255) << i;
    }
    return out;    
}

void unpack(char* out,int packed)
{

    for (int i = 0; i<32; i++)
    {
        out[i] = 1<<i & packed?255:0;
    }
}

bool test()
{
    char testdata[32] = {0,255,0,255,0,0,0,0,0,0,0,255,0,0,0,0,0,255,0,0,0,0,0,255,0,0,0,0,255,0,255,0};
    char processeddata[32];
    unpack(processeddata,pack(testdata));
    for (int i; i<32; i++){
        assert(testdata[i] == processeddata[i]);
    }

    return true;
}

int main(int argc, char const *argv[])
{
    if (argc == 1){
        test();
        printf("All tests passed\n");
    }
    return 0;
}
