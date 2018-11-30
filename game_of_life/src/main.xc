// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include "i2c.h"

#define IMHT 16                  //image height
#define IMWD 16                  //image width
#define WORKERS 4
#define WORKER_ROWS (IMHT / WORKERS)
#define infname  "test.pgm"     //put your input image path here
#define outfname "testout.pgm" //put your output image path here
typedef unsigned char uchar;      //using uchar as shorthand

on tile[0]: in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0]: out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs

on tile[0]: port p_scl = XS1_PORT_1E;         //interface ports to orientation
on tile[0]: port p_sda = XS1_PORT_1F;

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
void DataInStream(char inname[], chanend c_out)
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
            if (flag == 1){
                for (int y = 0; y < WORKER_ROWS; y++){
                    for (int x = 0; x < IMWD; x++){
                        work_out <: processed[y][x];
                    }
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
void distributor(chanend c_in, chanend fromAcc, chanend work_in[], chanend fromListener, chanend distributorToVisualiser)
{
  int value = 1;
  int rounds = 0;
  int tilted = 0;

  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Waiting for SW1...\n" );
  while (value != 14)
  fromListener :> value;
  distributorToVisualiser <: 1;


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

       for (int i = 0; i < WORKERS; i++){
           for (int x = 0; x < IMWD; x++)
               work_in[i] <: instate[mod((i * WORKER_ROWS) - 1, IMHT)][x];
           for (int y = (WORKER_ROWS * i); y <= (WORKER_ROWS * (i+1)); y++){
               for (int x = 0; x < IMWD; x++)

                  work_in[i] <: instate[y % IMHT][x];
           }

       }
//       //Conditionally send work to channels including ghost rows
//           for (int y = 0; y < (IMHT*2); y++){
//               par{
//                 if ((y >= (IMHT) && y<=(IMHT+(IMHT/2))) || (y == IMHT-1)){
//                     for(int x = 0; x <IMWD; x++){
//                         work_in[0] <: instate[y%IMHT][x];
//                     }
//
//                 }
//                 if (y >= ((IMHT/2)-1) && (y <= IMHT)){
//                     for(int x = 0; x <IMWD; x++){
//                         work_in[1] <: instate[y%IMHT][x];
//                     }
//                 }
//               }
//           }

           while (1){
               select{
                   case fromListener :> int button:
                       flag = button & 0x1;
                       break;
                   default:
                       flag = 0;
                       break;

               }
               distributorToVisualiser <: (int)(flag * 2) + ((rounds+1)%2);
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
               distributorToVisualiser <: ((rounds+1)%2);

               for (int i = 0; i < WORKERS; i++){
                   for (signed int y = (2*i) - 1; y < (2*i)+3; y += 3){
                       for (int x = 0; x < IMWD; x++){
                           work_in[i] <: redundant[mod(y,(WORKERS*2))][x];
                       }
                   }

               }
               rounds++;
               distributorToVisualiser <: ((rounds+1)%2);

               printf( "\nOne processing round completed...\n" );fflush(stdout);
               fromAcc <: 1;
               fromAcc :> tilted;
               if (tilted == 1){
                   distributorToVisualiser <: ((rounds+1)%2) + 8;
                   while (tilted == 1)
                       fromAcc :> tilted;
                   distributorToVisualiser <: ((rounds+1)%2);
               }


           }

              


}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outname[], chanend c_in[WORKERS])
{
  int res;
  int serving;
  uchar line[ IMWD ];

  while(1){
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
        printf(" %d ",line[i] & 0x1);
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
  int flag;

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

  while (1) {
      toDist :> flag;
  //Probe the orientation x-axis forever
      while (1) {
        //check until new orientation data is available
        do {
          status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
        } while (!status_data & 0x08);

        //get new x-axis tilt value
        int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

        //send signal to distributor after first tilt
        tilted = x >30 ? 1:0;
        toDist <: tilted;
        if (!tilted)
            break;
        }
      }
}


//DISPLAYS an LED pattern
int showLEDs(out port p, chanend fromVisualiser) {
  int pattern; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED
  while (1) {
    fromVisualiser :> pattern;   //receive new pattern from visualiser
    p <: pattern;                //send pattern to LED port
  }
  return 0;
}

//READ BUTTONS and send button pattern to distributor
void buttonListener(in port b, chanend toDistributor) {
  int r;

  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;
    if ((r==13) || (r==14)){     // if either button is pressed
        toDistributor <: r;             // send button pattern to userAnt
    }
  }
}

void visualiser(chanend visualiserToLEDs, chanend distributorToVisualiser){
    int pattern;
    while (1) {
        distributorToVisualiser :> pattern;
        //pattern = round%2 + 8 * dangerzone + 2 * ((distance==1) || (distance==-1));
        //if ((attackerAntToDisplay>7)&&(attackerAntToDisplay<15)) pattern = 15;
        visualiserToLEDs <: pattern;
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
chan c_inIO,
     c_control,
     work_in[WORKERS],
     work_out[WORKERS],
     visualiserToLEDs,
     buttonsToDistributor,
     distributorToVisualiser;    //extend your channel definitions here

par {
    on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    on tile[0]: orientation(i2c[0],c_control);        //client thread reading orientation data
    on tile[1]: DataInStream(infname, c_inIO);          //thread to read in a PGM image
    on tile[1]: DataOutStream(outfname, work_out);       //thread to write out a PGM image
    on tile[0]: distributor(c_inIO, c_control, work_in,buttonsToDistributor,distributorToVisualiser);//thread to coordinate work on image
    par(int i = 0; i < WORKERS; i++){
        on tile[1]: conway_worker(work_in[i], work_out[i]);
    }
    //on tile[1]: conway_worker(work_in[0], work_out[0]);
    //on tile[1]: conway_worker(work_in[1], work_out[1]);
    on tile[0]: buttonListener(buttons, buttonsToDistributor);
    on tile[0]: visualiser(visualiserToLEDs,distributorToVisualiser);
    on tile[0]: showLEDs(leds,visualiserToLEDs);
    
  }

  return 0;
}
