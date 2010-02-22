#include "MiniBee.h"

MiniBee::MiniBee() {
  
	shtOn = false;
	twiOn = false;
	prev_msg = 0;
	
	for ( i = 0; i<8; i++ ){
	    analog_precision[i] = false; // false is 8bit, true is 10bit
	    analog_in[i] = false;
	}
	for ( i = 0; i<19; i++ ){
	    digital_in[i] = false;
	    digital_out[i] = false;
	    digital_values[i] = 0;
	}
	for ( i=0; i<6; i++ ){
	    pwm_on[i] = false;
	    pwm_values[i] = 0;
	}

	//populate whatever xBee properties we'll need.
	atEnter();
	serial = strcat(atGet("SH"), atGet("SL"));
	dest_addr = strcat(atGet("SH"), atGet("SL"));
	if(strcmp(dest_addr, DEST_ADDR) != 0) {	//make sure we're on the default destination address
		atSet("DH", 0);
		atSet("DL", 1);
	}
	atExit();
}

MiniBee Bee = MiniBee();

void MiniBee::begin(int baud_rate) {
	//config array, this should move to the firmware or something?
	//id, twi, sht, ping, sht pins, 
	config = (char*)malloc(sizeof(char) * CONFIG_BYTES);
	
	Serial.begin(baud_rate);
	delay(200);
  	pinMode(XBEE_SLEEP_PIN, OUTPUT);
  	digitalWrite(XBEE_SLEEP_PIN, 0);
	delay(500);
}

//**** Xbee AT Commands ****//
int MiniBee::atGetStatus() {
	incoming = 0;
	int status = 0;
	
	while(incoming != '\r') {
		if(Serial.available()) {
			incoming = Serial.read();
		  	status += incoming;
		}
	}
	
	return status;
}

void MiniBee::atSend(char *c) {
	Serial.print("AT");
	Serial.print(c);
	Serial.print('\r');
}

void MiniBee::atSend(char *c, uint8_t v) {
	Serial.print("AT");
	Serial.print(c);
	Serial.print(v);
	Serial.print('\r');
}

int MiniBee::atEnter() {
	Serial.print("+++");
	return atGetStatus();
}

int MiniBee::atExit() {
	atSend("CN");
	return atGetStatus();
}

int MiniBee::atSet(char *c, uint8_t val) {
	atSend(c);
	return atGetStatus();
}

char* MiniBee::atGet(char *c) {
	char *response = (char *)malloc(sizeof(char)*128);
	incoming = 0;
	i = 0;
	
	while(incoming != '\r') {
		if(Serial.available()) {
			incoming = Serial.read();
		  response[i] = incoming;
			i++;
		}
	}
	
	realloc(response, sizeof(char)*(i-1));
	
	return response;
}

//**** END AT COMMAND STUFF ****//

void MiniBee::send(char type, char *p) {
	slip(ESC_CHAR);
	slip(type);
	for(i = 0;i < strlen(p);i++) slip(p[i]);
	slip(DEL_CHAR);
}

void MiniBee::slip(char c) {
	if((c == ESC_CHAR) || (c == DEL_CHAR) || (c == CR)) Serial.print(ESC_CHAR, BYTE);
	else Serial.print(c, BYTE);
}

void MiniBee::read() {
	incoming = Serial.read();
 	if(escaping) {	//escape set
		if((incoming == ESC_CHAR)  || (incoming == DEL_CHAR) || (incoming == CR)) {	//escape to integer
			message[byte_index] = incoming;
			byte_index++;
		} else {	//escape to char
			msg_type = incoming;
		}
		escaping = false;
	} else {	//escape not set
		if(incoming == ESC_CHAR) {
			escaping = true;
		} else if(incoming == DEL_CHAR) {	//end of msg
			routeMsg(msg_type, message, byte_index);	//route completed message
			byte_index = 0;	//reset buffer index
		} else {
			message[byte_index] = incoming; 
			byte_index++;            
		}
	}
}

boolean MiniBee::checkNodeMsg( uint8_t nid, uint8_t mid ){
	boolean res = ( (nid == id)  && ( mid != prev_msg) );
	prev_msg = mid;
	return res;
}

boolean MiniBee::checkMsg( uint8_t mid ){
	boolean res = ( mid != prev_msg);
	prev_msg = mid;
	return res;
}

void MiniBee::routeMsg(char type, char *msg, uint8_t size) {
	// these messages do not have a 
	switch(type) {
		case S_ANN:
			sendSerialNumber();
// 			configure();
			break;
		case S_QUIT:
			//do something to stop doing anything
			break;
		case S_ID:
			// check for msg ID
			if ( checkMsg( msg[0] ){
			  char ser[8];
			  for(i = 0;i < 8;i++){ ser[i] = msg[i+1]; }
			  if(strcmp(ser, serial) == 0){
			      id = msg[9];	//writeConfig(msg);
			  }
			  if ( size == 11 ){
			      config_id = msg[10];
			      waitForConfig();
			  } else if ( size == 10 ) {
			      readConfig();
			  }
			}
			break;
		case S_CONFIG:
		      // check if right config_id:
		      if ( msg[0] == config_id ){
			writeConfig( msg );
		      }
		case S_PWM:
			if ( checkNodeMsg( msg[0], msg[1] ) ){
			    for( i=0; i<6; i++){
				if ( pwm_on[i] ){
				    pwm_values[i] = msg[2+i];
				}
			    }
			    setPWM();
			}
			break;
		case S_DIGI:
			if ( checkNodeMsg( msg[0], msg[1] ) ){
			    for( i=0; i< (size-2); i++){
				if ( digital_on[i] ){
				    digital_values[i] = msg[2+i];
				}
			    }
			    setDigital();
			}
			break;
		default:
			break;
		}
	}
}

void MiniBee::setPWM(){
	for( i=0; i<6; i++){
	  if ( pwm_on[i] ){
	    analogWrite( pwm_pins[i], pwm_values[i] );
	  }
	} 
}

void MiniBee::setDigital(){
	for( i=0; i<19; i++){
	  if ( digital_on[i] ){
	    digitalWrite( i, digital_values[i] );
	  }
	} 
}

void dataFromInt( int output, int offset ){
  data[offset]   = byte(output/256);
  data[offset+1] = byte(output%256);
}

void MiniBee::readSensors( uint8_t db ){
    int value;
    // read analog sensors
    for ( i = 0; i < 8; i++ ){
      if ( analog_in[i] ){
	    if ( analog_precision[i] ){
		value = analogRead(i);
		dataFromInt( value );
		db += 2;
	    } else {
		data[db] = analogRead(i)/4;
		db++;      
	    }
      }
    }
    // read digital sensors
    for ( i = 0; i < 19; i++ ){
      if ( digital_in[i] ){
	// this can be done way more clever by shifting the results into 3 bytes
	data[db] = digitalRead(i);
	db++;
      }
    }
    // read I2C/two wire interface accelero
    if ( twiOn ){
      
    }
    
    // read SHT sensor
    if ( shtOn ){
      
    }
    
    // read ultrasound sensor
    if ( pingOn ){
      
    }
}

uint8_t MiniBee::getId(void) { 
	return config[0]; 
}

void MiniBee::sendSerialNumber(void){
	send(N_SER, serial);
}  

void MiniBee::waitForConfig(void){
	long timeout = millis();
	while(millis() < timeout + 30000) read();
	// waits 30 seconds for a configuration
}  

void MiniBee::configure(void) {
	send(N_SER, serial);
	long timeout = millis();
	while(millis() < timeout + 5000) read();
	readConfig();
}

void MiniBee::writeConfig(char *msg) {
// 	eeprom_write_byte((uint8_t *) i, id ); // writing id
	for(i = 0;i < CONFIG_BYTES;i++){
	    eeprom_write_byte((uint8_t *) i, msg[i+1]);
	    //write byte to memory
	}
}

void MiniBee::readConfig(void) {
	int datasize = 0;
  
	for(i = 0;i < CONFIG_BYTES;i++) config[i] = eeprom_read_byte((uint8_t *) i);
	
	msgInterval = config[0]*256 + config[1];
	samplesPerMsg = config[2];
	for(i = 3;i < CONFIG_BYTES;i++){
	    switch( config[i] ){
	      case AnalogIn10bit:
		if ( i > 13 ){
		    analog_precision[i-14] = true;
		    analog_in[i-14] = true;
		    pinMode( i, INPUT );
		    datasize += 2;
		}
		break;
	      case AnalogIn:
		if ( i > 13 ){
		    analog_precision[i-14] = false;
		    analog_in[i-14] = true;
		    pinMode( i, INPUT );
		    datasize += 1;
		}
		break;
	      case DigitalIn:
		pinMode( i, INPUT );
		digital_in[i-3] = true;
		datasize += 1;
		break;
	      case AnalogOut:
		for ( int j=0; j < 6; j++ ){
		    if ( pwm_pins[j] == i ){
			pinMode( i, OUTPUT );
			pwm_on[j] = true;
		    }
		}
		break;
	      case DigitalOut:
		digital_out[i-3] = true;
		pinMode( i, OUTPUT );
		break;
	      case SHTClock:
		sht_pins[0] = i;
		shtOn = true;
		pinMode( i, OUTPUT );
		break;
	      case SHTData:
		sht_pins[1] = i;
		shtOn = true;
		pinMode( i, OUTPUT );
		datasize += 4;
		break;
	      case TWIClock:
	      case TWIData:
		twiOn = true;
		datasize += 3;
		break;
	      case Ping:
		pingOn = true;
		ping_pin = i;
		datasize += 2;
		break;
	      case NotUsed:
		break;
	    }
	}
	
	datasize = datasize * samplesPerMsg;
	data = (char*)malloc(sizeof(char) * datasize);
}

//TWI
boolean MiniBee::getFlagTWI(void) { 
	if(config[3] > 0) return true; 
	else return false;
} 

void MiniBee::setupTWI(void) {
	//setup TWI here
}

int MiniBee::readTWI(int address, int bytes) {
	i = 0;
	int twi_reading[bytes];
	Wire.requestFrom(address, bytes);
  	while(Wire.available()) {   
		twi_reading[i] = Wire.receive();
		i++;
	}
	return *twi_reading;
}

//read a specific register on a particular device.
int MiniBee::readTWI(int address, int reg, int bytes) {
	i = 0;
	int twi_reading[bytes];
	Wire.beginTransmission(address);
	Wire.send(reg);                   //set x register
	Wire.endTransmission();
	Wire.requestFrom(address, bytes);            //retrieve x value
  	while(Wire.available()) {   
		twi_reading[i] = Wire.receive();
		i++;
	}
	return *twi_reading;
}

//SHT
boolean MiniBee::getFlagSHT(void) { 
	if(config[2] > 0) return true; 
	else return false;
}
 
int* MiniBee::getPinSHT(void) {
	 return sht_pins; 
}

void MiniBee::setupSHT(int* pins) {
	//pins[0] is scl pins[1] is sda
	*sht_pins = *pins;
	pinMode(sht_pins[0], OUTPUT);
	digitalWrite(sht_pins[0], HIGH);     
	pinMode(sht_pins[1], OUTPUT);   
	startSHT();
}

void MiniBee::startSHT(void) {
	pinMode(sht_pins[1], OUTPUT);
	digitalWrite(sht_pins[1], HIGH);
	digitalWrite(sht_pins[0], HIGH);    
	digitalWrite(sht_pins[1], LOW);
	digitalWrite(sht_pins[0], LOW);
	digitalWrite(sht_pins[0], HIGH);
	digitalWrite(sht_pins[1], HIGH);
	digitalWrite(sht_pins[0], LOW);
}

void MiniBee::resetSHT(void) {
	shiftOut(sht_pins[1], sht_pins[0], LSBFIRST, 0xff);
	shiftOut(sht_pins[1], sht_pins[0], LSBFIRST, 0xff);
	startSHT();
}

void MiniBee::softResetSHT(void) {
	resetSHT();
	ioSHT = 0x1E;
	ackSHT = 1;
	writeByteSHT();
	delay(15);
}

void MiniBee::waitSHT(void) {
	delay(5);
	i = 0;
	while(i < 600) {
		if(digitalRead(sht_pins[1]) == 0) i = 2600;
		delay(1);
		i++;
	}
}

void MiniBee::measureSHT(int cmd) {
	softResetSHT();
	startSHT();
	ioSHT = cmd;

	writeByteSHT();   
	waitSHT();          
	ackSHT = 0;      

	readByteSHT();
	int msby;                  
	msby = ioSHT;
	ackSHT = 1;

	readByteSHT();          
	valSHT = msby;           
	valSHT = valSHT * 0x100;
	valSHT = valSHT + ioSHT;
	if(valSHT <= 0) valSHT = 1;
}

void MiniBee::readByteSHT(void) {
	ioSHT = shiftInSHT();
	digitalWrite(sht_pins[1], ackSHT);
	pinMode(sht_pins[1], OUTPUT);
	digitalWrite(sht_pins[0], HIGH);
	digitalWrite(sht_pins[0], LOW);
	pinMode(sht_pins[1], INPUT);
	digitalWrite(sht_pins[1], LOW);
}

void MiniBee::writeByteSHT(void) {
	pinMode(sht_pins[1], OUTPUT);
	shiftOut(sht_pins[1], sht_pins[0], MSBFIRST, ioSHT);
	pinMode(sht_pins[1], INPUT);
	digitalWrite(sht_pins[1], LOW);
	digitalWrite(sht_pins[0], LOW);
	digitalWrite(sht_pins[0], HIGH);
	ackSHT = digitalRead(sht_pins[1]);
	digitalWrite(sht_pins[0], LOW);
}

int MiniBee::getStatusSHT(void) {
	softResetSHT();
	startSHT();
	ioSHT = 0x07;	//R_STATUS

	writeByteSHT();
	waitSHT();
	ackSHT = 1;

	readByteSHT();
	return ioSHT;
}

int MiniBee::shiftInSHT(void) {
	int cwt = 0;	
	for(mask = 128;mask >= 1;mask >>= 1) {
		digitalWrite(sht_pins[0], HIGH);
		cwt = cwt + mask * digitalRead(sht_pins[1]);
		digitalWrite(sht_pins[0], LOW);
	}
	return cwt;
}

//PING
boolean MiniBee::getFlagPing(void) { 
	if(config[3] > 0) return true; 
	else return false;
} 

int* MiniBee::getPinPing(void) { 
	return ping_pin; 
}

// void MiniBee::setupPing(int *pins) {
// 	*ping_pins = *pins;	//ping pins = ping pins
// 	//no Ping setup
// }	

int MiniBee::readPing(void) {
	long ping;

	// The Devantech US device is triggered by a HIGH pulse of 10 or more microseconds.
	// We give a short LOW pulse beforehand to ensure a clean HIGH pulse.
	pinMode(ping_pin, OUTPUT);
	digitalWrite(ping_pin, LOW);
	delayMicroseconds(2);
	digitalWrite(ping_pin, HIGH);
	delayMicroseconds(11);
	digitalWrite(ping_pin, LOW);

	// The same pin is used to read the signal from the Devantech Ultrasound device: a HIGH
	// pulse whose duration is the time (in microseconds) from the sending
	// of the ping to the reception of its echo off of an object.
	pinMode(ping_pin, INPUT);
	ping = pulseIn(ping_pin, HIGH);
 
	//max value is 30000 so easily fits in an int
	return int(ping);
}

//**** EVENTS ****//
void MiniBee::setupDigitalEvent(void (*event)(int, int)) {
	dEvent = event;
	
	//set up digital interrupts 
	EICRA = (1 << ISC10) | (1 << ISC00);	
	PCICR = (1 << PCIE0);
	PCMSK0 = (1 << PCINT0);
}

void MiniBee::digitalUpdate(int pin, int status) {
	(*dEvent)(pin, status);
}

void PCINT0_vect(void) {
	Bee.digitalUpdate(0, PINB & (1 << PINB0));
}

//serial rx event
/*void MiniBee::attachSerialEvent(void (*event)(void)) {
	//usart registers
	UCSR0B |= (1 << RXCIE0) | (1 << TXCIE0) | (1 << RXEN0) | (1 << TXEN0); //turn on rx + tx and enable interrupts
	UCSR0C |= (1 << UCSZ01) | (1 << UCSZ00);	//set frame format (81NN)
	UBRR0L = BAUD_PRESCALE; // Load lower 8-bits of the baud rate value into the low char of the UBRR register 
	UBRR0H = (BAUD_PRESCALE >> 8); // Load upper 8-bits of the baud rate value into the high char of the UBRR register
}

void USART_RX_vect(void) {
	
}*/

//**** REST OF THE EVENTS ****//