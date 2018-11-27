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
      c_out <: line[ x ];
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

// right now this is broken, distributor does not send the rows in the correct order
// but it SHOULD work
void conway_worker(chanend work_in, chanend work_out) {
    uchar cells[WORKER_ROWS + 2][IMWD];
    // turns out the chan :> arr works but the IDE complains
    for (int y = 0; y < WORKER_ROWS + 2; y++) {
        for (int x = 0; x < IMWD; x++) {
            work_in :> cells[y][x];
            // for now let's just turn 255 into 1
            cells[y][x] &= 0x01;
        }
    }
    for (int y = 1; y < WORKER_ROWS + 1; y++) {
        for (int x = 0; x < IMWD; x++) {
            // neighbour cells coords
            int u = y - 1,
                d = y + 1,
                l = mod(x - 1, IMWD),
                r = mod(x + 1, IMWD);
            char neighbours = cells[u][l] + cells[u][x] + cells[u][r]
                            + cells[y][l]               + cells[y][r]
                            + cells[d][l] + cells[d][x] + cells[d][r];
            uchar next = next_cell(neighbours, cells[y][x]) * 255;
            work_out <: next;
        }
    }
}

//Later add generality using the number of workers
void collector(chanend c_out, chanend work_out[]){
    uchar val;
    for (int y = 0; y < IMHT/2; y++){
        for (int x = 0; x < IMWD; x++){
            work_out[0] :> val;
            c_out <: val;
        }
    }
    
    for (int y = 0; y < IMHT/2; y++){
        for (int x = 0; x < IMWD; x++){
            work_out[1] :> val;
            c_out <: val;
        }
    }
}

//The worker will recieve the cells it works on plus a 'ghost row' at the top and bottom and 
//a ghost collumn on the left and right. The height must take this into account but modular arithmetic 
//is used for the width so the width shouldn't
void worker(chanend work_in, chanend work_out, int height, int width){
    uchar vals[10][16];
    uchar val;
    for (int y = 0; y < height; y++){
        for(int x = 0; x < width; x++ ){
            work_in :> val;
            vals[y][x] = val;
        }
    }
    for (int y = 0; y < height-2; y++){
            for(int x = 0; x < width; x++ ){
                    work_out <:(uchar)( vals[y][x] ^ 0xFF );
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
void distributor(chanend c_in, chanend fromAcc,chanend work_in[])
{
  uchar val;
  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for Board Tilt...\n" );
  fromAcc :> int value;

  //Read in and do something with your image values..
  //This just inverts every pixel, but you should
  //change the image according to the "Game of Life"
 printf( "Processing...\n" );
   for( int y = 0; y < IMHT; y++ ) {   //go through all lines
        for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
          c_in :> val;
          
          //Conditionally send work to channels including ghost rows
          if (y <= (IMHT/2) || y == IMHT - 1){
              work_in[0] <: val;
          }
          if (y >= (IMHT/2) || y == 0){
              
              work_in[1] <: val;
          }
          
        }
      }
  printf( "\nOne processing round completed...\n" );
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend c_in)
{
  int res;
  uchar line[ IMWD ];

  //Open PGM file
  printf( "DataOutStream: Start...\n" );
  res = _openoutpgm( outfname, IMWD, IMHT );
  if( res ) {
    printf( "DataOutStream: Error opening %s\n.", outfname );
    return;
  }

  //Compile each line of the image and write the image line-by-line
  for( int y = 0; y < IMHT; y++ ) {
    for( int x = 0; x < IMWD; x++ ) {
      c_in :> line[ x ];
    }
    _writeoutline( line, IMWD );
    printf( "DataOutStream: Line written...\n" );
  }

  //Close the PGM image
  _closeoutpgm();
  printf( "DataOutStream: Done...\n" );
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
chan c_inIO, c_outIO, c_control, work_in[2],work_out[2];    //extend your channel definitions here

par {
    i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    orientation(i2c[0],c_control);        //client thread reading orientation data
    DataInStream(infname, c_inIO);          //thread to read in a PGM image
    DataOutStream(outfname, c_outIO);       //thread to write out a PGM image
    distributor(c_inIO, c_control,work_in);//thread to coordinate work on image
//    par (int i = 0; i < 2; i++){
//        worker(work_in[i],work_out[i],(IMHT/2)+2,IMWD+2);
//    }
    
    //worker(work_in[0],work_out[0],(IMHT/2)+2,IMWD);
    //worker(work_in[1],work_out[1],(IMHT/2)+2,IMWD);
    conway_worker(work_in[0], work_out[0]);
    conway_worker(work_in[1], work_out[1]);
    collector(c_outIO, work_out);
    
  }

  return 0;
}
