#ifndef MiniBee_h
#define MiniBee_h

#include <avr/interrupt.h>
#include <avr/eeprom.h>
#include <inttypes.h>
#include <WProgram.h>
#include "../Wire/Wire.h"

extern "C" {
	void PCINT0_vect(void) __attribute__ ((signal));
	void USART_RX_vect(void) __attribute__ ((signal));
}

class MiniBee {
	public:
		MiniBee();	//constructor

		//AT CMD
		int atEnter(void);
		int atExit(void);
		char* atGet(char *);
		int atSet(char *, uint8_t);
		
		void send(char, char *);
		void read(void);

		void begin(int); //init function
		void configure(void);	//configure from eeprom settings
		uint8_t getId(void);
		
		//twi
		boolean getFlagTWI();	//returns twi flag state
		void setupTWI(void);	//setup function for TWI
		int readTWI(int, int);	//address, number of bytes;
		int readTWI(int, int, int);	//address, register, number of bytes
		
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
		#define CONFIG_BYTES 4
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
		#define S_FULL 'a'
		#define S_LIGHT 'l'
		
		//node message types
		#define N_DATA 'd'
		#define N_SER 's'
		
		uint8_t mask;
		uint8_t i;
		uint8_t byte_index;
		uint8_t escaping;
		uint8_t id;
		uint8_t prev_msg;
		char incoming;
		char msg_type;
		char *serial;
		char *dest_addr;
		char *message;
		
		//at commands
		void atSend(char *);
		void atSend(char *, uint8_t);
		int atGetStatus(void);
		
		//msg
		void routeMsg(char, char*);
		void slip(char);
		
		//config 
		char *config; //array of pointers for all the config bytes
		int sht_pins[2];	//scl, sda
		int ping_pins[4];	//ping pins
		void writeConfig(char *);
		void readConfig(void);
		
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
	