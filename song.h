#ifndef __SONG__
#define __SONG__

#include "sequence.h"

//Global "stfu" note value
#define SILENCE 255

class SongCommand {
	public:
		SongCommand(uint8_t dutyCycle, uint16_t pitch, uint16_t noiseRange) {
			this->dutyCycle = dutyCycle;
			this->pitch = pitch;
			this->noiseRange = noiseRange;
		}

		uint8_t dutyCycle;
		uint16_t pitch;
		uint16_t noiseRange;
};

class Song {
	public:
		Song(Sequence* song, SongCommand* notes) {
			this->song = song;
			this->notes = notes;
		}

	Sequence* song;
	SongCommand* notes;
};

#define SONG_STACK_SIZE 4

class SongDriver {
	private:
		SongCommand* curCommand;
	
/*		bool pushSong(Song* c) {
			if(sPtr<SONG_STACK_SIZE) {
				stack[++sPtr] = c;
				return true;
			}
			else
				return false;
		}
	
		Song* popSong() {
			if(sPtr>0) {
				stack[sPtr--] = NULL;
				return stack[sPtr];
			}
			else
				return NULL;
		}*/
	
//		#define curSong stack[sPtr]

		Song* curSong;
	
	public:
		SongDriver() {
			sPtr = 0;
		}
	
		//Song* curSong;
		Song* stack[4];
		byte sPtr;
	
		void play(Song* s) {
			//if(pushSong(s)) {
				curSong = s;
				curSong->song->reset();
			//}
		}
	
		void play(SongCommand* c) {
			//pushSong(NULL);
			curSong = NULL;
			curCommand = c;
		}

		void stop(Song* s=NULL) {
//			if(s == NULL || curSong == s) {
				SoundOff();
				curCommand = NULL;
				curSong = NULL;
//			}
		}
	
		void updateSong() {			
			SongCommand* newCmd = NULL;
			
			/*while((curSong == NULL || curSong->song->done()) && sPtr>=0) {
				popSong();
			}*/
		
			if(curSong != NULL) {
				byte state = curSong->song->state();

				if(state == SILENCE) {
					//STFU
					SoundOff();
				}
				else {
					newCmd = &(curSong->notes[state]);
				}
			}
			else if(curCommand != NULL)
				newCmd = curCommand;
		
			if(newCmd != NULL) {
				if(newCmd->noiseRange==0) {
					if(curSong==NULL || curCommand==NULL || newCmd->pitch != curCommand->pitch)
						my_Tone_Start(newCmd->pitch,1000);
				}
				else {
					unsigned long newLowPitch = (unsigned long)newCmd->pitch - (unsigned long)newCmd->noiseRange;
					unsigned long newHighPitch = (unsigned long)newCmd->pitch + (unsigned long)newCmd->noiseRange;
					my_Tone_Start(random(min(newLowPitch, 65535), min(newHighPitch, 65535)), 1000);
				}
			}
			else
				SoundOff();
			
			curCommand = newCmd;
		}
	
		void my_Tone_Start(unsigned int divisor, unsigned int duration_ms) {
			if(!MakingSound)
				Tone_Start(divisor, duration_ms);
			else
				OCR1A = divisor;
		}
};

#endif
