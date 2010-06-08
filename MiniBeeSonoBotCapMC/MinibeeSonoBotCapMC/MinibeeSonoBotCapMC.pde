// #include <EEPROM.h>
// #include <Wire.h>

#include <MiniBee.h>

#include <CapSenseMC.h>

MiniBee Bee = MiniBee();

uint8_t myID = 1; // or 4

char myConfig[] = { 0, 1, 0, 50, 1, // null, config id, msgInt high byte, msgInt low byte, samples per message
  AnalogOut, Custom, AnalogOut, AnalogOut, SHTClock, SHTData, // D3 to D8
  AnalogOut, AnalogOut, AnalogOut, NotUsed, NotUsed,  // D9,D10,D11,D12,D13
  NotUsed, NotUsed, NotUsed, NotUsed, Custom, Custom, Custom, Custom // A0, A1, A2, A3, A4, A5, A6, A7
};

int capData[4];
long capLong[4];
uint8_t capPins[] = {18,19,20,21};
CapSenseMC   cSense = CapSenseMC(4,capPins,4); 
int capSamples = 30;
 
// this will be our parser for the custom messages we will send:
// msg[0] and msg[1] will be node ID and message ID
// the remainder the actual contents of the message
// if you want to send several kinds of messages, you can e.g.
// switch based on msg[2] for message type
void customParser( char * msg ){
//     Serial.println( msg );
  switch( msg[2] ){
    case 'C':
      capSamples = msg[3];
    break;
  }
}


/// Sonobotanic plant board 1

/// D7,8 will be SHT
/// D3,D5,D6 will be PWM light 1 (RGB)
/// D9,D10,D11 will be PWM light 2 (RGB)
/// D4, A4,A5,A6,A7 are capacitive sensing

/// Sonobotanic plant board 2

/// A0,A1,A2,A3 will be light sensing
/// D12, D13, light sensing select
/// D4,D7,D8 speaker select
/// A4,A5,A6,A7 are motor control
/// D3,D5,D6 will be PWM light 1 (RGB)
/// D9,D10,D11 will be PWM light 2 (RGB)


void setup() {
  Bee.setRemoteConfig( false );
  Bee.openSerial(19200);
  Bee.configXBee();
  Bee.setID( myID );
//   Bee.begin(19200);

  // define which pins we will be using for our custom functionality:
  // arguments are: pin number, size of data they will produce (in bytes)
  uint8_t cpins [] = {4,18,19,20,21};
  uint8_t csizes [] = {0,2,2,2,2};
  // capacitive sensing
    
  Bee.setCustomPins( cpins, csizes, 5 );  
  Bee.setCustomCall( &customParser );
  
  Bee.readConfigMsg( myConfig );
}


void loop() {
  cSense.capSense( capSamples, capLong );
  for ( int j=0; j<4; j++ ){
   capData[j] = (int) capLong[j];
  }

  // add our customly measured data to the data package:
  Bee.addCustomData( capData, 4 );
 // do a loop step of the remaining firmware:
  Bee.doLoopStep();
}
