// #include <EEPROM.h>
#include <Wire.h>

#define MINIBEE_REVISION 'A'
#include <MiniBee.h>


void setup() {
	Bee.begin(19200);
}

void loop() {
  Bee.doLoopStep();
}
