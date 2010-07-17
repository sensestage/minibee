#include "MiniBee.h"

#if MINIBEE_ENABLE_TWI == 1
#include <Wire.h>
#endif

// #include <NewSoftSerial.h>

uint8_t MiniBee::pwm_pins[] = { 3,5,6, 8,9,10 };

MiniBee::MiniBee() {
// 	pwm_pins = { 3,5,6, 8,9,10 };
	
#if MINIBEE_ENABLE_SHT == 1
	shtOn = false;
#endif
#if MINIBEE_ENABLE_TWI == 1
	twiOn = false;
#endif
#if MINIBEE_ENABLE_PING == 1
	pingOn = false;
#endif
	prev_msg = 0;
	prev_conf_msg = 0;
	prev_id_msg = 0;

	curSample = 0;
	datacount = 0;
	msg_id_send = 0;
	
	for ( i = 0; i<8; i++ ){
	    analog_precision[i] = false; // false is 8bit, true is 10bit
	    analog_in[i] = false;
	}
	for ( i = 0; i<19; i++ ){
	    digital_in[i] = false;
	    digital_out[i] = false;
	    digital_values[i] = 0;
	    custom_pin[i] = false;
	    custom_size[i] = 0;
	}
	for ( i=0; i<6; i++ ){
	    pwm_on[i] = false;
	    pwm_values[i] = 0;
	}

	smpInterval = 50; // default value
	msgInterval = 50;
	samplesPerMsg = 1;
	
	customDataSize = 0;
	
	loopback = false;
	remoteConfig = true;
	
// 	useSoftSerial = false;

	status = STARTING;
	msg_type = S_NO_MSG;

	message = (char*)malloc(sizeof(char) * MAX_MESSAGE_SIZE);
	
	void (*customMsgFunc)(char *) = NULL;

	hasInput = false;
	hasOutput = false;
	hasCustom = false;

}

// MiniBee Bee = MiniBee();

void MiniBee::openSerial(int baud_rate) {
	Serial.begin(baud_rate);  
}

void MiniBee::configXBee(){
	pinMode(XBEE_SLEEP_PIN, OUTPUT);
	digitalWrite(XBEE_SLEEP_PIN, 0);  
}

void MiniBee::setID( uint8_t id ){
    node_id = id;
}

char * MiniBee::getData(){
    return data;
}

int MiniBee::dataSize(){
    return datasize;
}

void MiniBee::begin(int baud_rate) {
	openSerial(baud_rate);
	delay(200);

	configXBee();
	delay(500);

	readXBeeSerial();
	// allow some delay before sending data
	delay(500);

	sendSerialNumber();

	status = WAITFORHOST;
}

// void MiniBee::setSoftSerial(bool onoff, int baud_rate){
//     useSoftSerial = onoff;
//     if ( onoff )
//       initSoftSerial( baud_rate );
// }
// 
// void MiniBee::initSoftSerial(int baud_rate){
//   // define pin modes for tx, rx, led pins:
//   softSerial =  NewSoftSerial(SoftRX, SoftTX);
//   pinMode(SoftRX, INPUT);
//   pinMode(SoftTX, OUTPUT);
//   // set the data rate for the SoftwareSerial port
//   softSerial.begin(baud_rate);
// }

void MiniBee::doLoopStep(void){
  int bytestoread;
  // do something based on current status:
  switch( status ){
    case SENSING:
      //send( N_INFO, "sensing" );
	// read sensors:
	datacount = readSensors( datacount );
	if ( curSample >= samplesPerMsg ){
	    sendData();
	    curSample = 0;
	    datacount = 0;
	}
	delay( smpInterval );
	break;
    case STARTING:
//       send( N_INFO, "starting", 8 );
      delay( 100 );
      break;
    case WAITFORCONFIG:
//       send( N_INFO, "waitforconfig" );
      delay( 100 );
      break;
    case WAITFORHOST:
//       send( N_INFO, "waitforhost" );
      delay( 100 );
      break;
    case ACTING:
      delay( smpInterval );
      break;
    case PAUSING:
      delay( 500 );
      break;
  }
  
  // read any new data from XBee:
  // do this at the end, so status change happens at the beginning of next loop
  bytestoread = Serial.available();
  if ( bytestoread > 0 ){
//         send( N_INFO, "reading" );
	for ( i = 0; i < bytestoread; i++ ){
		read();      
	}
//   } else {
//       send( N_INFO, "no data" );
  }
}

void MiniBee::setCustomPins( uint8_t * ids, uint8_t * sizes, uint8_t n  ){
  for ( i=0; i<n; i++ ){
    setCustomPin( ids[i], sizes[i] );
  }
}

void MiniBee::setCustomInput( uint8_t noInputs, uint8_t size ){
  customInputs = noInputs;
  customDataSize += noInputs * size;

    hasCustom = true;
    if ( size > 0 ){ hasInput = true; }
}

void MiniBee::setCustomPin( uint8_t id, uint8_t size ){
  if ( id >= PINOFFSET ){
    custom_pin[id-PINOFFSET] = true;
    custom_size[id-PINOFFSET] = size;
  } // id's smaller than PINOFFSET allow for custom data without pin associated
    customDataSize += size;
    
    hasCustom = true;
    if ( size > 0 ){ hasInput = true; }
    
//     char info [2];
//     info[0] = (char) id;
//     info[1] = (char) size;
//     send( N_INFO, info, 2 );
}

void MiniBee::addCustomData( uint8_t * cdata, uint8_t n ){
  if ( status == SENSING ){
    for ( i=0; i<n; i++){
      data[datacount] = (char) cdata[i];
      datacount++;  
    }
  }
}

void MiniBee::addCustomData( char * cdata, uint8_t n ){
  if ( status == SENSING ){
    for ( i=0; i<n; i++){
      data[datacount] = cdata[i];
      datacount++;  
    }
  }
}

void MiniBee::addCustomData( int * cdata, uint8_t n ){
  if ( status == SENSING ){
    for ( i=0; i<n; i++){
      dataFromInt( cdata[i], datacount );
      datacount += 2;  
    }
  }
}

void MiniBee::setCustomCall( void (*customFunc)(char * ) ){
//    customMsgFunc = customFunc;
  customMsgFunc = customFunc;
  hasOutput = true;
}

void MiniBee::setDataCall( void (*dataFunc)(char * ) ){
  dataMsgFunc = dataFunc;  
}

// void MiniBee::customMsgFuncWrapper( void* mb, char* msg ){
//   MiniBee * me = (MiniBee*) mb;
//   me->parseCustomMsg( msg );
// }

/// read the serial number of the XBee
void MiniBee::readXBeeSerial(void){
  
    char *response;// = (char *)malloc(sizeof(char)*6);
    char *response2;// = (char *)malloc(sizeof(char)*8);
    
    //populate whatever xBee properties we'll need.
    atEnter();

//     my_addr = atGet( "MY" );

    response = atGet( "SH" );
    response2 = atGet( "SL" );

    free(serial);
    serial = (char *)malloc(sizeof(char)* (
      // length of both strings plus null-termination
      strlen(response) + strlen(response2) + 1 )
      ) ;

    serial = strcpy( serial, response );
    serial = strcat( serial, response2 );

    free( response );
    free( response2 );

//      response = atGet( "DH" );
//      response2 = atGet( "DL" );
//  
//      dest_addr = (char *)malloc(sizeof(char)* (
//        // length of both strings plus null-termination
//        strlen(response) + strlen(response2) + 1 )
//      ) ;
//  
//      dest_addr = strcpy( dest_addr, response );
//      dest_addr = strcat( dest_addr, response2 );
//  
// //     if(strcmp(dest_addr, DEST_ADDR) != 0) {
// //     //make sure we're on the default destination address
// //       atSet("DH", 0);
// //       atSet("DL", 1);
// //     }
//  
//      free( response );
//      free( response2 );
     
    atExit();  
}

//**** Xbee AT Commands ****//
int MiniBee::atGetStatus() {
	incoming = 0;
	int status = 0;
	
	while(incoming != CR ) {
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
	delay( 1000 );
	Serial.print("+++");
	delay( 500 );
	return atGetStatus();
}

int MiniBee::atExit() {
	atSend("CN");
	return atGetStatus();
}

int MiniBee::atSet(char *c, uint8_t val) {
	atSend(c, val);
	return atGetStatus();
}

char* MiniBee::atGet(char *c) {
	char *response = (char *)malloc(sizeof(char)*32);
	incoming = 0;
	i = 0;
	
	atSend( c );
	
	while(incoming != CR ) {
		if(Serial.available()) {
		  incoming = Serial.read();
		  response[i] = incoming;
		  i++;
		}
	}
	response[i-1] = '\0';
	realloc(response, sizeof(char)*(i));
	
	return response;
}

//**** END AT COMMAND STUFF ****//

void MiniBee::send(char type, char *p, int size) {
	Serial.print(ESC_CHAR, BYTE);
	Serial.print(type, BYTE);
	for(i = 0;i < size;i++) slip(p[i]);
	Serial.print(DEL_CHAR, BYTE);
}

void MiniBee::slip(char c) {
	if((c == ESC_CHAR) || (c == DEL_CHAR) || (c == CR))
	    Serial.print(ESC_CHAR, BYTE);
	Serial.print(c, BYTE);
}

void MiniBee::read() {
	incoming = Serial.read();
 	if(escaping) {	//escape set
		if((incoming == ESC_CHAR)  || (incoming == DEL_CHAR) || (incoming == CR)) {	//escape to integer
			if ( msg_type != S_NO_MSG ){ // only add if message type set
			  message[byte_index] = incoming;
			  byte_index++;
			}
		} else {	//escape to char
			msg_type = incoming;
		}
		escaping = false;
	} else {	//escape not set
		if(incoming == ESC_CHAR) {
			escaping = true;
		} else if(incoming == DEL_CHAR) {	//end of msg
			message[byte_index] = '\0'; // null-termination
			routeMsg(msg_type, message, byte_index);	//route completed message
			msg_type = S_NO_MSG;
			byte_index = 0;	//reset buffer index
		} else {
			if ( msg_type != S_NO_MSG ){ // only add if message type set
			  message[byte_index] = incoming; 
			  byte_index++;
			}
		}
	}
}

bool MiniBee::checkNodeMsg( uint8_t nid, uint8_t mid ){
	bool res = ( (nid == node_id)  && ( mid != prev_msg) );
	prev_msg = mid;
	return res;
}

bool MiniBee::checkNotNodeMsg( uint8_t nid ){
	bool res = ( (nid != node_id) );
	return res;
}

bool MiniBee::checkConfMsg( uint8_t mid ){
 	bool res = ( mid != prev_conf_msg);
 	prev_conf_msg = mid;
 	return res;
}

bool MiniBee::checkIDMsg( uint8_t mid ){
 	bool res = ( mid != prev_id_msg);
 	prev_id_msg = mid;
 	return res;
}

void MiniBee::routeMsg(char type, char *msg, uint8_t size) {
	uint8_t len;
	char * ser;

	if ( loopback ){
	  char * loopbackMsg = (char *)malloc(sizeof(char)* (size + 2 ) );
	  loopbackMsg[0] = type;
	  loopbackMsg[1] = size;
	  for ( i=0; i<size; i++ ){
	      loopbackMsg[i+2] = msg[i];
	  }
	  // msg loopback;
	  send( N_INFO, loopbackMsg, size + 2 );
	  free( loopbackMsg );
	}

	switch(type) {
		case S_ANN:
			if ( remoteConfig ){
			  sendSerialNumber();
			  status = WAITFORHOST;
  // 			send( N_INFO, "waitforhost", 11 );
			}
			break;
		case S_QUIT:
			if ( remoteConfig ){
			  status = WAITFORHOST;
			//do something to stop doing anything
			}
// 			send( N_INFO, "waitforhost", 11 );
			break;
		case S_ID:
			if ( remoteConfig ){
			  if ( checkIDMsg( msg[0] ) ){
			    len = strlen(serial);
			    ser = (char *)malloc(sizeof(char)* (len + 1 ) );
			    for(i = 0;i < len;i++){ ser[i] = msg[i+1]; }
			    ser[len] = '\0';
			    if(strcmp(ser, serial) == 0){
			      node_id = msg[len+1];	//writeConfig(msg);
			      if ( size == (len+3) ){
				config_id = msg[len+2];
				status = WAITFORCONFIG;
				char configInfo[2];
				configInfo[0] = node_id;
				configInfo[1] = config_id;
				send( N_WAIT, configInfo, 2 );
    // 			  send( N_INFO, "waitforconfig", 13 );
			      } else if ( size == (len+2) ) {
				readConfig();
				status = SENSING;
    // 				send( N_INFO, "sensing", 7 );
			      }
    // 			  } else {
    // 			      send( N_INFO, "wrong serial number", 19 );
    // 			      send( N_INFO, ser, len );
			    }
			    free(ser);
			  }
			}
			break;
		case S_CONFIG:
		      if ( remoteConfig ){
			// check if right config_id:
			if ( checkConfMsg( msg[0] ) ){
			  if ( msg[1] == config_id ){
			    writeConfig( msg );
			    readConfig();
  // 			readConfigMsg( msg );
			    if ( hasInput ){
			      status = SENSING;
			    } else if ( hasOutput ){
			      status = ACTING;
			    }
  // 			send( N_INFO, "sensing", 7 );
			  }
			}
		      }
		      break;
		case S_RUN:
			if ( checkNodeMsg( msg[0], msg[1] ) ){
			   setRunning( msg[2] );
			}
			break;
		case S_LOOP:
			if ( checkNodeMsg( msg[0], msg[1] ) ){
			   setLoopback( msg[2] );
			}
			break;
		/*
		case S_PWM:
			if ( checkNodeMsg( msg[0], msg[1] ) ){
			    for( i=0; i<6; i++){
			      pwm_values[i] = msg[2+i];
			    }
			    setPWM();
			}
			break;
		case S_DIGI:
			if ( checkNodeMsg( msg[0], msg[1] ) ){
			    for( i=0; i< (size-2); i++){
			      digital_values[i] = msg[2+i];
			    }
			    setDigital();
			}
			break;
		*/
		case S_OUT:
			if ( checkNodeMsg( msg[0], msg[1] ) ){
			  setOutputValues( msg, 2 );
			  setOutput();
			}
			break;
		case S_CUSTOM:
			if ( checkNodeMsg( msg[0], msg[1] ) ){
			    this->customMsgFunc( msg );
			}
			break;
		case N_DATA:
			if ( checkNotNodeMsg( msg[0] ) ){
			    this->dataMsgFunc( msg );
			}
			break;
// 		default:
// 			break;
		}
}

void MiniBee::setRemoteConfig( bool onoff ){
    remoteConfig = onoff;
}

void MiniBee::setRunning( uint8_t onoff ){
    if ( onoff == 1 ){
	status = SENSING;
    } else if ( onoff == 0 ){
	status = PAUSING;
    }
}

void MiniBee::setLoopback( uint8_t onoff ){
    if ( onoff == 1 ){
	loopback = true;
    } else if ( onoff == 0 ){
	loopback = false;
    }
}

/*
void MiniBee::setPWM(){
	for( i=0; i<6; i++){
	  if ( pwm_on[i] ){
	    analogWrite( pwm_pins[i], pwm_values[i] );
	  }
	} 
}

void MiniBee::setDigital(){
	for( i=0; i<19; i++){
	  if ( digital_out[i] ){
	    digitalWrite( i + PINOFFSET, digital_values[i] );
	  }
	} 
}
*/

void MiniBee::setOutputValues( char * msg, uint8_t offset ){
  i = offset;
  for ( uint8_t j=0; j < 6; j++ ){
    if ( pwm_on[j] ){
	pwm_values[j] = msg[i];
	i++;
    }
  }
  for ( uint8_t j=0; j < 19; j++ ){
    if ( digital_out[j] ){
	digital_values[j] = msg[i];
	i++;
	}
  }
}

void MiniBee::setOutput(){
	for( i=0; i<6; i++){
	  if ( pwm_on[i] ){
	    analogWrite( pwm_pins[i], pwm_values[i] );
	  }
	} 
	for( i=0; i<19; i++){
	  if ( digital_out[i] ){
	    digitalWrite( i + PINOFFSET, digital_values[i] );
	  }
	} 
}

void MiniBee::dataFromInt( int output, int offset ){
  data[offset]   = byte(output/256);
  data[offset+1] = byte(output%256);
}

uint8_t MiniBee::readSensors( uint8_t db ){
    int value;
    // read analog sensors
    for ( i = 0; i < 8; i++ ){
      if ( analog_in[i] ){
	    if ( analog_precision[i] ){
		value = analogRead(i);
		dataFromInt( value, db );
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
	//TODO this can be done way more clever by shifting the results into 3 bytes, resulting in shorter messages to be sent.
	data[db] = digitalRead(i+PINOFFSET);
	db++;
      }
    }
    // read I2C/two wire interface accelero
    // TODO higher precision readings, we are now truncating to 8bit.
#if MINIBEE_ENABLE_TWI == 1
     if ( twiOn ){
       readAccelleroTWI( accel1Address, db );
       db += 3;
     }
#endif

#if MINIBEE_ENABLE_SHT == 1
    // read SHT sensor
    if ( shtOn ){
      measureSHT( SHT_T_CMD );
      dataFromInt( valSHT, db );
      db += 2;
      measureSHT( SHT_H_CMD );
      dataFromInt( valSHT, db );
      db += 2;      
    }
#endif

#if MINIBEE_ENABLE_PING == 1
    // read ultrasound sensor
    if ( pingOn ){
      dataFromInt( readPing(), db );
      db += 2;
    }
#endif
    
    curSample++;
//     datacount = db;
    return db;
}

void MiniBee::sendData(void){
    msg_id_send++;
    msg_id_send = msg_id_send%256;
    outMessage[0] = node_id;
    outMessage[1] = msg_id_send;
//     for ( i=0; i < datacount; i++ ){
// 	outMessage[i+2] = data[i];
//     }
    send( N_DATA, outMessage, datacount+2 );
}

uint8_t MiniBee::getId(void) { 
	return node_id;
}

void MiniBee::sendSerialNumber(void){
	int size = strlen(serial);
	char * serdata = (char*)malloc(sizeof(char) * (size + 3) );
	serdata = strcpy( serdata, serial );
 	serdata[ size ] = MINIBEE_LIBVERSION;
 	serdata[ size+1 ] = MINIBEE_REVISION;
/// 1 byte with data of capabilities that may be commented out in the firmware lib...
 	serdata[ size+2 ] = MINIBEE_ENABLE_PING*4 + MINIBEE_ENABLE_SHT*2 + MINIBEE_ENABLE_TWI;
//  	serdata[ size+3 ] = '\0';
 	send(N_SER, serdata, size+3 );
 	free( serdata );
//	send(N_SER, serial, strlen(serial) );
}

void MiniBee::writeConfig(char *msg) {
// 	eeprom_write_byte((uint8_t *) i, id ); // writing id
	for(i = 0;i < CONFIG_BYTES;i++){
	    eeprom_write_byte((uint8_t *) i, msg[i+1]);
	    //write byte to memory
	}
}

void MiniBee::readConfigMsg(char *msg){
	config = (char*)malloc(sizeof(char) * CONFIG_BYTES);
	for(i = 0;i < CONFIG_BYTES;i++){
	   config[i] = msg[i+1];
	}
	parseConfig();
	free(config);
	if ( hasInput ){
	    status = SENSING;
	} else if ( hasOutput ){
	    status = ACTING;
	}
}

void MiniBee::readConfig(void) {
	config = (char*)malloc(sizeof(char) * CONFIG_BYTES);
	for(i = 0;i < CONFIG_BYTES;i++) config[i] = eeprom_read_byte((uint8_t *) i);
	parseConfig();
	free(config);
}

void MiniBee::parseConfig(void){
	uint8_t pin = 0;
	int datasizeout = 0;
	datasize = 0;

	free(outMessage);

	config_id = config[0];
	msgInterval = config[1]*256 + config[2];
	samplesPerMsg = config[3];
	for(i = 0;i < (CONFIG_BYTES-4);i++){
	    pin = i + PINOFFSET;
	    if ( custom_pin[i] ){
	      config[i+4] = Custom;
	      hasCustom = true;
	    } else {
	      switch( config[i+4] ){
		case AnalogIn10bit:
		  if ( i >= ANAOFFSET ){
		      analog_precision[i-ANAOFFSET] = true;
		      analog_in[i-ANAOFFSET] = true;
		      pinMode( pin, INPUT );
		      datasize += 2;
		      hasInput = true;
		  }
		  break;
		case AnalogIn:
		  if ( i >= ANAOFFSET ){
		      analog_precision[i-ANAOFFSET] = false;
		      analog_in[i-ANAOFFSET] = true;
		      pinMode( pin, INPUT );
		      datasize += 1;
		      hasInput = true;
		  }
		  break;
		case DigitalIn:
		  pinMode( pin, INPUT );
		  digital_in[i] = true;
		  datasize += 1;
		  hasInput = true;
		  break;
		case AnalogOut:
		  for ( int j=0; j < 6; j++ ){
		      if ( pwm_pins[j] == pin ){
			  pinMode( pin, OUTPUT );
			  pwm_on[j] = true;
			  datasizeout++;
			  hasOutput = true;
		      }
		  }
		  break;
		case DigitalOut:
		  digital_out[i] = true;
		  pinMode( pin, OUTPUT );
		  datasizeout++;
		  hasOutput = true;
		  break;
#if MINIBEE_ENABLE_SHT == 1
		case SHTClock:
		  sht_pins[0] = pin;
		  shtOn = true;
		  pinMode( pin, OUTPUT );
		  break;
		case SHTData:
		  sht_pins[1] = pin;
		  shtOn = true;
		  pinMode( pin, OUTPUT );
		  datasize += 4;
		  hasInput = true;
		  break;
#endif
#if MINIBEE_ENABLE_TWI == 1
		case TWIClock:
		case TWIData:
		  twiOn = true;
		  datasize += 3;
		  hasInput = true;
		  break;
#endif
#if MINIBEE_ENABLE_PING == 1
		case Ping:
		  pingOn = true;
		  ping_pin = pin;
		  datasize += 2;
		  hasInput = true;
		  break;
#endif
		case Custom:
		  // pin is used in the custom part of the firmware
		  custom_pin[i] = true;
		  hasCustom = true;
		  break;
		case NotUsed:
		  break;
		case UnConfigured:
		  break;
	      }
	    }
	}
	
	datacount = 0;
	datasize += customDataSize;
	datasize = datasize * samplesPerMsg;

// 	free(data);

// 	data = (char*)malloc(sizeof(char) * datasize);
	smpInterval = msgInterval / samplesPerMsg;

#if MINIBEE_ENABLE_TWI == 1
	if ( twiOn ){
	    setupAccelleroTWI();
	}
#endif
#if MINIBEE_ENABLE_SHT == 1
	if ( shtOn ){
	    setupSHT();
	}
#endif
	// no need to setup ping
// 	if ( pingOn ){
// 	    setupPing();
// 	}
	
	uint8_t confSize = 9;
	char * configInfo = (char*)malloc( sizeof(char) * (19*2 + confSize) );
	configInfo[0] = node_id;
	configInfo[1] = config_id;
	configInfo[2] = samplesPerMsg;
	configInfo[3] = (uint8_t) (smpInterval/256);
	configInfo[4] = (uint8_t) (smpInterval%256);
	configInfo[5] = datasize;
	configInfo[6] = datasizeout;
	configInfo[7] = customInputs;
	configInfo[8] = customDataSize;
	for ( i=0; i<19; i++){
	  if ( custom_pin[i] ){
	    configInfo[confSize] = i;
	    configInfo[confSize+1] = custom_size[i];
	    confSize += 2;
	  }
	}
	send( N_CONF, configInfo, confSize );
	free( configInfo );

	outMessage = (char*)malloc( sizeof(char) * (datasize + 2 ) );
	data = outMessage + 2*sizeof(char); // not sure if this is correct... test!!

}

#if MINIBEE_ENABLE_TWI == 1
//TWI --- for LIS302DL accelerometer
bool MiniBee::getFlagTWI(void) { 
 	return twiOn;
} 

void MiniBee::setupAccelleroTWI(void) {
	//start I2C bus
//   Wire.begin();
  setupTWI();

//------- LIS302DL setup --------------
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

//-------end LIS302DL setup --------------
}

/// reading LIS302DL
void MiniBee::readAccelleroTWI( int address, int dboff ){
    data[dboff]   = readTWI( address, accelResultX, 1 ) + 128 % 256;
    data[dboff+1] = readTWI( address, accelResultY, 1 ) + 128 % 256;
    data[dboff+2] = readTWI( address, accelResultZ, 1 ) + 128 % 256;
}

void MiniBee::setupTWI(void) {
	//start I2C bus
	Wire.begin();
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
#endif

#if MINIBEE_ENABLE_SHT == 1
//SHT
bool MiniBee::getFlagSHT(void) { 
    return shtOn;
}
 
uint8_t* MiniBee::getPinSHT(void) {
	 return sht_pins; 
}

void MiniBee::setupSHT() {
// void MiniBee::setupSHT(int* pins) {
	//pins[0] is scl pins[1] is sda
// 	*sht_pins = *pins;
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
	ioSHT = SHT_RST_CMD;
	ackSHT = 1;
	writeByteSHT();
	delay(15);
}

void MiniBee::waitSHT(void) {
	delay(5);
	int j = 0;
	while(j < 600) {
		if(digitalRead(sht_pins[1]) == 0) j = 2600;
		delay(1);
		j++;
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
	ioSHT = SHT_R_STAT;	//R_STATUS

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
#endif

#if MINIBEE_ENABLE_PING == 1
//PING
bool MiniBee::getFlagPing(void) { 
  return pingOn;
} 

uint8_t MiniBee::getPinPing(void) { 
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
#endif

// //**** EVENTS ****//
// void MiniBee::setupDigitalEvent(void (*event)(int, int)) {
// 	dEvent = event;
// 	
// 	//set up digital interrupts 
// 	EICRA = (1 << ISC10) | (1 << ISC00);	
// 	PCICR = (1 << PCIE0);
// 	PCMSK0 = (1 << PCINT0);
// }
// 
// void MiniBee::digitalUpdate(int pin, int status) {
// 	(*dEvent)(pin, status);
// }
// 
// void PCINT0_vect(void) {
// 	Bee.digitalUpdate(0, PINB & (1 << PINB0));
// }

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