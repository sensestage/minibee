/// Wire needs to be included if TWI is enabled
#include <Wire.h>
/// in the header file of the MiniBee you can disable some options to save
/// space on the MiniBee. If you don't the board may not work as it runs
/// out of RAM.
#include <MiniBee.h>

/// in our example we are using the capacitive sensing library to use sensors
/// not supported by default in our library
#include <CapSense.h>

MiniBee Bee = MiniBee();

  int xclr=8;
  int mclck=3;

  int eepromAddress=0x50; // 0xA1;// 
  int pressTempAddress=0x77; //0xEF;// 
  
  int compassAddress=B0110000;// [0110xx0] [xx] is determined by factory programming, total 4 different addresses are available
  
  word rawTemp, rawPressure;
  
  // keep these in order
  int temp, pres;
  int xCorr2, yCorr2;
  int rangeX, rangeY;
  
  int xCorr, yCorr;
  
  
  // keep these in order:
  int xParam,yParam;
  int minX=1900; // default start minimum
  int maxX=2150; // default start maximum
  int minY=1900;
  int maxY=2150;
  int centerX, centerY;
  
  
//  byte calibData[18];

    // keep following fields in order:
    word C1, C2, C3, C4, C5, C6, C7;
    byte A, B, C, D;

void customMsgParser( char * msg ){
     if ( msg[2] == 'A' ){ // request for calibration data
         Bee.send( N_INFO, (char*) &C1, 18 );
     }
     if ( msg[2] == 'B' ){ // request for compass calibration data
         Bee.send( N_INFO, (char*) &xParam , 16*2 );
     }
}

void setup() {
  Bee.begin(19200);

  // define which pins we will be using for our custom functionality:
  // arguments are: pin number, size of data they will produce (in bytes)
  /// in our case we use pin 10 (no data)
  /// and pins 11, 12, and 13, each 2 bytes, as we are going to send integers
  
  uint8_t cpins []  = {xclr, mclck, ANAOFFSET+4, ANAOFFSET+5};//, 0,0,0,0, 0,0,0,0, 0,0,0,0};
  uint8_t csizes [] = {0,0,0,0};// , 1,1,1,1, 1,1,1,1, 1,1,1,1};

  Bee.setCustomPins( cpins, csizes, 4 );
  
  Bee.setCustomInput( 6, 2 );
  
  // set the custom message function
  Bee.setCustomCall( &customMsgParser );
  
  Wire.begin();
  delay (20);

  setupCompass();
  delay( 20 );
  setupPressureTemp();  
  delay( 20 );
}

void setupPressureTemp(){
  pinMode(xclr, OUTPUT);
//  digitalWrite(xclr, HIGH);

  pinMode(mclck, OUTPUT);
  digitalWrite(mclck, LOW);

 // setup of the mclock
  // generate 32768 Hz on IRQ pin (OC2B)
  TCCR2A = bit(COM2B0) | bit(WGM21);
  TCCR2B = bit(CS20);
  OCR2A = 243;

  delay( 100 );
  readCalibration();
}

void readCalibration(){
    digitalWrite( xclr, LOW );
    delay(5);
    for (byte i = 0; i < 18; ++i){
//        calib[i] = 
        ((byte*) &C1)[i < 14 ? i^1 : i] = readEepromByte(16 + i);
    }
}

byte readEepromByte(byte wordaddress) {
  byte result;
  int i;
    Wire.beginTransmission(eepromAddress);
    Wire.send(wordaddress);
    Wire.endTransmission();//RESTART OBLIGATORY
    Wire.requestFrom(eepromAddress, 1);
    if(Wire.available()) {
	result = Wire.receive();
    }
    Wire.endTransmission();
  return result;
}

word getADCPT(byte press){
  byte rcvByte[2];

  digitalWrite( xclr, HIGH );  
  delay( 10 );

  Wire.beginTransmission(pressTempAddress);
  // pressure
  //Send target (master)address
//  Wire.send(0xFF);
  Wire.send(0xFF);
  if ( press == 1 )
    Wire.send(0xF0 );
  else
    Wire.send(0xE8 );
  Wire.endTransmission();
  
  delay(45); // as told to on the data sheet

  Wire.beginTransmission(pressTempAddress);
//  Wire.send(0xEE);
  Wire.send(0xFD);
//  Wire.send(0xEF);
  Wire.endTransmission();
  delay(2);
  
  Wire.requestFrom(pressTempAddress, 2);
  for (int i=0;i<2;i++){
    rcvByte[i]=0;
    rcvByte[i] = Wire.receive();
  }
//  Wire.endTransmission();

  word result = ( rcvByte[0] << 8 ) | rcvByte[1];
  delay( 10 );
//  digitalWrite( xclr, LOW );
  return result;
}

void getPressTemp( boolean debug=false ){


    rawPressure = getADCPT( 1 );
    rawTemp = getADCPT( 0 );
      
    int corr = (rawPressure - C5) >> 7;
    int dUT  = (rawPressure - C5) - (corr * (long) corr * (rawPressure >= C5 ? A : B) >> C);
    int OFF = (C2 + ((C4 - 1024) * dUT >> 14)) << 2;
    int SENS = C1 + (C3 * dUT >> 10);
    int X = (SENS * (rawTemp - 7168L) >> 14) - OFF;

    temp = (250 + (dUT * C6 >> 16) - (dUT >> D)); 
    pres = ((X * 10L >> 5) + C7);

    /*
    if ( debug ){
      Serial.print("corr = ");
      Serial.print(corr);
      Serial.print(", dUT = ");
      Serial.print(dUT);
      Serial.print(", OFF = ");
      Serial.print(OFF);
      Serial.print(", SENS = ");
      Serial.print(SENS);
      Serial.print(", X = ");
      Serial.print(X);
    }
    */
}

void setupCompass(){
  Wire.beginTransmission(compassAddress);
  //Send target (master)address
  Wire.send(0x00);
  //Wake up call, send SET signal to set/reset coil
  Wire.send(0x02);
  Wire.endTransmission();
// wait for SET action to settle
  delay(10);  
}

void getCompassData(){
  byte rcvByte[4];
   Wire.beginTransmission(compassAddress);
  //Send target (master)address
  Wire.send(0x00);
  //Wake up call, request for data
  Wire.send(0x01);
  Wire.endTransmission();
//      wait 5ms min for compass to acquire data
  delay(7);
  Wire.requestFrom(compassAddress, 4);
  for (int i=0;i<4;i++){
    rcvByte[i]=0;
    rcvByte[i] = Wire.receive();
  }
  xParam =  rcvByte[0] << 8;
  xParam= xParam | rcvByte[1];
  yParam  = rcvByte[2] << 8;
  yParam= yParam | rcvByte[3];
}

/*
void printCalibration(){
  Serial.print( C1 );
  Serial.print( "," );
  Serial.print( C2 );
  Serial.print( "," );
  Serial.print( C3 );
  Serial.print( "," );
  Serial.print( C4 );
  Serial.print( "," );
  Serial.print( C5 );
  Serial.print( "," );
  Serial.print( C6 );
  Serial.print( "," );
  Serial.print( C7 );
  Serial.print( "," );
  Serial.print( (word) A );
  Serial.print( "," );
  Serial.print( (word) B );
  Serial.print( "," );
  Serial.print( (word) C );
  Serial.print( "," );
  Serial.print( (word) D );
}
*/

void convertCompassData(){
//by rotating compass, we'll eventually get the extreme values for x and y
  //North (real)  (x,y)=(2055,2129)

  if (xParam>maxX){
    maxX=xParam;
  } else if (minX==0){
    minX=xParam;
  } else if (xParam<minX){
    minX=xParam;
  }
  if (yParam>maxY){
    maxY=yParam;
  } else if (minY==0){
    minY=yParam;
  } else if (yParam<minY){
    minY=yParam;
  }
  rangeX = (maxX - minX)/2;
  rangeY = (maxY - minY)/2;
  centerX = minX + rangeX;
  centerY = minY + rangeY;
  xCorr = (xParam - centerX)*100/rangeX;
  yCorr = (yParam - centerY)*100/rangeY;
  xCorr2 = xCorr + rangeX;
  xCorr2 = yCorr + rangeY;
}

/*
void printCompass( boolean detail=false ){
  Serial.print ("(");
  Serial.print (xCorr);
  Serial.print (",");
  Serial.print (yCorr);
  Serial.print (")");


//  if ( abs(yCorr) < 10 && (xCorr > 10 ) ){
//     Serial.print( "N" ); 
//  }
//  if ( abs(yCorr) < 10 && (xCorr < -10 ) ){
//     Serial.print( "S" ); 
//  }
//  if ( abs(xCorr) < 10 && (yCorr < -10 ) ){
//     Serial.print( "W" ); 
//  }
//  if ( abs(xCorr) < 10 && (yCorr > 10 ) ){
//     Serial.print( "E" ); 
//  }
  
  if ( detail ){
    Serial.print (",(");
    Serial.print (xParam);
    Serial.print (",");
    Serial.print (yParam);
    Serial.print (")");
    Serial.print (" Extremes: x(");
    Serial.print (minX);
    Serial.print (",");
    Serial.print (centerX);
    Serial.print (",");
    Serial.print (maxX);
    Serial.print (",");
    Serial.print (rangeX);
    Serial.print (") y(");
    Serial.print (minY);
    Serial.print (",");
    Serial.print (centerY);
    Serial.print (",");
    Serial.print (maxY);
    Serial.print (",");
    Serial.print (rangeY);
    Serial.print (")");
  }
}
*/
/*
void printPressTemp( boolean raw=false, boolean calib=false ){
  Serial.print ("T:");
  Serial.print( temp );
  Serial.print (", P:");
  Serial.print( pres );
  if ( raw ){
    Serial.print (", rawT:");
    Serial.print( rawTemp );
    Serial.print (", rawP:");
    Serial.print( rawPressure );
  }
  if ( calib ){
     Serial.print( "   " );
     printCalibration(); 
  }
}
*/

void loop() {
  /// do our measurements
  getCompassData();
  convertCompassData();
  getPressTemp();
  
  // add our customly measured data to the data package:
  Bee.addCustomData( &temp, 6 );
  // do a loop step of the remaining firmware:
  Bee.doLoopStep();
}
