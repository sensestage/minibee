// #include <EEPROM.h>
#include <Wire.h>

#define MINIBEE_REVISION 'A'
#include <MiniBee.h>

#include <CapSense.h>

 // 10M resistor between pins 4 & 6, pin 6 is sensor pin, add a wire and or foil
CapSense   cs_10_11 = CapSense(10,11);       
CapSense   cs_10_12 = CapSense(10,12); 
CapSense   cs_10_13 = CapSense(10,13); 

void setup() {
  Bee.begin(19200);
  Bee.setCustomPin( 10, 0 );
  Bee.setCustomPin( 11, 2 );
  Bee.setCustomPin( 12, 2 );
  Bee.setCustomPin( 13, 2 );
}

int capData[3];

void loop() {
  long total1 =  cs_10_11.capSense(30);
  long total2 =  cs_10_12.capSense(30);
  long total3 =  cs_10_13.capSense(30);

  capData[0] = (int) total1;
  capData[1] = (int) total2;
  capData[2] = (int) total3;
  
  Bee.addCustomData( capData );
  Bee.doLoopStep();
}
