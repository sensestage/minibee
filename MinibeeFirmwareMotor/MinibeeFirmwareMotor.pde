// #include <EEPROM.h>
#include <Wire.h>

#define MINIBEE_REVISION 'A'
#include <MiniBee.h>

// #include <CapSense.h>
#include <Stepper.h>

#define STEPS 48

Stepper stepper(STEPS, 7, 8);

// this will be our parser for the custom messages we will send:
// msg[0] and msg[1] will be node ID and message ID
// the remainder the actual contents of the message
// if you want to send several kinds of messages, you can e.g.
// switch based on msg[2] for message type
void customMsgParser( char * msg ){
    stepper.setSpeed( msg[2] ); // first argument of message is the speed
    if ( msg[3] == 0 ) // second argument is the direction
      stepper.step( -1 * msg[4] ); // third argument is the amount of steps to do
    else
      stepper.step( msg[4] ); // third argument is the amount of steps to do      
}

void setup() {
  Bee.begin(19200);

  stepper.setSpeed( 30 );
  // define which pins we will be using for our custom functionality:
  // arguments are: pin number, size of data they will produce (in bytes)
  Bee.setCustomPin( 7, 0 );
  Bee.setCustomPin( 8, 0 );

  // set the custom message function
  Bee.setCustomCall( &customMsgParser );
}


void loop() {  
  // do a loop step of the remaining firmware:
  Bee.doLoopStep();
}
