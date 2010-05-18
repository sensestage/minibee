/// Wire needs to be included if TWI is enabled
// #include <Wire.h>
/// in the header file of the MiniBee you can disable some options to save
/// space on the MiniBee. If you don't the board may not work as it runs
/// out of RAM.
#include <MiniBee.h>

/// this example shows how to use a stepper motor to be controlled from custom pins
#include <Stepper.h>

/// our motor has 7.5 degree steps, so 48 per full rotation
#define STEPS 48

MiniBee Bee = MiniBee();

/// stepper motor will be attached to pin 12 and 13
Stepper stepper(STEPS, 12, 13);

// this will be our parser for the custom messages we will send:
// msg[0] and msg[1] will be node ID and message ID
// the remainder are the actual contents of the message
// if you want to send several kinds of messages, you can e.g.
// switch based on msg[2] for message type
void customMsgParser( char * msg ){
     if ( msg[2] > 0 ){ // change speed yes/no
       stepper.setSpeed( msg[3] ); // second argument of message is the speed
     }
     if ( msg[4] == 0 ) // third argument is the direction
       stepper.step( -1 * msg[5] ); // fourth argument is the amount of steps to do
     else
       stepper.step( msg[5] ); // fourth argument is the amount of steps to do
}

void setup() {
  Bee.begin(19200);
  
/// set a default speed for our stepper
  stepper.setSpeed( 60 );

  // define which pins we will be using for our custom functionality:
  // arguments are: pin number, size of data they will produce (in bytes)
  /// in our case, pins 12 and 13, and we don't output any data from them
  Bee.setCustomPin( 12, 0 );
  Bee.setCustomPin( 13, 0 );

  // set the custom message function
  Bee.setCustomCall( &customMsgParser );
}

void loop() {  
  // do a loop step of the remaining firmware:
  Bee.doLoopStep();
}
