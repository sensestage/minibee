#ifndef MiniBee_h
#define MiniBee_h

#define MINIBEE_REVISION 'A'
#define MINIBEE_LIBVERSION 1

/// all together: 3644 bytes
#define MINIBEE_ENABLE_TWI 1  /// TWI takes up 2064 bytes
#define MINIBEE_ENABLE_SHT 1  /// SHT takes up 1140 bytes
#define MINIBEE_ENABLE_PING 1 /// Ping takes up 440 bytes

// #include <avr/interrupt.h>
#include <avr/eeprom.h>
#include <inttypes.h>
#include <WProgram.h>
// #include <EEPROM.h>
// #include <Wire.h>

#ifndef MINIBEE_REVISION
#define MINIBEE_REVISION 'A'
#endif

#ifndef MINIBEE_ENABLE_TWI
#define MINIBEE_ENABLE_TWI 1
#endif

#ifndef MINIBEE_ENABLE_SHT
#define MINIBEE_ENABLE_SHT 1
#endif

#ifndef MINIBEE_ENABLE_PING
#define MINIBEE_ENABLE_PING 1
#endif

enum MiniBeePinConfig { 
  NotUsed,
  DigitalIn, DigitalOut,
  AnalogIn, AnalogOut, AnalogIn10bit, 
  SHTClock, SHTData, 
  TWIClock, TWIData,
  Ping,
  Custom = 100,
  UnConfigured = 200
};

// extern "C" {
//  	void PCINT0_vect(void) __attribute__ ((signal));
//  	void USART_RX_vect(void) __attribute__ ((signal));
// }

class MiniBee {
	public:
		MiniBee();	//constructor

		void (*customMsgFunc)(char *);// = NULL;
		void (*dataMsgFunc)(char *);// = NULL;
		
// 		void ParseCustom( char * msg ){ Serial.println( msg ); };
		
		void begin(int); //init function
		void doLoopStep(void); // loop function

		void setCustomPins( uint8_t * ids, uint8_t * sizes, uint8_t n ); // sets pins to custom configuration
		void setCustomPin( uint8_t id, uint8_t size ); // sets a pin to custom configuration
		void setCustomInput( uint8_t noInputs, uint8_t size );
		void addCustomData( uint8_t * cdata );
		void addCustomData( int * cdata );
		void setCustomCall( void (*customFunc)(char * ) );

		void setDataCall( void (*dataFunc)(char * ) );

		void readXBeeSerial(void);
		
		void openSerial(int);
		void configXBee();

		void readConfigMsg(char *); // assign config from msg
		void setID( uint8_t id );

	//AT CMD (communicate with XBee)
		int atEnter(void);
		int atExit(void);
		int atSet(char *, uint8_t);
		char* atGet(char *);

	// serial communication with network
		void send(char, char *, int);
		void read(void);

	// set output pins
		void setRunning( uint8_t ); 
		void setLoopback( uint8_t ); 
//		void setPWM();
//		void setDigital();
		void setOutput();
		void setOutputValues( char * msg, uint8_t offset );
	
	// read input pins
		uint8_t readSensors( uint8_t );
	
	// send data
		void sendData( void );

		uint8_t getId(void);
		void sendSerialNumber(void);
// 		void waitForConfig(void); // waits for the configuration message
// 		void configure(void);	//configure from eeprom settings

	//twi
		bool getFlagTWI();	//returns twi flag state
#if MINIBEE_ENABLE_TWI == 1
		void setupTWI(void);	//setup function for TWI
		int readTWI(int, int);	//address, number of bytes;
		int readTWI(int, int, int);	//address, register, number of bytes

		void setupAccelleroTWI();
		void readAccelleroTWI( int address, int dboff );
#endif

#if MINIBEE_ENABLE_SHT == 1
	//sht
		int ioSHT;
		int ackSHT;
		int valSHT; 
		bool getFlagSHT();	//returns sht flag state
		uint8_t *getPinSHT();	//returns the pins used for SHT

// 		void setupSHT(int*);	//setup function for SHT
		void setupSHT();	//setup function for SHT
		void startSHT(void);
		void resetSHT(void);
		void softResetSHT(void);
		void waitSHT(void);
		void measureSHT(int cmd);
		void writeByteSHT(void);
		void readByteSHT(void);
		int getStatusSHT(void);
		int shiftInSHT(void);
#endif

#if MINIBEE_ENABLE_PING == 1
	//ping
		bool getFlagPing();	//returns ping flag state
		uint8_t getPinPing();	//returns the pins used for Ping
// 		void setupPing(int*);	//setup function for Ping
		int readPing(void);
#endif

		//listener function
// 		void setupDigitalEvent(void (*event)(int, int));	//attach digital pin listener
// 		void digitalEvent(int pin, int state);	//digital pin event function (add it to the arduino sketch to receive the data)
// 		void attachSerialEvent(void (*event)(void));
// 		void SerialEvent(void);

	private:
		#define CONFIG_BYTES 23
		#define MAX_MESSAGE_SIZE 26
		#define XBEE_SLEEP_PIN 2
		#define AT_OK 167
		#define AT_ERROR 407
//  		#define AT_AT "AT"
// 		char * at_AT[3] = "AT";
// 		#define AT_ENTER "+++"
// 		#define AT_EXIT "CN"
		#define XBEE_SER 8
		#define DEST_ADDR "1"
		#define ESC_CHAR '\\' 
		#define DEL_CHAR '\n'
		#define CR '\r'
		
		#define S_NO_MSG '0'
		//server message types
//		#define S_PWM 'P'
//		#define S_DIGI 'D'
		#define S_OUT 'O'
		#define S_RUN 'R'
		#define S_LOOP 'L'
		#define S_ANN 'A'
		#define S_QUIT 'Q'
		#define S_ID 'I'
		#define S_CONFIG 'C'
		#define S_CUSTOM 'E'
// 		#define S_FULL 'a'
// 		#define S_LIGHT 'l'
		
		//node message types
		#define N_DATA 'd'
		#define N_SER 's'
		#define N_INFO 'i'
		#define N_WAIT 'w'
		#define N_CONF 'c'
		
		uint8_t i;
		uint8_t byte_index;
		uint8_t escaping;
		uint8_t node_id;
		uint8_t config_id;
		uint8_t prev_conf_msg;
		uint8_t prev_id_msg;
		uint8_t prev_msg;
		char incoming;
		char msg_type;

		uint8_t status;
		
		bool loopback;

		char *serial;
// 		char *dest_addr;
// 		char *my_addr;

		// incoming message
		char *message;

		int msgInterval;
		uint8_t samplesPerMsg;
		uint8_t msg_id_send;
		
		uint8_t curSample;
		int smpInterval;
		char *outMessage;

	//AT private commands
		int atGetStatus(void);
		void atSend(char *);
		void atSend(char *, uint8_t);

	//msg with network
		void slip(char);
// 		void slipSoft(char);
		bool checkNodeMsg( uint8_t nid, uint8_t mid );
		bool checkNotNodeMsg( uint8_t nid );
		bool checkConfMsg( uint8_t mid );
		bool checkIDMsg( uint8_t mid );
		void routeMsg(char, char*, uint8_t);

	//config 
		char *config; //array of pointers for all the config bytes
		void writeConfig(char *); // eeprom write
		void readConfig(void); // eeprom read
		void parseConfig(void); // parse the config

	// collecting sensor data:
		void dataFromInt( int output, int offset );
		char *data;
		int datacount;

		bool twiOn;

#if MINIBEE_ENABLE_SHT == 1
		uint8_t mask;
		bool shtOn;
		uint8_t sht_pins[2];	//scl, sda  clock, data
#endif

#if MINIBEE_ENABLE_PING == 1
		bool pingOn;
		uint8_t ping_pin;	//ping pins (these could be more, but not right now)
#endif

		bool analog_in[8]; // sets whether analog in on 
		bool analog_precision[8]; // sets whether analog 10 bit precision is on or not

		bool pwm_on[6]; // sets whether pwm pin is on or not
		static uint8_t pwm_pins[]; // = { 3,5,6, 8,9,10 };
		uint8_t pwm_values[6]; // = {0,0,0, 0,0,0};
		
		bool digital_out[19]; // sets whether digital out on
		uint8_t digital_values[19];

		bool digital_in[19]; // sets whether digital in on

		bool custom_pin[19]; // sets whether custom pin is configured
		uint8_t custom_size[19]; // sets size of custom pin data
		uint8_t customDataSize;

		#define PINOFFSET 3
		#define ANAOFFSET 11

#if MINIBEE_ENABLE_TWI == 1
	// LIS302DL accelerometer addresses
		#define accel1Address 0x1C
		#define accelResultX 0x29
		#define accelResultY 0x2B
		#define accelResultZ 0x2D
#endif

#if MINIBEE_ENABLE_SHT == 1
	// SHT sensor - See Sensirion Data sheet
		#define  SHT_T_CMD  0x03                
		#define  SHT_H_CMD  0x05
		#define  SHT_R_STAT 0x07
		#define  SHT_W_STAT 0x06
		#define  SHT_RST_CMD 0x1E
#endif

	// state machine for the MiniBee...
		#define STARTING 0
		#define SENSING 1
		#define WAITFORHOST 2
		#define WAITFORCONFIG 3
		#define ACTING 4
		#define PAUSING 5

	bool hasInput; // = false;
	bool hasOutput; // = false;
	bool hasCustom; // = false;

	uint8_t customInputs;
	uint8_t customSize;

// 	//listener functions
// 		void digitalUpdate(int pin, int status);	//function used to update digitalEvent
// 		friend void PCINT0_vect(void);	//interrupt vector
// 		void (*dEvent)(int, int);	//event listener being passed to listner functions
// 		
// 		void serialUpdate(void);
// 		void (*sEvent)(void);
// 		friend void USART_RX_vect(void);
// 	static void customMsgFuncWrapper( void* mb, char* msg );
};

// extern MiniBee Bee;	

#endif	
