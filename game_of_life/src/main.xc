// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include <stdint.h>
#include "pgmIO.h"
#include "i2c.h"
#define IMHT 64                //image height
#define IMWD 64              //image width
#define WORKERS 2
#define WORKER_ROWS (IMHT / WORKERS)
#define PACKED_WD (IMWD / 32)
#define infname  "test64.pgm"     //put your input image path here
#define outfname "testout64.pgm" //put your output image path here
typedef unsigned char uchar;      //using uchar as shorthand
typedef uint32_t uint32;

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

uint32 pack(uchar bits[32]) {
    uint32 packed = 0;
    for (uchar i = 0; i < 32; i++) {
        packed |= (uint32) (bits[i] >> 7) << (31 - i);
    }
    return packed;
}

void unpack(uchar result[32], uint32 packed) {
    for (uchar i = 0; i < 32; i++) {
        result[i] = ((packed >> (31 - i)) & 0x1) * 255;
    }
}

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
    for( int x = 0; x < PACKED_WD; x++ ) {
        uint32 packed = pack(&line[x * 32]);
        c_out <: packed;
    }
    //printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
}

// positive modulo function
int mod(int x, int n) {
    return (x % n + n) % n;
}

// returns the next cell value (this could be optimized!)
uint32 next_cell(int neighbours, char cell) {
    if ((cell == 1 && (neighbours < 2 || neighbours > 3)) || (cell == 0 && neighbours != 3)) {
        return 0;
    } else {
        return 1;
    }
}


//The worker will recieve the cells it works on plus a 'ghost row' at the top and bottom and
//a ghost collumn on the left and right. The height must take this into account but modular arithmetic
//is used for the width so the width shouldn't. Worker communicates directly with data out using flag
void conway_worker(chanend work_in, chanend above, chanend below, uchar sendFirst) {
    uint32 cells[WORKER_ROWS + 2][PACKED_WD];
    // initialise main cells from dist
    for (short y = 1; y < WORKER_ROWS + 1; y++) {
        for (short x = 0; x < PACKED_WD; x++) {
            work_in :> cells[y][x];
        }
    }
    while(1){
        // send and receive 'ghost rows'
        for (short x = 0; x < PACKED_WD; x++) {
            // if it works... (pls optimize}
            if (sendFirst) {
                above <: cells[1][x];
                above :> cells[0][x];
                below <: cells[WORKER_ROWS][x];
                below :> cells[WORKER_ROWS + 1][x];
            } else {
                below :> cells[WORKER_ROWS + 1][x];
                below <: cells[WORKER_ROWS][x];
                above :> cells[0][x];
                above <: cells[1][x];
            }
        }
        uint32 alive_cells = 0;
        for (short y = 1; y < WORKER_ROWS + 1 ; y++) {
            uint32 processed[PACKED_WD] = {0};
            for (short x = 0; x < PACKED_WD; x++) {
                uint32 u_row = y - 1, d_row = y + 1;
                for (uchar i = 0; i < 32; i++) {
                    // l, c, r represent the shifts to get the neighbouring cell bits
                    // l_pack and r_pack are the left and right packed bits
                    // they're usually the same unless the current bit is on the edge of the pack
                    uchar l = mod(-i, 32), c = 31 - i, r = i == 31 ? 31 : 30 - i;
                    uchar l_pack = i == 0 ? mod(x - 1, PACKED_WD) : x;
                    uchar r_pack = i == 31 ? mod(x + 1, PACKED_WD) : x;
                    uchar neighbours = ((cells[u_row][l_pack] >> l) & 0x1) + ((cells[u_row][x] >> c) & 0x1) + ((cells[u_row][r_pack] >> r) & 0x1)
                                     + ((cells[y][l_pack]     >> l) & 0x1) +                                + ((cells[y][r_pack]     >> r) & 0x1)
                                     + ((cells[d_row][l_pack] >> l) & 0x1) + ((cells[d_row][x] >> c) & 0x1) + ((cells[d_row][r_pack] >> r) & 0x1);
                    uchar next = next_cell(neighbours, (cells[y][x] >> c) & 0x1);
                    alive_cells += next;
                    processed[x] |= (next << (31 - i));
                }
            }
            for (short i = 0; i < PACKED_WD; i++) {
                cells[y - 1][i] = processed[i];
            }
        }

        // wait for export flag and send total cells alive
        uchar export;
        work_in :> export;
        work_in <: alive_cells;
        if (export == 1){
            for (short y = 0; y < WORKER_ROWS; y++){
                for (short x = 0; x < PACKED_WD; x++){
                    work_in <: cells[y][x];
                }
            }
        }

        // shift processed rows downwards, ready for ghost rows
        for (short y = WORKER_ROWS; y > 0; y--) {
            for (short x = 0; x < PACKED_WD; x++) {
                cells[y][x] = cells[y - 1][x];
            }
        }
    }
}


void distributor(chanend c_in, chanend fromAcc, chanend work_in[], chanend fromListener, chanend distributorToVisualiser, chanend toDataOut, chanend toTimer) {
    int value = 1;
    int rounds = 0;
    int tilted = 0;

    // starting up and wait for tilting of the xCore-200 Explorer
    printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
    printf( "Waiting for SW1...\n" );
    while (value != 14)
        fromListener :> value;
    distributorToVisualiser <: 1;

    uint32 total_cells;
    uchar flag = 0;

    // send worker packets
    for (int y = 0; y < IMHT; y++) {
        for (int x = 0; x < PACKED_WD; x++) {
            uint32 current_packet;
            c_in :> current_packet;
            work_in[(uint32) y / WORKER_ROWS] <: current_packet;
        }
    }

    toTimer <: 1;
    while (1) {
        select {
            case fromListener :> int button:
                flag = button & 0x1;
                break;
            default:
                flag = 0;
                break;
        }
        if (flag) {
            toDataOut <: 1;
        }
        distributorToVisualiser <: (int)(flag * 2) + ((rounds+1)%2);
        //Transfer flag for writing to stdout
        total_cells = 0;
        for (int i = 0; i < WORKERS; i++){
            work_in[i] <: flag;
            uint32 cells;
            work_in[i] :> cells;
            total_cells += cells;

            if (flag) {
                for (int y = 0; y < WORKER_ROWS; y++){
                    for (int x = 0; x < PACKED_WD; x++){
                        uint32 current_packet;
                        work_in[i] :> current_packet;
                        toDataOut <: current_packet;
                    }
                }
            }
        }
        distributorToVisualiser <: ((rounds+1)%2);

        rounds++;
        distributorToVisualiser <: ((rounds+1)%2);

        fromAcc <: 1;
        fromAcc :> tilted;
        if (tilted == 1){
            distributorToVisualiser <: ((rounds+1)%2) + 8;
            uint32 time;
            toTimer <: 1;
            toTimer :> time;
            printf("Processing stopped...\nGeneration: %u, Time Elapsed: %u ms, Alive: %u\n", rounds, time, total_cells);
            while (tilted == 1)
               fromAcc :> tilted;
            distributorToVisualiser <: ((rounds+1)%2);
        }
    }
}

void time_worker(chanend toDist) {
    // wait till image is read to initialise timer
    toDist :> int init;
    uint32 time, initial;
    const uint32 period = 100000;
    timer t;

    t :> time;
    time /= period;
    initial = time;
    while (1) {
        // update the current time, or send the current time when requested
        select {
            // time will store elapsed ms, so multiply by period to get ticks
            case t when timerafter(time * period) :> void:
                time += 1;
                break;
            case toDist :> int x:
                toDist <: (time - initial);
                break;
        }
    }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel c_in to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outname[], chanend fromDist)
{
    int res;
    //int serving;
    uchar line[ IMWD ];
    uint32 packed_line[PACKED_WD];

    while(1) {
        // wait to receive signal to export file
        fromDist :> int export;
        printf( "DataOutStream: Start...\n" );
        res = _openoutpgm( outfname, IMWD, IMHT );
        if(res) {
            printf( "DataOutStream: Error opening %s\n.", outfname );
            return;
        }

        //Compile each line of the image and write the image line-by-line
        printf("DataOutStream: Exporting to %s...\n", outfname);
        for (int y = 0; y < IMHT; y++ ) {
            for (int x = 0; x < PACKED_WD; x++ ) {
                fromDist :> packed_line[x];
            }
            for (int i = 0; i < PACKED_WD; i++) {
                unpack(&line[i * 32], packed_line[i]);
            }
            _writeoutline(line, IMWD);
        }
        //Close the PGM image
        _closeoutpgm();
        printf( "DataOutStream: Done...\n" );
    }
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
  int pattern; // RGB G
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
     c_workers[WORKERS],
     buttonsToDistributor,
     distributorToLEDs,
     distributorToDataOut,
     distributorToTimer;    //extend your channel definitions here

par {
    on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);   //server thread providing orientation data
    on tile[0]: orientation(i2c[0],c_control);        //client thread reading orientation data
    on tile[1]: DataInStream(infname, c_inIO);          //thread to read in a PGM image
    on tile[1]: DataOutStream(outfname, distributorToDataOut);       //thread to write out a PGM image
    on tile[1]: distributor(c_inIO, c_control, work_in,buttonsToDistributor,distributorToLEDs, distributorToDataOut, distributorToTimer);//thread to coordinate work on image
    on tile[1]: time_worker(distributorToTimer);
    par(int i = 0; i < WORKERS; i++){
        on tile[i / (WORKERS / 2)]: conway_worker(work_in[i], c_workers[i], c_workers[(i + 1) % WORKERS], i % 2);
    }
    on tile[0]: buttonListener(buttons, buttonsToDistributor);
    on tile[0]: showLEDs(leds,distributorToLEDs);
  }

  return 0;
}
