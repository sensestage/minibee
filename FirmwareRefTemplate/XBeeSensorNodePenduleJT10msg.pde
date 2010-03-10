//**************************************************************//
//  XBee Arduino Sensor Node                                    //
//  Marije Baalman May 2009                                     //
//  Mark T. Marshall August 2008                                //
//  Based on:                                                   //
//  Tenor T-Stick Arduino Serial USB                            //
//  Joseph Malloch December 2007                                //
//  Input Devices and Music Interaction Laboratory              //
//  Notes   : Adapted shiftIn() function by Carlyn Maw          //
//  Version : 1.5                                               //
//****************************************************************
//**************************************************************//
//  Arduino LIS302DL code                                       //
//  Joseph Malloch May 2009                                     //
//  Input Devices and Music Interaction Laboratory              //
//  Version : 1.0                                               //
//  Notes   : Adapted I2C code by Tom Igoe                      //
//            Adapted LIS302DL code by Ben Gatti                //
//****************************************************************
//**************************************************************//
//  Revision of messaging protocol for PWM and digital output   //
//  Joseph Thibodeau Feb 2010                                   //
//  Input Devices and Music Interaction Laboratory              //
//****************************************************************


// include Wire library to read and write I2C commands:
#include <Wire.h>

//LIS302DL accelerometer addresses
#define accel1Address 0x1C
#define accelResultX 0x29
#define accelResultY 0x2B
#define accelResultZ 0x2D

//Number of nondata integers in message body
#define MSG_NONDATA_INTS 2
#define MAX_DIGIPINS 11

// ID for the node (e.g. start at 160)
int ID = 117;

/// --- for basic use, you only need to configure these parameters to get the data in that you want
/// --- settings ---
boolean useI2C = true; // accelerometer - accelero LIS320DL protocol
boolean useWiiI2C = false; // accelerometer - from the WiiMote
boolean useSHT = false;  // humidity sensor protocol
boolean checkJumpSHT = false; // humidity sensor
boolean doPing = false;  // ultrasound distance measurement
int noAnalog = 0;        // number of analog pins to read
//int digInMaxPin = 2;     // last digital pin to read (the first one is number 3, so if this number is 2 no pins will be read)

int digitalModes[] = { 3, 2, 3, 3, 2, 2, 3, 3, 3, 2, 2 }; //0 - not used, 1 digital in, 2 digital out, 3 pwm 

int smpPmsg = 10;   // maximum 10! (or increase databytes array)	
int msgInterval = 50;
int smpInterval;
/// --- end settings ---

// int numPWM = 0;           // number of PWM outputs. message format is type 'p', then nodeID+msgID+(6 data values)
// int numDigOut = 0; //num Digital pins
// int numDigIn = 0; //num Digital pins



/// PWM pins
int pwmPins[] =   {3,  5,6,   9,10,11};
int pwmDigIDs[] =   {0,    2, 3,       6,  7,  8 };

/// digital Outputs
int digitalPins[] = {3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13}; //not necessarily using whole array depending on PWM config -- see configDigitalPins function



byte databytes[280];     // to store the intermediate measurement results
int maxDataBytes = 280;  // maximum number of databytes to use (8 analog, 2 bytes I2C, 4 for humidity/Temp, 2 for ultrasound, 11 for digital


int latchPin = 8;
int dataPin = 9;
int clockPin = 7;

int xbeesleepPin = 2;
int IRledPin = 3;

int digInMinPin = 3;
int pingPin = 13;

byte escapeChar = 92;
byte delimiterChar = 10;
byte delChar2 = 13;
int t,i,j = 0;
int started = 1;

int incoming = 0;

// reading bytes
char msgtype = 'n';
int bytenr = 0;
int msgSize = 0;
int msgSendID = 0;
int msgRecvID = 0;
boolean escape = false;
int setlights;

//message buffer
byte message[] = { 0,0,0, 0,0,0,
                  0,0,0, 0,0,0, 
                  0,0,0, 0,0,0, 
                  0,0,0, 0,0,0, 
                  0,0,0, 0,0,0, 
                  0,0,0, 0,0,0,
                  0, 0, 0 };

/// light values
int pwmVals[] = { 0,0,0, 0,0,0};
//int prevVals[] = { 255,255,255, 255,255,255}; //old mechanism - don't update repeat values


byte wiidata[6]; //six data bytes
int yaw, pitch, roll; //three axes
// int yaw0, pitch0, roll0; //calibration zeroes

////--------- Humidity sensor -----------

#define  T_CMD  0x03                // See Sensirion Data sheet
#define  H_CMD  0x05
#define  R_STAT 0x07
#define  W_STAT 0x06
#define  RST_CMD 0x1E

/*
//==========================================================================//
// SHT11 Sensor Coefficients from Sesirion Data Sheet
const float C1=-4.0;               // for 12 Bit
const float C2= 0.0405;            // for 12 Bit
const float C3=-0.0000028;         // for 12 Bit
//const float D1=-40.0;              // for 14 Bit @ 5V
//const float D2=0.01;               // for 14 Bit DEGC
const float T1=0.01;               // for 14 Bit @ 5V
const float T2=0.00008;            // for 14 Bit @ 5V
*/
//==========================================================================//
int shtOnPin = 13;
// Sensor Variables
int shtClk   =  11;                // Clock Pin                        
int shtData  =  12;                // Data Pin
int ioByte;                        // data transfer global -  DATA
int ackBit;                        // data transfer glocal  - ACKNOWLEDGE
//byte msb, lsb;                      // most significant byte and least significant byte of data
int retVal;
int r_temp;                      // raw working temp
int r_humid;                     // Raw working humidity

//float retVal;                      // Raw return value from SHT-11
/*
float temp_degC;                   // working temperature
float temp_degF;                   // working tempeature
float r_temp;                      // raw working temp
float r_humid;                     // Raw working humidity
float dew_point;
float dew_pointF;
*/
//==========================================================================//
// coding variables
int dly;
int timewait;
byte bitmask;
//==========================================================================//

int db = 0;



void setup() {
  //start serial
  Serial.begin(19200);

  smpInterval = msgInterval / smpPmsg;
  
  // define xbee sleep pin
  pinMode( xbeesleepPin, OUTPUT );
  
  //define pin modes (capacitive sensing)
//  pinMode(latchPin, OUTPUT);
//  pinMode(clockPin, OUTPUT); 
//  pinMode(dataPin, INPUT);

  // define IR led pin
//   pinMode( IRledPin, OUTPUT );

  if ( useI2C ){
    setupI2C();      
  }

  if ( useWiiI2C ){
    setupWiiI2C();      
  }

  for ( i=0; i<maxDataBytes; i++){
     databytes[i] = 0;
  }

  // define other digital pins
	configDigitalPins();


    for (t=0; t<noAnalog; t++) {
      if ( (t == 4 | t == 5) ){
         if ( !useI2C ) {
               pinMode(14+t, INPUT);  
         }
      } else {
        pinMode(14+t, INPUT);  
      }  
    }  

/*
    for ( i=0; i<numPWM; i++) {
       analogWrite( pwmPins[i], 0 );
       }
*/
// humidity sensor
  
  if ( useSHT ){
    if ( checkJumpSHT ){
       pinMode( shtOnPin, INPUT ); 
    }
    pinMode(shtClk, OUTPUT);
    digitalWrite(shtClk, HIGH);     // Clock
  
    pinMode(shtData, OUTPUT);        // Data
    
    SHT_Connection_Reset();
  }

    
// wake up XB
  digitalWrite( xbeesleepPin, 0 );

  //delay to allow XBee to start
  delay(100);

  started = 1;

//   digitalWrite( IRledPin, 1 );
}


// Joseph Thibodeau 2010.02.09
// makes sure that digital pin configs don't collide with PWM configs
void configDigitalPins()
{

  for ( i=0; i < 11; i++ ){
	switch( digitalModes[i] ){
	  case 1: // input
		pinMode( digitalPins[i], INPUT );
		break;
	  case 2:
	  case 3:
		pinMode( digitalPins[i], OUTPUT );
		break;
	}
  }
}

/*
    for (t=digInMinPin; t<=digInMaxPin; t++) {
      if ( t == 10 | t == 11 ){
         if ( !useSHT ){
           pinMode( t, INPUT);
         }
      } else {
        pinMode( t, INPUT);
      }
    }
    //define pin modes
  for ( i=0; i<numPWM; i++){
	digitalPins[ pwmPins[i] - 3 ] = 0;
     pinMode( pwmPins[i], OUTPUT );
  }

  for (i = 0; i < numDigi; i++)
	{
	if (digitalPins[i] > 0){
		  // first digital pin is number 3, so we add 2 to the configuration
		  pinMode( digitalPins[i], OUTPUT );
	}
	
}
*/


void loop() {
/*  incoming = Serial.read();
  if (incoming=='r')
    started = 1;
  else if (incoming=='x')
    started = 0;
*/
  //if system is started, send a reading every 50 ms
  
  int samp;
  int bytestoread;
 
  db = 0;
 
  bytestoread = Serial.available();
  if ( bytestoread > 0 ){
 //   digitalWrite( 4, 1 );
	  for ( i = 0; i < bytestoread; i++ ){
		readByte();      
	  }
  }

  if(started == 1) {
//    slipOut(ID);

	for ( samp = 0; samp < smpPmsg; samp++ ){

	  //Read analog data  
	  for (t=0; t<noAnalog; t++) {
		if ( (t == 4 & t == 5) ){
		  if ( !useI2C ) {
            databytes[db] = analogRead(t)/4;
            db++;
		  }
		} else {
		  databytes[db] = analogRead(t)/4;
		  db++;
		}
	  } // end analog
    
    
	  for ( i=0; i < 11; i++ ){
		if ( digitalModes[i] == 1 ){
		  databytes[db] = digitalRead( digitalPins[i] );
		  db++;
		}
	  } // end digital in
	    
			  //Read digital data (from capacitive sensor)
			  //    for (t=1; t<4; t++) {
			  //      slipOut(shiftInCap(dataPin, clockPin));
			  //    }

	  if ( useI2C ){
		readAccelerometerI2C(accel1Address, db);
		db = db+3;
	  } // end I2C
	  
	  if ( useWiiI2C ){
		readAccelWiiI2C( db );
		db = db+6;
	  }

	  if ( doPing ){
//    	  slipOutInt( readUltrasound() );
		databyteFromInt( readUltrasound(), db );
		db = db + 2;
	  } // end PING
    
    
	  if ( useSHT ){
		boolean doSHT = true;
		if ( checkJumpSHT ){
		  if ( digitalRead( shtOnPin ) == 1 ){
			doSHT = true;
		  } else {
			doSHT = false;
		  }
		}
		if ( doSHT ){
		  SHT_Measure(T_CMD);                    // retVal = Temperature reading
		  r_temp = retVal;
  //       temp_degC = SHT_calc_tempC( retVal);  // Convert to Celcius
  //       temp_degF = SHT_calc_tempF( retVal);  // Convert to Fahrenheit
		  databyteFromInt( r_temp, db );
		  db = db + 2;
      
		  SHT_Measure(H_CMD);                     // retVal = humidity reading
		  r_humid = retVal;                         // Store raw humidity value

		  databyteFromInt( r_humid, db );
		  db = db + 2;
      
		} else {
			for ( int i=0; i < 4; i++ ){
			  databytes[db] = 0;
			  db++; 
			}
		}
	  } // end SHT
	
	delay( smpInterval );
	} // end of iteration over samplesPerMessage

    // send complete message
    slipOutChar( 'd' );
    slipOut(ID);
    msgSendID++;
    slipOut( msgSendID );
    for ( i=0; i < db; i++ ){
      slipOut( databytes[i] );
    }
    Serial.print(delimiterChar, BYTE);
//    delay(50);
  }
}

void databyteFromInt( int output, int offset ){
  databytes[offset] = byte(output/256);
  databytes[offset+1] = byte(output%256);
}

void slipOutInt( int output ){
  slipOut( byte(output/256));
  slipOut( byte(output%256));  
}

void slipOutChar(char output) {
    Serial.print(escapeChar, BYTE);
    Serial.print(output, BYTE);
}

void slipOut(byte output) {
    if ((output==escapeChar)||(output==delimiterChar)||(output==delChar2)) Serial.print(escapeChar, BYTE);
    Serial.print(output, BYTE);
}

byte shiftInCap(int myDataPin, int myClockPin) { 
  int i;
  int temp = 0;
  byte myDataIn = 0;
  for (i=7; i>=0; i--)
  {
    digitalWrite(myClockPin, 0);
    //delayMicroseconds(1);
    temp = digitalRead(myDataPin);
    if (temp) {
      myDataIn = myDataIn | (1 << i);
    }
    digitalWrite(myClockPin, 1);
    //delayMicroseconds(1);
  }
  return myDataIn;
}

int readUltrasound(){

  long duration;
  

  // The Devantech US device is triggered by a HIGH pulse of 10 or more microseconds.
  // We give a short LOW pulse beforehand to ensure a clean HIGH pulse.
  pinMode(pingPin, OUTPUT);
  digitalWrite(pingPin, LOW);
  delayMicroseconds(2);
  digitalWrite(pingPin, HIGH);
  delayMicroseconds(11);
  digitalWrite(pingPin, LOW);

  // The same pin is used to read the signal from the Devantech Ultrasound device: a HIGH
  // pulse whose duration is the time (in microseconds) from the sending
  // of the ping to the reception of its echo off of an object.
  pinMode(pingPin, INPUT);
  duration = pulseIn(pingPin, HIGH);

  // max value is 30000 so easily fits in an int

  return int( duration );
}

void setupWiiI2C(){
  Wire.begin();
  Wire.beginTransmission(0x53); //WM+ starts out deactivated at address 0x53
  Wire.send(0xfe); //send 0x04 to address 0xFE to activate WM+
  Wire.send(0x04);
  Wire.endTransmission(); //WM+ jumps to address 0x52 and is now active
  
  wiiI2CSendZero();
}

void wiiI2CSendZero(){
  Wire.beginTransmission(0x52); //now at address 0x52
  Wire.send(0x00); //send zero to signal we want info
  Wire.endTransmission();
}


void readAccelWiiI2C( int dboff ){
  wiiI2CSendZero(); //send zero before each request (same as nunchuck)
  Wire.requestFrom(0x52,6); //request the six bytes from the WM+
  for (int i=0;i<6;i++){
	wiidata[i]=Wire.receive();
  }
  // three ints as results
  yaw=  ((wiidata[3]>>2)<<8)+wiidata[0];
  pitch=((wiidata[4]>>2)<<8)+wiidata[1];
  roll= ((wiidata[5]>>2)<<8)+wiidata[2];
  
  // write into databytes
  databyteFromInt( yaw, dboff );
  databyteFromInt( pitch, dboff+2 );
  databyteFromInt( roll, dboff+4 );
}

void readAccelerometerI2C(int address, int dboff) {
  Wire.beginTransmission(address);
  Wire.send(accelResultX);                   //set x register
  Wire.endTransmission();
  Wire.requestFrom(address, 1);            //retrieve x value
//  slipOut((Wire.receive()+128)%256);
  databytes[dboff] = (Wire.receive()+128)%256;
  
  Wire.beginTransmission(address);
  Wire.send(accelResultY);                   //set y register
  Wire.endTransmission();
  Wire.requestFrom(address, 1);            //retrieve y value
//  slipOut((Wire.receive()+128)%256);
  databytes[dboff+1] = (Wire.receive()+128)%256;

  Wire.beginTransmission(address);
  Wire.send(accelResultZ);                   //set z register
  Wire.endTransmission();
  Wire.requestFrom(address, 1);            //retrieve z value
//  slipOut((Wire.receive()+128)%256);
  databytes[dboff+2] = (Wire.receive()+128)%256;
}

void setupI2C(){
   //start I2C bus
  Wire.begin();
  
  //LIS302DL setup
  Wire.beginTransmission(accel1Address);
  Wire.send(0x21); // CTRL_REG2 (21h)
  Wire.send(B01000000);
  Wire.endTransmission();
  
  	//SPI 4/3 wire
  	//1=ReBoot - reset chip defaults
  	//n/a
  	//filter off/on
  	//filter for freefall 2
  	//filter for freefall 1
  	//filter freq MSB
  	//filter freq LSB - Hipass filter (at 400hz) 00=8hz, 01=4hz, 10=2hz, 11=1hz (lower by 4x if sample rate is 100hz)   

  Wire.beginTransmission(accel1Address);
  Wire.send(0x20); // CTRL_REG1 (20h)
  Wire.send(B01000111);
  Wire.endTransmission();
  
  	//sample rate 100/400hz
  	//power off/on
  	//2g/8g
  	//self test
  	//self test
  	//z enable
  	//y enable
  	//x enable 
}



//Joseph Thibodeau 2010.02.09 based on code by Marije Baalman
//Receives messages & prepares them for interpretation
//Message general protocol:
// ESC, CHAR, INT, ..., INT, DELIM
// where data INTs must be preceded by ESC if they would be interpreted incorrectly as DELIM
void readByte()
{
	incoming = Serial.read();
	if (escape) //escape is not set
	{
	  if ((incoming == escapeChar) || (incoming == delimiterChar) || (incoming == delChar2))
		{
			//escape to integer --- otherwise we interpret an int as a delimiter
			message[bytenr] = incoming;
			bytenr++;
		}
	  else //escape to a char representing the message type
		{
			msgtype = (char) incoming;
		}
	  escape = false;
	}
	else //escape is set
	{
		if (incoming == escapeChar) //if we get an escape character
		{
			escape = true;
		}
		else if (incoming == delimiterChar) //end of message
		{
			msgSize = bytenr; //log the size of this message
			bytenr = 0; //reset byte counter
			endMsg(); //run message parsing routine
		}
		else //this character is a data byte
		{
			message[bytenr] = incoming;
			bytenr++;
		}
	}
}

//Joseph Thibodeau 2010.02.09 based on code by Marije Baalman
//Interprets a formatted message
//NOTE that message contents are overwritten, so any data that must be persistent must be copied away from the message[] buffer.
void endMsg()
{
	if ( message[0] == ID )
	// only process the message if this is its receiver and we haven't yet dealt with this message
	{
		switch(msgtype)
		{
			case 'P': //set PWM message
				pwmMessage();
				break;
			case 'D': //set Digital pin message
				digitalMessage();
				break;
			case 'l':
				oldPWMmessage();
				break;
		}
	}
}

void oldPWMmessage()
{
	  for ( i = 0; i < 6; i++ ){
	  if ( digitalModes[ pwmDigIDs[i] ] == 3 ){ // pin is in PWM mode
		  pwmVals[i] = message[i+MSG_NONDATA_INTS]; //store next PWM value
		  analogWrite( pwmPins[i], pwmVals[i] ); //write value to pin
		}
	  }
}

//Joseph Thibodeau 2010.02.09
//sets the pwm for configured pins and given values (assuming it is set up)
void pwmMessage()
{
	if (message[1] != msgRecvID){
	  msgRecvID = message[1]; //this message has been received
	  for ( i = 0; i < 6; i++ ){
	  if ( digitalModes[ pwmDigIDs[i] ] == 3 ){ // pin is in PWM mode
		  pwmVals[i] = message[i+MSG_NONDATA_INTS]; //store next PWM value
		  analogWrite( pwmPins[i], pwmVals[i] ); //write value to pin
		}
	  }
	}
}

/*
	int pinsToWrite = msgSize - MSG_NONDATA_INTS; //message size minus node ID and message ID gives # of PWM values in message
	//we will write between 0 and 6 PWM values, depending on
	// A. whether the PWM pins are configured at all (0)
	// B. how many PWM pins are configured (1 - 6)
	// C. how many data bytes have been received (1 - 6)
	//and the smallest result will be used (safety measure)
	if (numPWM < pinsToWrite) //is the config amount less than the message size?
	{
		pinsToWrite = numPWM; //use the smaller number
	}
	
	
	if (pinsToWrite > 0) //are any pins configured at all?
	{
		for ( i=0; i < pinsToWrite; i++)
		{
			pwmVals[i] = message[i+MSG_NONDATA_INTS]; //store next PWM value
			analogWrite( pwmPins[i], pwmVals[i] ); //write value to pin
		}
	}
}
*/

void digitalMessage()
{
	if (message[1] != msgRecvID){
	  msgRecvID = message[1]; //this message has been received
	  for ( i = 0; i < 11; i++ ){
		if ( digitalModes[ i ] == 2 ){ // pin is in digital out mode
			digitalWrite( digitalPins[i], message[i+MSG_NONDATA_INTS] ); //write value to pin
		}
	  }
	}
}
/*
	int pinsToWrite = msgSize - MSG_NONDATA_INTS; //message size minus node ID and message ID gives # of digital values in message
	//we will write between 0 and 11 digital values, depending on
	// A. whether the Digita pins are configured at all (0)
	// B. how many Digital pins are configured (1 - 6)
	// C. how many data bytes have been received (1 - 6)
	//and the smallest result will be used (safety measure)
	if (numDigi < pinsToWrite) //is the config amount less than the message size?
	{
		pinsToWrite = numDigi; //use the smaller number
	}

	if (pinsToWrite > 0) //are any pins configured at all?
	{
		for ( i=0; i < pinsToWrite; i++)
		{
			if (digitalPins[i] > 0) //collided pins ignored
			{
				digitalWrite( digitalPins[i] + 2, message[i+MSG_NONDATA_INTS] ); //write value to pin
			}
		}
	}
}
*/

/* old function, no longer used. --- Joseph Thibodeau 2010.02.09
void readByte(){
  incoming = Serial.read();
    if ( escape > 0 ){ // escape set
      if ( incoming == escapeChar ){ // escape to integer
        if ( msgtype == 'l' ){
  //         digitalWrite( 6, 1 );
           if ( bytenr > 0 ){ // past ID
              if ( setlights == 1 ){ // if for this device
               pwmVals[bytenr-1] = incoming; // set the lighvalue
              }
           } else {
               if ( incoming == ID ){ // if for this device
                 setlights = 1;
               }
             }
            bytenr++; // increment bytenr
          }
        } else { // escape to char
          if ( incoming == 'l' ){
             msgtype = 'l';
//             digitalWrite( 6, 1 );
          }         
       }
       escape = 0;
    } else { // escape not set
      if ( incoming == escapeChar ){
        escape = 1;
      }
      else if ( incoming == delimiterChar ){ // EOM
         bytenr = 0;
         msgtype = 'n';
         if ( setlights > 0 ){
 //           digitalWrite( 5, 1 );
            // light data message:
            for ( i=0; i<numPWM; i++) {
/*                if ( pwmVals[i] > 0 ) {
                  digitalWrite( pwmPins[i], 1 );
                } else {
                  digitalWrite( pwmPins[i], 0 );
                }

// writing the value anew seems to do something weird to the phase, so don't write if it has already been set to this value
//                if ( pwmVals[i] != prevVals[i] ){
                    analogWrite( pwmPins[i], pwmVals[i] );
                    prevVals[i] = pwmVals[i];
//                }

              }
            setlights = 0;
          }
      }
      else if ( msgtype == 'l' ){
 //       digitalWrite( 6, 1 );
        if ( bytenr > 0 ){ // past ID
           if ( setlights == 1 ){ // if for this device
               pwmVals[bytenr-1] = incoming; // set the lighvalue
              }
           } else {
             if ( incoming == ID ){ // if for this device
               setlights = 1;
//               digitalWrite( 5, 1 );               
             }
           }
        bytenr++; // increment bytenr            
      }
    }
}
*/

///============= Humidity / temperature sensor ==============

//--[ Subroutines ]---------------------------------------------------
void SHT_Write_Byte(void) {
//--------------------------------------------------------------------
  pinMode(shtData, OUTPUT);
  shiftOut(shtData, shtClk, MSBFIRST, ioByte);
  pinMode(shtData, INPUT);
  digitalWrite(shtData, LOW);
  digitalWrite(shtClk, LOW);
  digitalWrite(shtClk, HIGH);
  ackBit = digitalRead(shtData);
  digitalWrite(shtClk, LOW);
}

int SHT_shiftIn() {
  int cwt;
  cwt=0;
  bitmask=128;
  while (bitmask >= 1) {
    digitalWrite(shtClk, HIGH);
    cwt = cwt + bitmask * digitalRead(shtData);
    digitalWrite(shtClk, LOW);
    bitmask=bitmask/2;
  }
  return(cwt);
}

//--------------------------------------------------------------------
void SHT_Read_Byte(void) {
//--------------------------------------------------------------------  
  ioByte = SHT_shiftIn();
  digitalWrite(shtData, ackBit);
  pinMode(shtData, OUTPUT);
  digitalWrite(shtClk, HIGH);
  digitalWrite(shtClk, LOW);
  pinMode(shtData, INPUT);
  digitalWrite(shtData, LOW);
}
//--------------------------------------------------------------------
void SHT_Start(void) {
//--------------------------------------------------------------------
// generates a sensirion specific transmission start
// This where Sensirion is not following the I2C standard
//       _____         ________
// DATA:      |_______|
//           ___     ___
// SCK : ___|   |___|   |______

  digitalWrite(shtData, HIGH);     // Data pin high
  pinMode(shtData, OUTPUT);
  digitalWrite(shtClk,  HIGH);     // clock high
  digitalWrite(shtData,  LOW);     // data low
  digitalWrite(shtClk,   LOW);     // clock low
  digitalWrite(shtClk,  HIGH);     // clock high
  digitalWrite(shtData, HIGH);     // data high
  digitalWrite(shtClk,  LOW);      // clock low
}


//--------------------------------------------------------------------
void SHT_Connection_Reset(void) {
//--------------------------------------------------------------------  
// connection reset: DATA-line=1 and at least 9 SCK cycles followed by start
// 16 is greater than 9 so do it twice
//      _____________________________________________________         ________
// DATA:                                                     |_______|
//          _    _    _    _    _    _    _    _    _        ___    ___
// SCK : __| |__| |__| |__| |__| |__| |__| |__| |__| |______|   |__|   |______

  shiftOut(shtData, shtClk, LSBFIRST, 0xff);
  shiftOut(shtData, shtClk, LSBFIRST, 0xff);
  SHT_Start();
  
}

//--------------------------------------------------------------------
void SHT_Soft_Reset(void) {
//--------------------------------------------------------------------
  SHT_Connection_Reset();
  
  ioByte = RST_CMD;
  ackBit = 1;
  SHT_Write_Byte();
  delay(15);
}

//--------------------------------------------------------------------
void SHT_Wait(void) {
//--------------------------------------------------------------------
// Waits for SHT to complete conversion
  delay(5);
  dly = 0;
  while (dly < 600) {
    if (digitalRead(shtData) == 0) dly=2600;
    delay(1);
    dly=dly+1;
  }
}



//--------------------------------------------------------------------
void SHT_Measure(int SHT_CMD) {
//--------------------------------------------------------------------
  SHT_Soft_Reset();
  SHT_Start();
   ioByte = SHT_CMD;
  
  SHT_Write_Byte();          // Issue Command
  SHT_Wait();                // wait for data ready
   ackBit = 0;               // read first byte
  
  SHT_Read_Byte();
  int msby;                  // process it as Most Significant Byte (MSB)
   msby = ioByte;
   ackBit = 1;
   
   // most signficant byte
//   msb = (byte) ioByte;

  SHT_Read_Byte();          // read second byte

   // least signficant byte   
//   lsb = (byte) ioByte;
   
   retVal = msby;           // process result to combine MSB with LSB
   retVal = retVal * 0x100;
   retVal = retVal + ioByte;
   if (retVal <= 0) retVal = 1;
}

//--------------------------------------------------------------------
int SHT_Get_Status(void) {
//--------------------------------------------------------------------
  SHT_Soft_Reset();
  SHT_Start();
   ioByte = R_STAT;
  
  SHT_Write_Byte();
  SHT_Wait();
   ackBit = 1;
 
  SHT_Read_Byte();
  return(ioByte);
}



/*
/// Adjustments calculated in SC instead

//--------------------------------------------------------------------
int SHT_calc_tempC( float w_temperature)
//--------------------------------------------------------------------
{
// calculate temp with float

float temp1;

// Per the data sheet, these are adjustments to results
temp1 = w_temperature * 0.01;  // divide by 100
temp1 = temp1 - (int)40;       // Subtract 40
return (temp1);
} 

//--------------------------------------------------------------------
int SHT_calc_tempF( int w_temperature) {
//--------------------------------------------------------------------
// calculate temp with float
int temp1;
  temp1 = w_temperature * 0.018;
  temp1 = temp1 - (int)40;
 return (temp1);
} 

//--------------------------------------------------------------------
float calc_dewpoint(float h,float t)
//--------------------------------------------------------------------
// calculates dew point
// input:   humidity [%RH], temperature [�C]
// output:  dew point [�C]
{ float logEx,dew_point;
  logEx=0.66077+7.5*t/(237.3+t)+(log10(h)-2);
  dew_point = (logEx - 0.66077)*237.3/(0.66077+7.5-logEx);
  return dew_point;
}

*/

