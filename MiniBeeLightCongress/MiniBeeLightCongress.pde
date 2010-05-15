#include <MiniBee.h>
#include <Wire.h>

MiniBee Bee = MiniBee();

char myConfig[] = { 0, 1, 0, 100, 1,
  AnalogOut, Custom, AnalogOut, AnalogOut, Custom, Custom, // D3 to D8
  NotUsed, NotUsed, NotUsed, NotUsed, NotUsed,  // D9,D10,D11,D12,D13
  NotUsed, NotUsed, AnalogIn, AnalogIn, NotUsed, NotUsed, NotUsed, NotUsed // A0, A1, A2, A3, A4, A5, A6, A7
};

uint8_t myID = 0;

uint8_t prev_msg[] = {0,0,0,0, 0,0,0,0};

uint8_t pwmVals[3] = {0,0,0};

void dataMsgParser( char * msg ){
  uint8_t msgSrc = msg[0];
  uint8_t msgID = msg[1];
  if ( prev_msg[msgSrc] != msgID ){
    // new message from that node ID:
    prev_msg[msgSrc] = msgID;
    // do something useful with the message
  }
}

void setup() {
  Bee.openSerial(19200);
  Bee.configXBee();
  Bee.readConfigMsg( myConfig );
  
  uint8_t cpins []  = {4,7,8};
  uint8_t csizes [] = {0,0,0};// , 1,1,1,1, 1,1,1,1, 1,1,1,1};

  Bee.setCustomPins( cpins, csizes, 3 ); // our id pins
  Bee.setCustomInput( 3, 1 ); // our current PWM values
  
  for ( uint8_t i=0; i < 3; i++ ){
      pinMode( cpins[i], INPUT );
  };
  
  for ( uint8_t i=0; i < 3; i++ ){
    myID << digitalRead( cpins[i] );
  };
  Bee.setID( myID );
  Bee.setDataCall( dataMsgParser );
}


void loop() {
  Bee.addCustomData( pwmVals );
  Bee.doLoopStep();
  // update State
  // update current values of pwm
}
