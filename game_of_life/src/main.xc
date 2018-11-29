// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define IMHT 16                  //image height
#define IMWD 16                  //image width
#define WORKERS 2
#define WORKER_ROWS (IMHT / WORKERS)
typedef unsigned char uchar;      //using uchar as shorthand

port p_scl = XS1_PORT_1E;         //interface ports to orientation
port p_sda = XS1_PORT_1F;

#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel c_out
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend c_out)
{
  int res;
  uchar line[ IMWD ];
  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error openening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel c_out
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );
    for( int x = 0; x < IMWD; x++ ) {
      c_out <: line[x];
      printf( "-%4.1d ", line[ x ] ); //show image values
    }
    printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
}

// positive modulo function
inline int mod(int x, int n) {
    return (x % n + n) % n;
}

// returns the next cell value (this could be optimized!)
uchar next_cell(int neighbours, char cell) {
    if ((cell == 1 && (neighbours < 2 || neighbours > 3)) || (cell == 0 && neighbours != 3)) {
        return 0;
    } else {
        return 1;
    }
}

//The worker will recieve the cells it works on plus a 'ghost row' at the top and bottom and
//a ghost collumn on the left and right. The height must take this into account but modular arithmetic
//is used for the width so the width shouldn't. Worker communicates directly with data out using flag
void conway_worker(chanend work_in, chanend work_out) {

    uchar cells[WORKER_ROWS + 2][IMWD];
    uchar processed[WORKER_ROWS][IMWD];
    uchar flag;

    // First time setup of cells
    for (int y = 0; y < WORKER_ROWS + 2; y++) {
        for (int x = 0; x < IMWD; x++) {
            work_in :> cells[y][x];
            // for now let's just turn 255 into 1
            cells[y][x] &= 0x01;
        }
    }
        while(1){
            for (int y = 1; y < WORKER_ROWS + 1 ; y++) {
                for (int x = 0; x < IMWD; x++) {
                    // neighbour cells coords
                    int u = y - 1,
                        d = y + 1,
                        l = mod(x - 1, IMWD),
                        r = mod(x + 1, IMWD);
                    char neighbours = cells[u][l] + cells[u][x] + cells[u][r]
                                    + cells[y][l]               + cells[y][r]
                                    + cells[d][l] + cells[d][x] + cells[d][r];
                    processed[y-1][x] = next_cell(neighbours, cells[y][x]) * 255;
                }
            }

            //Wait for flag from the distributor
            work_in :> flag;
            for (int y = 0; y < WORKER_ROWS; y++){
                for (int x = 0; x < IMWD; x++){
                    work_out <: processed[y][x];
                }
            }
            work_in <: flag;


            //send redundant rows
            for (int y = 0; y < WORKER_ROWS; y += (WORKER_ROWS -1)){
                for (int x = 0; x < IMWD; x++){
                            work_in <: processed[y][x];
                        }
            }

            //accept redundant rows
            for (int y = 0; y < WORKER_ROWS + 2; y += (WORKER_ROWS)+1){
                for (int x = 0; x < IMWD; x++){
                            work_in :> cells[y][x];
                            cells[y][x] &= 0x01;
                        }
            }
            for (int y = 1; y < WORKER_ROWS+1; y++){
                for (int x = 0; x < IMWD; x++){
                    cells[y][x] = processed[y-1][x];
                    cells[y][x] &= 0x01;
                }
             }
    }
}




/////////////////////////////////////////////////////////////////////////////////////////
//
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////
void distributor(chanend c_in, chanend fromAcc, chanend work_in[])
{
  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  fromAcc :> int value;

  //Read in and do something with your image values..
  //This just inverts every pixel, but you should
  //change the image according to the "Game of Life"
  uchar instate[IMHT][IMWD];
  uchar redundant[WORKERS*2][IMWD];
  //Contains 0,7,8,15
  uchar flag = 1;

     printf( "Processing...\n" );
       for( int y = 0; y < IMHT; y++ ) {   //go through all lines
            for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
              c_in :> instate[y][x];
            }
       }
       //Conditionally send work to channels including ghost rows
           for (int y = 0; y < (IMHT*2); y++){
               par{
                 if ((y >= (IMHT) && y<=(IMHT+(IMHT/2))) || (y == IMHT-1)){
                     for(int x = 0; x <IMWD; x++){
                         work_in[0] <: instate[y%IMHT][x];
                     }

                 }
                 if (y >= ((IMHT/2)-1) && (y <= IMHT)){
                     for(int x = 0; x <IMWD; x++){
                         work_in[1] <: instate[y%IMHT][x];
                     }
                 }
               }
           }

           while (1){
               //Transfer flag for writing to stdout
               for (int i = 0; i < WORKERS; i++){
                   work_in[i] <: flag;
                   work_in[i] :> flag;
                   //Transfer redundant rows
                   for (int y = 0; y < 2; y++){
                       for (int x = 0; x < IMWD; x++){
                           work_in[i] :> redundant[(2*i)+y][x];
                       }
                   }
               }

               for (int i = 0; i < WORKERS; i++){
                   for (signed int y = (2*i) - 1; y < (2*i)+3; y += 3){
                       for (int x = 0; x < IMWD; x++){
                           work_in[i] <: redundant[mod(y,(WORKERS*2))][x];
                       }
                   }

               }
               printf( "\nOne processing round completed...\n" );fflush(stdout);

           }

              


}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in[WORKERS])
{
  int res;
  int serving = 1;
  uchar line[ IMWD ];

  while(1){
  //Open PGM file
  printf( "DataOutStream: Start...\n" );
  res = _openoutpgm( outfname, IMWD, IMHT );
  if( res ) {
    printf( "DataOutStream: Error opening %s\n.", outfname );
    return;
  }

  //Refactor me now
  //Compile each line of the image and write the image line-by-line
  for( int y = 0; y < IMHT; y++ ) {
      for( int x = 0; x < IMWD; x++ ) {

          serving = 1;
          while (serving){

            select{
                case c_in[int j] :> line[x]:
                    serving = 0;
                    break;
            }
          }
          }

    _writeoutline( line, IMWD );
    //printf( "DataOutStream: Line written...\n" );
    for (int i = 0; i<IMWD; i++){
        printf(" %d ",line[i] & 0x01);
    }
    printf("\n");
  }

  //Close the PGM image
  _closeoutpgm();
  printf( "DataOutStream: Done...\n" );
  }
  return;
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////
void orientation( client interface i2c_master_if i2c, chanend toDist) {
  i2c_regop_res_t result;
  char status_data = 0;
  int tilted = 0;

  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }
  
  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the orientation x-axis forever
  while (1) {

    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt
    if (!tilted) {
      if (x>30) {
        tilted = 1 - tilted;
        toDist <: 1;
      }
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////
int main(void) {

i2c_master_if i2c[1];               //interface to orientation

//int workers = 2;
char infname[] = "test.pgm";     //put your input image path here
char outfname[] = "testout.pgm"; //put your output image path here
chan c_inIO, c_control, work_in[WORKERS],work_out[WORKERS];    //extend your channel definitions here

par {
    i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    orientation(i2c[0],c_control);        //client thread reading orientation data
    DataInStream(infname, c_inIO);          //thread to read in a PGM image
    DataOutStream(outfname, work_out);       //thread to write out a PGM image
    distributor(c_inIO, c_control, work_in);//thread to coordinate work on image
    conway_worker(work_in[0], work_out[0]);
    conway_worker(work_in[1], work_out[1]);
    //collector(c_outIO, work_out, "testout.pgm", filepipe );
    
  }

  return 0;
}
