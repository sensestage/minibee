#include <Wire.h>
#include <MiniBee.h>
#include <NewSoftSerial.h>


#define SoftRX 12
#define SoftTX 13

// NewSoftSerial softSerial;

NewSoftSerial softSerial(SoftRX, SoftTX);

void initSoftSerial( int baud_rate ){
//   // define pin modes for tx, rx, led pins:
//    softSerial =  
//    pinMode(SoftRX, INPUT);
//    pinMode(SoftTX, OUTPUT);
   // set the data rate for the SoftwareSerial port
   softSerial.begin(baud_rate);
}

void sendSoft(char type, char *p) {
  int i;
 	softSerial.print(ESC_CHAR, BYTE);
 	softSerial.print(type, BYTE);
 	for(i = 0;i < strlen(p);i++) slipSoft(p[i]);
 	softSerial.print(DEL_CHAR, BYTE);

}

void slipSoft(char c) {
 	if((c == ESC_CHAR) || (c == DEL_CHAR) || (c == CR))
 	    softSerial.print(ESC_CHAR, BYTE);
 	softSerial.print(c, BYTE);
}

char sz[8];

void setup() {
//     char *response;// = (char *)malloc(sizeof(char)*6);
//     char *response2;// = (char *)malloc(sizeof(char)*8);
    
// 	initSoftSerial( 19200 );

//  	softSerial.print( '\\' );
//  	softSerial.print( 'a' );
//  	softSerial.print( '\n' );

// 	sendSoft( N_SER, "13A200402D0BD7" );

// 	sendSoft(N_SER, Bee.serial);

	Bee.begin(19200);

	
// 	sendSoft(N_SER, Bee.serial);

// 	sprintf(sz,"%d",strlen(Bee.serial));

// 	sendSoft(N_INFO, sz );

// 	delay(500);
	
// 	Bee.atEnter();
// 	response = Bee.atGet( "SH" );
// 	response2 = Bee.atGet( "SL" );
// 	Bee.atExit();  
// 
// 	sendSoft( N_SER, strcat( response, response2) );
// 	free( response );
// 	free( response2 );

}

void loop() {
  Bee.doLoopStep();

//    sprintf(sz,"%d",Bee.status );
//    sendSoft(N_INFO, sz );

//   delay( 100 );
}
