// #include <EEPROM.h>
// #include <Wire.h>

#include <MiniBee.h>

// #include <CapSense.h>
#include <Stepper.h>

#define STEPS 48

Stepper stepper(STEPS, 12, 13);

// this will be our parser for the custom messages we will send:
// msg[0] and msg[1] will be node ID and message ID
// the remainder the actual contents of the message
// if you want to send several kinds of messages, you can e.g.
// switch based on msg[2] for message type
void customMsgParser( char * msg ){
     if ( msg[2] > 0 ){
       stepper.setSpeed( msg[3] ); // first argument of message is the speed
     }
     if ( msg[4] == 0 ) // second argument is the direction
       stepper.step( -1 * msg[5] ); // third argument is the amount of steps to do
     else
       stepper.step( msg[5] ); // third argument is the amount of steps to do
//    digitalWrite( 12, msg[2] );
//    digitalWrite( 13, msg[3] );
}

void setup() {
  Bee.begin(19200);

//  pinMode( 12, OUTPUT );
//  pinMode( 13, OUTPUT );
  
  stepper.setSpeed( 60 );
  // define which pins we will be using for our custom functionality:
  // arguments are: pin number, size of data they will produce (in bytes)
  Bee.setCustomPin( 12, 0 );
  Bee.setCustomPin( 13, 0 );

  // set the custom message function
  Bee.setCustomCall( &customMsgParser );
}


void loop() {  
  // do a loop step of the remaining firmware:
  Bee.doLoopStep();
}
