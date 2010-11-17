
#include <MiniBee.h>

uint8_t myID = 2; // 2 or 3

MiniBee Bee = MiniBee();

char myConfig[] = { 0, 2, 0, 50, 1, // null, config id, msgInt high byte, msgInt low byte, samples per message
  AnalogOut, Custom, AnalogOut, AnalogOut, Custom, Custom, // D3 to D8
  AnalogOut, AnalogOut, AnalogOut, Custom, Custom,  // D9,D10,D11,D12,D13
  Custom, Custom, Custom, Custom, Custom, Custom, Custom, Custom // A0, A1, A2, A3, A4, A5, A6, A7
};

/// multiplexing with 2 CD4052's to get 16 light inputs from 4 analog inputs
/// D12, D13    - controlling multiplexer
/// A0,A1,A2,A3 - reading in analog data

/// Sonobotanic plant board 2

/// A0,A1,A2,A3 will be light sensing
/// D12, D13, light sensing select
/// D4,D7,D8 speaker select
/// A4,A5,A6,A7 are motor control
/// D3,D5,D6 will be PWM light 1 (RGB)
/// D9,D10,D11 will be PWM light 2 (RGB)

uint8_t lights[16];

/// this example shows how to use a stepper motor to be controlled from custom pins
#include <Stepper.h>

/// our motor has 7.5 degree steps, so 48 per full rotation
#define STEPS 48

/// stepper motors will be attached to pin 18 and 19, and 20 and 21.
Stepper stepper1(STEPS, 18, 19);
Stepper stepper2(STEPS, 20, 21);

/// message is:
/// 'M', change?, speed, direction, steps
/// 'K', change?, speed, direction, steps
/// 'S', speaker select
void customMsgParser( char * msg ){
   switch( msg[2] ){
    case 'M':
      if ( msg[3] > 0 ){ // change speed yes/no
	stepper1.setSpeed( msg[4] ); // second argument of message is the speed
      }
      if ( msg[5] == 0 ) // third argument is the direction
	stepper1.step( -1 * msg[6] ); // fourth argument is the amount of steps to do
      else
	stepper1.step( msg[6] ); // fourth argument is the amount of steps to do
      break;
    case 'K':
      if ( msg[3] > 0 ){ // change speed yes/no
	stepper2.setSpeed( msg[4] ); // second argument of message is the speed
      }
      if ( msg[5] == 0 ) // third argument is the direction
	stepper2.step( -1 * msg[6] ); // fourth argument is the amount of steps to do
      else
	stepper2.step( msg[6] ); // fourth argument is the amount of steps to do
      break;
    case 'S':
	setMultiplexer( msg[3] );
      break;
  }
}
 
uint8_t mpins [] = {4,7,8};

void setMultiplexer( byte value ){
   byte mask = 1;
   uint8_t j=0;
   for (mask = 00000111; mask>0; mask <<= 1) { //iterate through bit mask
       digitalWrite( mpins[j], (value & mask) );
       j++;
   }
}



void setup() {
  Bee.setRemoteConfig( false );
  Bee.openSerial(19200);
  Bee.configXBee();
  Bee.setID( myID );

  // define which pins we will be using for our custom functionality:
  // arguments are: pin number, size of data they will produce (in bytes)
    // speaker select (3), light sensing (6), motor control (4)
  uint8_t cpins []  = {4,7,8, 12,13, 14,15,16,17, 18,19,20,21};//, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  uint8_t csizes [] = {0,0,0,  0, 0,  0, 0, 0, 0,  0, 0, 0, 0};// , 1,1,1,1, 1,1,1,1, 1,1,1,1};

  Bee.setCustomPins( cpins, csizes, 13 );
  Bee.setCustomInput( 16, 1 ); // 16 light inputs, 1 byte each

  pinMode( 12, OUTPUT );
  pinMode( 13, OUTPUT );
  
  for ( uint8_t i=0; i<4; i++ ){
    pinMode( i+14, INPUT );
  }

  for ( uint8_t i=0; i<3; i++ ){
    pinMode( mpins[i], OUTPUT );
  }
  
  Bee.readConfigMsg( myConfig );

//   Bee.begin(19200);
}

uint8_t cnt=0;

void loop() {
  cnt = 0;
  for ( uint8_t i=0; i<2; i++ ){
    digitalWrite( 12, i ); // high bit, 0 then 1
    for ( uint8_t j=0; j<2; j++ ){
      digitalWrite( 13, j ); // low bit, 0 then 1
      for ( uint8_t k=0; k<4; k++ ){
	lights[cnt] = (uint8_t) (analogRead( k )/4);
	cnt++;
      }
    }
  }

  // add our customly measured data to the data package:
  Bee.addCustomData( lights, 16 );
 // do a loop step of the remaining firmware:
  Bee.doLoopStep();
}
