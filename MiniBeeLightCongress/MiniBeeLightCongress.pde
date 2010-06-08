#include <MiniBee.h>
// #include <Wire.h>

MiniBee Bee = MiniBee();

char myConfig[] = { 0, 1, 0, 50, 1, // null, config id, msgInt high byte, msgInt low byte, samples per message
  AnalogOut, Custom, AnalogOut, AnalogOut, Custom, Custom, // D3 to D8
  NotUsed, NotUsed, NotUsed, NotUsed, NotUsed,  // D9,D10,D11,D12,D13
  NotUsed, AnalogIn, AnalogIn, NotUsed, NotUsed, NotUsed, NotUsed, NotUsed // A0, A1, A2, A3, A4, A5, A6, A7
};

uint8_t myID = 0; // my id

char msgVals[9] = {0,0,0,0,0,0,255,255,255}; // the current pwm values

char pwmVals[3] = {0,0,0}; // the current pwm values

char holdVals[3] = {0,0,0}; // the current pwm values

int maxVals[3] = { 255,255,255 };
int minVals[3] = { 0,0,0 };

uint8_t lids[] = {0,1,2};
uint8_t old_lids[] = {0,1,2};

char onoffLimit = 5;

int lightCum[2] = {0,0};
int mainCnt = 0;
int msgCnt = 0;

int fadeVals[3] = {0,0,0};
int fadeStep[3] = {0,0,0};
int fadeInc[3] = { 2,4,10 };

char state[3] = { 0, 0, 0 }; // 0: fading, 1: at min, 2: at max
int timecounter[3] = {0,0,0};

int maxTime[3] = { 1000, 300, 100 };
int midTime[3] = {  500, 150,  50 };

// int fadeDist = 147;

int blackCnt = 0;
int holdCnt = 0;
char mainState;

enum LightState {
  fading,
  atMin,
  atMax,
  black1,
  hold,
  black2
};


uint8_t prev_msg[12] = {0, 0,0, 0,0,0, 0,0,0, 0,0,0}; // previous message ids from other nodes
bool otherThere[] = {false, false, false, false, false, false, false, false}; // whether others are there

uint8_t lastOther = 0;

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
    lastOther = msgSrc;
    // copy the data to the array with "other data"
    for ( uint8_t j=0; j<9; j++ ){
      otherData[ msgSrc*11 + j ] = msg[ j+2 ];
    }
  }
}

void setup() {
  Bee.setRemoteConfig( false );
  Bee.openSerial(19200);
  Bee.configXBee();
  
  mainState = fading;
  
  uint8_t cpins []  = {4,7,8};
  uint8_t csizes [] = {0,0,0};

  Bee.setCustomPins( cpins, csizes, 3 ); // our id pins
  Bee.setCustomInput( 9, 1 ); // our current PWM values, min and max values
  
  for ( uint8_t i=0; i < 3; i++ ){
      pinMode( cpins[i], INPUT );
  };
  
  /// reading the id from the hardware pins and setting it:
  for ( uint8_t i=0; i < 3; i++ ){
    myID << digitalRead( cpins[i] );
  };
  Bee.setID( myID );
  
  /// allocate an array for the data from up to 8 other nodes:
  otherData = (uint8_t *)malloc(sizeof(uint8_t)* 5 * 8) ;

  /// setting our own data parser to receive data from other nodes:
  Bee.setDataCall( dataMsgParser );

  Bee.readConfigMsg( myConfig );
}

void mimicBee( uint8_t bid ){
    if ( otherThere[bid] ){
	mainState = black1;
	for ( uint8_t i=0; i < 3; i++ ){
	  holdVals[i] = otherData[ bid * 5 + 2 + i ];
	}
    } else {
	mainState = fading;
    }
}

int clip( int in, int min, int max ){
  int out;
  out = in;
  if ( out < min ){
    out = min;
  }
  if ( out > max ){
    out = max;
  }
  return out;
}

void loop() {
  int fadeSum;
  int lightCumSum;

  for ( uint8_t i=0; i < 3; i++ ){
    msgVals[i]   = pwmVals[i];
//     msgVals[i+3] = minVals[i];
//     msgVals[i+6] = maxVals[i];
  }
  
  Bee.addCustomData( msgVals, 3 );

  /// this does the sensing, and the serial receiving, and the N ms waiting
  Bee.doLoopStep();

  myData = Bee.getData();

  switch( mainState ){
    case black1:
      blackCnt++;
      if ( blackCnt > 10 ){
	mainState = hold;
	blackCnt = 0;
      }
      for ( uint8_t i=0; i < 3; i++ ){
	pwmVals[i] = 0;
      }
      break;
    case black2:
      blackCnt++;
      if ( blackCnt > 10 ){
	mainState = fading;
	blackCnt = 0;
      }
      for ( uint8_t i=0; i < 3; i++ ){
	pwmVals[i] = 0;
      }
      break;
    case hold:  
      holdCnt++;
      if ( holdCnt > 100 ){
	mainState = black2;
	holdCnt = 0;
      }
      for ( uint8_t i=0; i < 3; i++ ){
	pwmVals[i] = holdVals[i];
      }      
    case fading:
      msgCnt++;
      if ( msgCnt > (40*20 + myData[0] + myData[1] ) ){
	mimicBee( lastOther );
	msgCnt = 0;
	// to add, get closer to their min/max values
      }

      for ( uint8_t i=0; i < 2; i++ ){
	lightCum[i] = (lightCum[i] + myData[i])/2;
      }

      mainCnt++;
      
      /*
      if ( mainCnt%100 == 0 ){
	lightCumSum = lightCum[0] + lightCum[1];
	if ( lightCumSum < 30 ){ // dark
	    for ( uint8_t i=0; i < 3; i++ ){
	      minVals[i]++; 
	      maxVals[i]++;
	      minVals[i] = clip( minVals[i], 0, maxVals[i]-fadeDist );
	      maxVals[i] = clip( maxVals[i], minVals[i]+fadeDist, 511 );
	    }
	}
	if ( lightCumSum > 400 ){ // very bright
	    for ( uint8_t i=0; i < 3; i++ ){
	      minVals[i]--; 
	      maxVals[i]--;
	      minVals[i] = clip( minVals[i], 0, maxVals[i]-fadeDist );
	      maxVals[i] = clip( maxVals[i], minVals[i]+fadeDist, 511 );
	    }
	}
      }
      */

      fadeSum = fadeVals[0] + fadeVals[1] + fadeVals[2];
      if ( ( (fadeSum > 1200) || (fadeSum < 60) ) && (mainCnt > 300) ){
	for ( uint8_t i=0; i < 3; i++ ){
	  old_lids[i] = lids[i];
	}
	if ( lightCum[1] - lightCum[0] > 0 ){
	  lids[0] = old_lids[1];
	  lids[1] = old_lids[2];
	  lids[2] = old_lids[0];
	} else {
	  lids[0] = old_lids[2];
	  lids[1] = old_lids[0];
	  lids[2] = old_lids[1];
	}
	mainCnt = 0;
	lightCum[0] = 0; lightCum[1] = 0;
      }

      for ( uint8_t i=0; i < 3; i++ ){
	timecounter[i]++;
	if ( timecounter[i] == 1 ){
	  fadeStep[i] = fadeInc[i];
	} else if ( timecounter[i] == midTime[i] ){
	  fadeStep[i] = -1*fadeInc[i];
	} else if ( timecounter[i] > maxTime[i] ){
	  timecounter[i] = 0;
	}
	fadeVals[i] = fadeVals[i] + fadeStep[i];
	fadeVals[i] = clip( fadeVals[i], 0, 511);
	// update the PWM value
	pwmVals[i] = fadeVals[i]/2;
// 	if ( pwmVals[i] < onoffLimit ){
// 	    pwmVals[i] = 0;
// 	}
      }
      break;
  }
  
  Bee.setOutputValues( pwmVals, 0 );
  Bee.setOutput();
}
