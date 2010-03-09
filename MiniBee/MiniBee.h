#ifndef MiniBee_h
#define MiniBee_h

#include <avr/interrupt.h>
#include <avr/eeprom.h>
#include <inttypes.h>
#include <WProgram.h>
#include "../Wire/Wire.h"

enum MiniBeePinConfig { 
  NotUsed,
  DigitalIn, DigitalOut,
  AnalogIn, AnalogOut, AnalogIn10bit, 
  SHTClock, SHTData, 
  TWIClock, TWIData,
  Ping
}

extern "C" {
	void PCINT0_vect(void) __attribute__ ((signal));
	void USART_RX_vect(void) __attribute__ ((signal));
}

class MiniBee {
	public:
		MiniBee();	//constructor

		void begin(int); //init function
		void doLoopStep(void); // loop function
		
	//AT CMD (communicate with XBee)
		int atEnter(void);
		int atExit(void);
		int atSet(char *, uint8_t);
		char* atGet(char *);

	// serial communication with network
		void send(char, char *);
		void read(void);

	// set output pins
		void setPWM();
		void setDigital();
	
	// read input pins
		void readSensors( uint8_t );
	
	// send data
		void sendData( void );

		uint8_t getId(void);
		void sendSerialNumber(void);
		void waitForConfig(void); // waits for the configuration message
// 		void configure(void);	//configure from eeprom settings

	//twi
		boolean getFlagTWI();	//returns twi flag state
		void setupTWI(void);	//setup function for TWI
		int readTWI(int, int);	//address, number of bytes;
		int readTWI(int, int, int);	//address, register, number of bytes

		void setupAcceleroTWI();
		void readAcceleroTWI( int address, int dboff );

	//sht
		int ioSHT;
		int ackSHT;
		int valSHT; 
		boolean getFlagSHT();	//returns sht flag state
		int *getPinSHT();	//returns the pins used for SHT
		void setupSHT(int*);	//setup function for SHT
		void startSHT(void);
		void resetSHT(void);
		void softResetSHT(void);
		void waitSHT(void);
		void measureSHT(int cmd);
		void writeByteSHT(void);
		void readByteSHT(void);
		int getStatusSHT(void);
		int shiftInSHT(void);
		
	//ping
		boolean getFlagPing();	//returns ping flag state
		int *getPinPing();	//returns the pins used for Ping
		void setupPing(int*);	//setup function for Ping
		int readPing(void);
			
		//listener function
		void setupDigitalEvent(void (*event)(int, int));	//attach digital pin listener
		void digitalEvent(int pin, int state);	//digital pin event function (add it to the arduino sketch to receive the data)
		void attachSerialEvent(void (*event)(void));
		void SerialEvent(void);
	
	private:
		#define CONFIG_BYTES 22
		#define XBEE_SLEEP_PIN 2
		#define AT_OK 167
		#define AT_ERROR 407
		#define XBEE_SER 8
		#define DEST_ADDR "1"
		#define ESC_CHAR '\\' 
		#define DEL_CHAR '\n'
		#define CR '\r'
		
		//server message types
		#define S_PWM 'P'
		#define S_DIGI 'D'
		#define S_ANN 'A'
		#define S_QUIT 'Q'
		#define S_ID 'I'
		#define S_CONFIG 'C'
// 		#define S_FULL 'a'
// 		#define S_LIGHT 'l'
		
		//node message types
		#define N_DATA 'd'
		#define N_SER 's'
		
		uint8_t mask;
		uint8_t i;
		uint8_t byte_index;
		uint8_t escaping;
		uint8_t id;
		uint8_t config_id;
		uint8_t prev_msg;
		char incoming;
		char msg_type;
		char *serial;
		char *dest_addr;
		char *message;

		int msgInterval;
		int samplesPerMsg;
		uint8_t msg_id_send;
		
		int curSample;
		int smpInterval;
		char *outMessage;


		boolean shtOn;
		boolean twiOn;
		boolean pingOn;
		
	//AT private commands
		int atGetStatus(void);
		void atSend(char *);
		void atSend(char *, uint8_t);
		
	//msg with network
		void slip(char);
		boolean checkNodeMsg( uint8_t nid, uint8_t mid );
		boolean checkMsg( uint8_t mid );
		void routeMsg(char, char*, uint8_t);
		
	//config 
		char *config; //array of pointers for all the config bytes
		void writeConfig(char *);
		void readConfig(void);

	// collecting sensor data:
		void dataFromInt( int output, int offset );
		char *data;
		int datacount;

		int sht_pins[2];	//scl, sda  clock, data
		int ping_pin;	//ping pins

		boolean analog_in[8]; // sets whether analog in on 
		boolean analog_precision[8]; // sets whether analog 10 bit precision is on or not

		boolean pwm_on[6]; // sets whether pwm pin is on or not
		uint8_t pwm_pins [] = { 3,5,6, 8,9,10 };
		int pwm_values[] = {0,0,0, 0,0,0};
		
		boolean digital_out[19]; // sets whether digital out on
		int digital_values[19];

		boolean digital_in[19]; // sets whether digital in on
		
	// LIS302DL accelerometer addresses
		#define accel1Address 0x1C
		#define accelResultX 0x29
		#define accelResultY 0x2B
		#define accelResultZ 0x2D

	// SHT sensor - See Sensirion Data sheet
		#define  SHT_T_CMD  0x03                
		#define  SHT_H_CMD  0x05
		#define  SHT_R_STAT 0x07
		#define  SHT_W_STAT 0x06
		#define  SHT_RST_CMD 0x1E


		int status;
		#define STARTING 0
		#define SENSING 1
		#define WAITINGHOST 2
		#define WAITFORCONFIG 3
		

	//listener functions
		void digitalUpdate(int pin, int status);	//function used to update digitalEvent
		friend void PCINT0_vect(void);	//interrupt vector
		void (*dEvent)(int, int);	//event listener being passed to listner functions
		
		void serialUpdate(void);
		void (*sEvent)(void);
		friend void USART_RX_vect(void);
};

extern MiniBee Bee;	

#endif	
