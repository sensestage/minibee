// #include <EEPROM.h>
#include <Wire.h>

#define MINIBEE_REVISION 'A'
#include <MiniBee.h>


void setup() {
  Bee.begin(57600);
}

void loop() {
  Bee.doLoopStep();
}
