#ifndef __TimerSequence__
#define __TimerSequence__
#include "WProgram.h"
#include <avr/pgmspace.h>

//#define MkSequence(name, st, dur, len) \
//unsigned long explosionDurations[9] = {1, 2, 4, 8, 8, 8, 8, 8, 8}; \
//byte explosionStates[9] = {FullOn, White, Yellow, Orange, Yellow, Orange, Red, Orange, Red}; \
//Sequence explosionBlinker(bulletDurations, bulletStates, 9, true);

unsigned long sequenceTicks();

class Sequence {
public:
  //unsigned long started;
  PROGMEM const prog_uint32_t* durations;
  PROGMEM const prog_uint8_t* states;
  int length;
  byte autoreset;
  
  int lastState;
  unsigned long lastTime;

  Sequence(PROGMEM const prog_uint32_t* dur = NULL, PROGMEM const prog_uint8_t* st = NULL, int len = 0, byte ar = false) { 
	setup(dur, st, len, ar);
  };
  
  void setup(PROGMEM const prog_uint32_t* dur = NULL, PROGMEM const prog_uint8_t* st = NULL, int len = 0, byte ar = false) { 
	durations = dur;
	states = st;
	length = len;
	autoreset = ar;
	reset();
  };
  
  void reset(void) {
	lastState = 0;
//	if(length>0)
	lastTime = sequenceTicks();
  };
  
#define getDuration(idx) (pgm_read_dword(&(durations[idx])))
#define getState(idx) (pgm_read_byte(&(states[idx])))

  int state() {
	unsigned long time = sequenceTicks();
	unsigned long going = time - lastTime;
	unsigned long lastDuration = getDuration(lastState); //have to have passes this much time to advance
	unsigned long total = lastDuration;

	if(length>0) {
	  while(total < going) {		  
		lastDuration = getDuration(lastState);
		total += getDuration(lastState++);
		
		if(lastState>=length) {
		  if(autoreset)
			lastState = 0;
		  else {
			lastState = length-1;
			break;
		  }
		}
	  }
	  
	  //adjust last time to line up with most recent state change to prevent drift
	  lastTime = time - (lastDuration - (total - going));
	  
	  return getState(lastState);
	}
	else
	  return 0xDEAD;
  };
  
  char done() {
	return (!autoreset) && (lastState>=length-1);
  }
private:
};
#endif