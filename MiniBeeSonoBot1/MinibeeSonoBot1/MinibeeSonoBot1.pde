// #include <EEPROM.h>
// #include <Wire.h>

#include <MiniBee.h>

#include <CapSenseMC.h>


int capData[4];
long capLong[4];
uint8_t capPins[] = {17,18,19,20};
CapSenseMC   cSense = CapSenseMC(11,capPins,4); 
 
// this will be our parser for the custom messages we will send:
// msg[0] and msg[1] will be node ID and message ID
// the remainder the actual contents of the message
// if you want to send several kinds of messages, you can e.g.
// switch based on msg[2] for message type
void customParser( char * msg ){
//     Serial.println( msg );
  switch( msg[2] ){
    case 'L':
      for ( int j=1; j<9; j++ ){
	maxSingle( j, msg[j+2] );
      }
    break;
    case 'I':
     maxIntensity( msg[3] );
    break;
    case 'S'
      setMultiplexer( msg[3] );
    break;
  } 
}

/// A0,A1,A2,A3 will be light sensing
/// D12,13 will be SHT
/// D3,4,5 will be multiplexer
/// D6,7,8 are LED matrix
/// D9, D10 will be PWM light
/// D11, A4,A5,A6,A7 are capacitive

//    uint8_t capData[1];

// Channels   0  1  2  3  4  5  6  7
// byte bin [] = {0, 1, 2, 3, 4, 5, 6, 7};

uint8_t mpins [] = {3,4,5};
// byte mpinMask = { 0x01, 0x02, 0x04 };
/// 001, 010, 100

void setMultiplexer( byte value ){
  byte mask = 1;
  uint8_t j=0;
  for (mask = 00000111; mask>0; mask <<= 1) { //iterate through bit mask
      digitalWrite( mpins[j], (value & mask) );
      j++;
  }
}

void setup() {
  Bee.begin(19200);

  // define which pins we will be using for our custom functionality:
  // arguments are: pin number, size of data they will produce (in bytes)
  uint8_t cpins [] = {11,17,18,19,20, 6,7,8, 3,4,5};
  uint8_t csizes [] = {0,2,2,2,2, 0,0,0, 0,0,0};
  // capacitive sensing
/*  Bee.setCustomPin( 4, 0 );
  Bee.setCustomPin( 10, 2 );
  Bee.setCustomPin( 11, 2);
  Bee.setCustomPin( 12, 2 );
  Bee.setCustomPin( 13, 2 );
*/
  
  // max7219
//   Bee.setCustomPin( 6, 0 );
//   Bee.setCustomPin( 7, 0 );
//   Bee.setCustomPin( 8, 0 );
  
  Bee.setCustomPins( cpins, csizes, 8 );
  
  maxSetup();

  Bee.setCustomCall( &customParser );
}


void loop() {
  cSense.capSense( 30, capLong );
//   capLong[0] = cs_9_10.capSense(30);
//   capLong[1] = cs_9_11.capSense(30);
//   capLong[2] = cs_9_12.capSense(30);
//   capLong[3] = cs_9_13.capSense(30);

  for ( int j=0; j<4; j++ ){
   capData[j] = (int) capLong[j];
  }

  // add our customly measured data to the data package:
  Bee.addCustomData( capData );
 // do a loop step of the remaining firmware:
  Bee.doLoopStep();
}


/* code for max 7219 from maxim, 
reduced and optimised for useing more then one 7219 in a row,
______________________________________

 Code History:
 --------------

The orginal code was written for the Wiring board by:
 * Nicholas Zambetti and Dave Mellis /Interaction Design Institute Ivrea /Dec 2004
 * http://www.potemkin.org/uploads/Wiring/MAX7219.txt

First modification by:
 * Marcus Hannerstig/  K3, malmö högskola /2006
 * http://www.xlab.se | http://arduino.berlios.de

This version is by:
 * tomek ness /FH-Potsdam / Feb 2007
 * http://design.fh-potsdam.de/ 

 * @acknowledgements: eric f. 

-----------------------------------

General notes: 


-if you are only using one max7219, then use the function maxSingle to control
 the little guy ---maxSingle(register (1-8), collum (0-255))

-if you are using more then one max7219, and they all should work the same, 
then use the function maxAll ---maxAll(register (1-8), collum (0-255))

-if you are using more than one max7219 and just want to change something
at one little guy, then use the function maxOne
---maxOne(Max you wane controll (1== the first one), register (1-8), 
collum (0-255))

/* During initiation, be sure to send every part to every max7219 and then
 upload it.
For example, if you have five max7219's, you have to send the scanLimit 5 times
before you load it-- other wise not every max7219 will get the data. the
function maxInUse  keeps track of this, just tell it how many max7219 you are
using.
*/

char maxDataIn = 8;
char maxLoad = 7;
char maxClock = 6;

char e = 0;           // just a varialble
                     // define max7219 registers
byte max7219_reg_noop        = 0x00;
/*byte max7219_reg_digit0      = 0x01;
byte max7219_reg_digit1      = 0x02;
byte max7219_reg_digit2      = 0x03;
byte max7219_reg_digit3      = 0x04;
byte max7219_reg_digit4      = 0x05;
byte max7219_reg_digit5      = 0x06;
byte max7219_reg_digit6      = 0x07;
byte max7219_reg_digit7      = 0x08;*/
byte max7219_reg_decodeMode  = 0x09;
byte max7219_reg_intensity   = 0x0a;
byte max7219_reg_scanLimit   = 0x0b;
byte max7219_reg_shutdown    = 0x0c;
byte max7219_reg_displayTest = 0x0f;

void maxPutByte(byte data) {
  byte i = 8;
  byte mask;
  while(i > 0) {
    mask = 0x01 << (i - 1);      // get bitmask
    digitalWrite( maxClock, LOW);   // tick
    if (data & mask){            // choose bit
      digitalWrite( maxDataIn, HIGH);// send 1
    }else{
      digitalWrite( maxDataIn, LOW); // send 0
    }
    digitalWrite( maxClock, HIGH);   // tock
    --i;                         // move to lesser bit
  }
}

void maxSingle( byte reg, byte col) {    
//maxSingle is the "easy"  function to use for a     //single max7219
  digitalWrite(maxLoad, LOW);       // begin     
  maxPutByte(reg);                  // specify register
  maxPutByte(col);//((data & 0x01) * 256) + data >> 1); // put data   
  digitalWrite(maxLoad, LOW);       // and load da shit
  digitalWrite(maxLoad,HIGH); 
}

void maxIntensity( byte intens ){
  maxSingle(max7219_reg_intensity, intens & 0x0f);    // the first 0x0f is the value you can set  
}

void maxSetup(){
  pinMode(maxDataIn, OUTPUT);
  pinMode(maxClock,  OUTPUT);
  pinMode(maxLoad,   OUTPUT);

//initiation of the max 7219
  maxSingle(max7219_reg_scanLimit, 0x07);      
  maxSingle(max7219_reg_decodeMode, 0x00);  // using an led matrix (not digits)
  maxSingle(max7219_reg_shutdown, 0x01);    // not in shutdown mode
  maxSingle(max7219_reg_displayTest, 0x00); // no display test
   for (e=1; e<=8; e++) {    // empty registers, turn all LEDs off 
    maxSingle(e,0);
  }
  maxSingle(max7219_reg_intensity, 0x0f & 0x0f);    // the first 0x0f is the value you can set
}
