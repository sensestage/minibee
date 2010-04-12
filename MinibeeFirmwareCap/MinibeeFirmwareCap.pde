// #include <EEPROM.h>
#include <Wire.h>

#define MINIBEE_REVISION 'A'
#include <MiniBee.h>

#include <CapSense.h>

 // 10M resistor between pins 4 & 6, pin 6 is sensor pin, add a wire and or foil
CapSense   cs_10_11 = CapSense(10,11);       
CapSense   cs_10_12 = CapSense(10,12); 
CapSense   cs_10_13 = CapSense(10,13); 

// this will be our parser for the custom messages we will send:
// msg[0] and msg[1] will be node ID and message ID
// the remainder the actual contents of the message
// if you want to send several kinds of messages, you can e.g.
// switch based on msg[2] for message type
void customMsgParser( char * msg ){
    Serial.println( msg );
}

void setup() {
  Bee.begin(19200);

  // define which pins we will be using for our custom functionality:
  // arguments are: pin number, size of data they will produce (in bytes)
  Bee.setCustomPin( 10, 0 );
  Bee.setCustomPin( 11, 2 );
  Bee.setCustomPin( 12, 2 );
  Bee.setCustomPin( 13, 2 );

  // set the custom message function
  Bee.setCustomCall( &customMsgParser );
}

int capData[3];

void loop() {
  long total1 =  cs_10_11.capSense(30);
  long total2 =  cs_10_12.capSense(30);
  long total3 =  cs_10_13.capSense(30);

  capData[0] = (int) total1;
  capData[1] = (int) total2;
  capData[2] = (int) total3;
  
  // add our customly measured data to the data package:
  Bee.addCustomData( capData );
  // do a loop step of the remaining firmware:
  Bee.doLoopStep();
}
