// #include <EEPROM.h>

#include <Wire.h>
#include <MiniBee.h>


void setup() {
  Bee.begin(19200);
}

void loop() {
  Bee.doLoopStep();
}
