#include <MiniBee.h>
#include <Wire.h>

MiniBee Bee = MiniBee();

char myConfig[] = { 0, 1, 0, 50, 1, // null, config id, msgInt high byte, msgInt low byte, samples per message
  AnalogOut, Custom, AnalogOut, AnalogOut, Custom, Custom, // D3 to D8
  NotUsed, NotUsed, NotUsed, NotUsed, NotUsed,  // D9,D10,D11,D12,D13
  NotUsed, NotUsed, AnalogIn, AnalogIn, NotUsed, NotUsed, NotUsed, NotUsed // A0, A1, A2, A3, A4, A5, A6, A7
};

uint8_t myID = 0; // my id

char fadeVals[3] = {0,0,0}; // the current pwm values
char pwmVals[3] = {0,0,0}; // the current pwm values

char maxVals[3] = { 255,255,255 };
char minVals[3] = { 0,0,0 };
int stepVals[3] = { 2, 2, 2 };

char state[3] = { 0, 0, 0 }; // 0: fading, 1: at min, 2: at max
int timecounter[3] = {0,0,0};

int incVals[3] = { 1,2,3 };

int maxTime[3] = { 2000, 500, 300 };
int midTime[3] = { 1000, 250, 150 };

enum LightState {
  fading,
  atMin,
  atMax
};

char onoffLimit = 1;


uint8_t prev_msg[] = {0,0,0,0, 0,0,0,0}; // previous message ids from other nodes
bool otherThere[] = {false, false, false, false, false, false, false, false}; // whether others are there

uint8_t * otherData; 
char * myData;

void dataMsgParser( char * msg ){
  uint8_t msgSrc = msg[0]; // between 0 and 7, since we have three bits
  uint8_t msgID = msg[1];
  if ( prev_msg[msgSrc] != msgID ){
    // new message from that node ID:
    prev_msg[msgSrc] = msgID;
    // this other minibee is there:
    otherThere[msgSrc] = true;
    // copy the data to the array with "other data"
    for ( uint8_t j=0; j<5; j++ ){
      otherData[ msgSrc*5 + j ] = msg[ j+2 ];
    }
  }
}

void setup() {
  Bee.openSerial(19200);
  Bee.configXBee();
  
  uint8_t cpins []  = {4,7,8};
  uint8_t csizes [] = {0,0,0};

  Bee.setCustomPins( cpins, csizes, 3 ); // our id pins
  Bee.setCustomInput( 3, 1 ); // our current PWM values
  
  for ( uint8_t i=0; i < 3; i++ ){
      pinMode( cpins[i], INPUT );
  };
  
  /// reading the id from the hardware pins and setting it:
  for ( uint8_t i=0; i < 3; i++ ){
    myID << digitalRead( cpins[i] );
  };
  Bee.setID( myID );
  
  /// allocate an array for the data from up to 8 other nodes:
  otherData = (uint8_t *)malloc(sizeof(uint8_t)* 5*8) ;

  /// setting our own data parser to receive data from other nodes:
  Bee.setDataCall( dataMsgParser );

  Bee.readConfigMsg( myConfig );
}

void loop() {
   for ( uint8_t i=0; i < 3; i++ ){
      timecounter[i]++;
   }
   
  Bee.addCustomData( pwmVals );

  /// this does the sensing, and the serial receiving, and the N ms waiting
  Bee.doLoopStep();

  myData = Bee.getData();
  // update State
  updateState();
  // update current values of pwm
  updatePWM();
  Bee.setOutputValues( pwmVals, 0 );
  Bee.setOutput();
}

void updateState(){
  /// update according to time:
  for ( uint8_t i=0; i < 3; i++ ){ 
      if ( timecounter[i] == 1 ){
	// update direction
	stepVals[i] = incVals[i];
	fadeVals[i] = minVals[i];
      } else if ( timecounter[i] == midTime[i] ){
	// update direction
	stepVals[i] = -1 * incVals[i];
	fadeVals[i] = maxVals[i];
      } else if ( timecounter[i] > maxTime[i] ){
	timecounter[i]= 0;
      }
  }
//   if ( myData[3] < 100 ){
//       incVals[1] = 4;
//       maxTime[1] = 200;
//       midTime[1] = 100;
//   }
//   if ( myData[3] > 100 ){
//       incVals[1] = 2;
//       maxTime[1] = 500;
//       midTime[1] = 250;
//   }
//   if ( myData[4] < 100 ){
//       incVals[2] = 2;
//       maxTime[2] = 500;
//       midTime[2] = 250;
//   }
//   if ( myData[4] > 100 ){
//       incVals[2] = 4;
//       maxTime[2] = 200;
//       midTime[2] = 100;
//   }
//   
}

void updatePWM(){
   for ( uint8_t i=0; i < 3; i++ ){
      // update the faded value:
      fadeVals[i] = fadeVals[i] + stepVals[i];
      if ( fadeVals[i] < minVals[i] ){ // clip low
	fadeVals[i] = minVals[i];
	state[i] = atMin;
      } else if ( fadeVals[i] > maxVals[i] ){ // clip high
	fadeVals[i] = maxVals[i];
	state[i] = atMax;
      } else {
	state[i] = fading;
      }
      // update the PWM value
      pwmVals[i] = fadeVals[i];
      if ( pwmVals[i] < onoffLimit ){ // clip on/off
	pwmVals[i] = 0; 
      }
   }
}