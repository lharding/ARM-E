#include "Metro.h"
#include "MeggyJrSimple.h"
#include "actors.h"
#include "song.h"
//This nice wtfly little construct could be used to remove some string constants easily in a low-ram situation
#define serialDebug(x) {}
//#define serialDebug(x) Serial.println(x)

extern void *__bss_end;
extern void *__brkval;

int getFreeRAM()
{
	int free_memory;

	if((int)__brkval == 0)
		free_memory = ((int)&free_memory) - ((int)&__bss_end);
	else
		free_memory = ((int)&free_memory) - ((int)__brkval);

	return free_memory;
}

SongDriver song;

unsigned long frameCount;

//Gotta define this when using sequence.h
unsigned long sequenceTicks() {
  return frameCount;
}

/*** This stuff should go in an actors lib ***/
char addActor(Actor* a) {
  for(int i=0; i<MAX_ACTORS; i++) {
	if(actors[i] == NULL) {
	  actors[i] = a;
	  serialDebug("Actor added");
	  return i;
	}
  }
    
  return -1;
}

char removeActor(Actor* a) {
  for(int i=0; i<MAX_ACTORS; i++) {
	if(actors[i] == a) {
	  actors[i] = NULL;
	  return true;
	}
  }
  
  return false;
}

void setupActors() {
  scrollX = 0;
  scrollY = 0;

  for(int i=0; i<MAX_ACTORS; i++) {
	actors[i] = NULL;
  }
}

char spaceFree(char x, char y) {
  for(int i=0; i<MAX_ACTORS; i++) {
	if(actors[i]->x == x && actors[i]->y == y)
	  return false;
  }
  
  return true;
}

void doDamage(int x, int y, int amt) {
}

void Actor::loop() {
  if(xMove.check())
	x += dx;
  
  if(yMove.check())
	y += dy;
}

void Actor::draw() {
	int col = color;
	if(blinker != NULL)
	  col = blinker->state();
	  
	ClampDrawPx(x-scrollX, y-scrollY, col);
}

char Actor::isAlive() {
  return hp>0;
}

void Actor::kill() {
  hp = -1;
}


/*****/

#define LAND_HEIGHT 3
char land[FIELD_WIDTH];
//char land_occu[FIELD_WIDTH];
char missesLeft;
char score;
char victimsLeft;

PROGMEM const prog_uint32_t armSndDurations[2] = {2, 6};
PROGMEM const prog_uint8_t armSndStates[2] = {0, 1};
Sequence armSndSeq(armSndDurations, armSndStates, 2, true);

SongCommand armSndCmds[4] = {
	SongCommand(128U, ToneC5, 0),
	SongCommand(128U, ToneC3, 0),

	SongCommand(128U, ToneC4, 0),
	SongCommand(128U, ToneC6, 0)
};

Song armSong(&armSndSeq, armSndCmds);

PROGMEM const prog_uint32_t grabSndDurations[3] = {2, 6, 1};
PROGMEM const prog_uint8_t grabSndStates[3] = {2, 3, SILENCE};
Sequence grabSndSeq(armSndDurations, armSndStates, 3, false);

Song grabSong(&grabSndSeq, armSndCmds);


Player::Player() {  
  hp = 64;
  x =3;
  y = 0;
  color = White;
  xMove.interval(125, true);
  yMove.interval(125, true);
  armTimer.interval(75, true);
  bulletTimer.interval(250, true);
  bulletTimer.reset();
  arm = 0;
  dArm = 0;
  grabbed = NULL;
}
	
#define ARM_LENGTH (FIELD_HEIGHT-LAND_HEIGHT)
	
void Player::loop() {
  if(arm != 0){
	dx = 0;
	
	if(armTimer.check()) {
	  arm += dArm;
	}
	
	if(grabbed == NULL) {	
	  for(int i=0; i<MAX_VICTIMS; i++) {
		if(victims[i].isAlive()) {
		  if(victims[i].x == x && victims[i].y == y+arm) {
			serialDebug("Picked up.");
			grabbed = &(victims[i]);
			grabbed->dx = 0;
			grabbed->dy = 0;
			dArm = -1;
			//song.play(&grabSong);
			break;
		  }
		}
	  }
	}
	
	if(dArm > 0) {
	  if(arm>=ARM_LENGTH)
		dArm = -1;
	}

	if(dArm < 0) {
	  //arm has returned	
	  if(arm<=0) {
		dArm = 0;

		song.stop(&armSong);
		
		if(grabbed != NULL) {
		  serialDebug("Letting go...");
		  grabbed->y = y;
		  grabbed->dy = -1;
		  grabbed = NULL;
		}
	  }
	}
		
	if(grabbed != NULL) {
	  grabbed->x = x;
	  grabbed->y = y+arm;
	}
  }
  else {
	if(Button_Left) {
	  dx = -1;
	  if(!Button_Left_Latch) {
		x--;
		xMove.reset();
	  }
	}
	else if(Button_Right) {
	  dx = 1;
	  if(!Button_Right_Latch) {
		x++;
		xMove.reset();
	  }
	}
	else
	  dx = 0;
	  
	if(Button_A) {
	  arm = 1;
	  dArm = 1;
	  armTimer.reset();
	
	  song.play(&armSong);
	}
	
	if(Button_B && bulletTimer.check()) {
	  for(int i=0; i<MAX_BULLETS; i++) {
		if(!bullets[i].isAlive()) {
		  bullets[i].setup();
		  bullets[i].x = x;
		  bullets[i].y = y;
		  addActor(&(bullets[i]));
	  	  serialDebug("firing...");
		  break;
		}
	  }
	  
	  serialDebug("Should have fired now...");
	  bulletTimer.reset();
	}
  }
  	
  Actor::loop();

  x = BoardClamp(x);
  y = BoardClamp(land[x-FIELD_LEFT]);
}
	
void Player::draw() {
  for(byte i=y; i<y+arm; i++) {
	 ClampDrawPx(x-scrollX, i-scrollY, Blue);
  }
	
  Actor::draw();
  SetAuxLEDs(0xFF << (8-missesLeft));
}

//wtf
void Enemy::kill() {
  Actor::kill();
}

int wave = 1;

PROGMEM const prog_uint32_t victimDurations[2] = {18, 2};
PROGMEM const prog_uint8_t victimStates[2] = {White, FullOn};
Sequence victimBlinker(victimDurations, victimStates, 2, true);

void Victim::setup() {
  x = FIELD_RIGHT;
  y = random(LAND_HEIGHT, FIELD_HEIGHT);
 
  hp = 1;
  dy = 0;
  dx = -1;
  xMove.interval(random(450/wave, 750/wave), true);
  xMove.reset();
  yMove.interval(random(450/wave, 750/wave), true);
  yMove.reset();
  color = White;
  blinker = &victimBlinker;
}

void Victim::loop() {
  if(x<FIELD_LEFT) {
	//do any miss penalty stuffs in kill()
	kill();
  }
  
  if(y<FIELD_BOTTOM) {
	score++;
	victimsLeft--;
	//don't kill, just become inactive
	hp = -1;
  }
  
  Enemy::loop();
}

void Victim::kill() {
  missesLeft--;
  victimsLeft--;
  Enemy::kill();
}

PROGMEM const prog_uint32_t sharkDurations[4] = {4, 1, 3, 1};
PROGMEM const prog_uint8_t sharkStates[4] = {Green, DimGreen, Yellow, FullOn};
Sequence sharkBlinker(sharkDurations, sharkStates, 4, true);

void Shark::setup() {
  x = FIELD_LEFT;
  y = random(LAND_HEIGHT, FIELD_HEIGHT);
 
  hp = 1;
  dy = 0;
  dx = 1;
  xMove.interval(500, true);
  xMove.reset();
  yMove.interval(800, true);
  yMove.reset();
  color = Red;
  blinker = &sharkBlinker;
}

void Shark::loop() {
  if(x>FIELD_RIGHT || y>FIELD_TOP) {
	hp = -1;
  }
  
  Victim* closest = NULL;
  int closestDist = 10000;
  for(byte i=0; i<MAX_VICTIMS; i++) {
	if(victims[i].isAlive()) {
	  if(closest==NULL) {
		closest = &victims[i];
	  }
	  else {
		if(distanceSqr(*closest, victims[i]) < closestDist) {
		  closest = &victims[i];
		  closestDist = distanceSqr(*closest, victims[i]);
		}
	  }
	}
  }
  
  if(closest != NULL) {
	if(y > closest->y) 
	  dy = -1;
	else if(y < closest->y)
	  dy = 1;
	else
	  dy = 0;

	if(x > closest->x) 
	  dx = -1;
	else if(x < closest->x)
	  dx = 1;
	else
	  dx = 0;
	  
	if(x==closest->x && y==closest->y) {
	  closest->kill();
	}
  }
  
  if(y<LAND_HEIGHT) {
	y++;
  }
  
  Actor::loop();
}

PROGMEM const prog_uint32_t bulletDurations[4] = {1, 1, 1, 1};
PROGMEM const prog_uint8_t bulletStates[4] = {Red, Orange, White, Yellow};
Sequence bulletBlinker(bulletDurations, bulletStates, 4, true);

PROGMEM const prog_uint32_t bulletSndDurations[9] = {7, 2, 3, 4, 5, 6, 7, 16, 10};
PROGMEM const prog_uint8_t bulletSndStates[9] = 	{0, 1, 2, 3, 4, 5, 6, 7, SILENCE};
Sequence bulletSnd(bulletSndDurations, bulletSndStates, 9, false);

SongCommand bulletSndCmds[8] = {
	SongCommand(128U, ToneC6, ToneC6/2),
	SongCommand(128U, ToneC6+200, ToneC6/3),
	SongCommand(128U, ToneC6+400, ToneC6/4),
	SongCommand(128U, ToneC6+600, 0),
	SongCommand(128U, ToneC6+1800, 0),
	SongCommand(128U, ToneC6+2400, 0),
	SongCommand(128U, ToneC6+3000, 0),
	SongCommand(128U, ToneC6+3800, 0)
};

Song bulletSong(&bulletSnd, bulletSndCmds);


void Bullet::setup() {
  hp = 1;
  dy = 1;
  dx = 0;
  xMove.interval(500, true);
  xMove.reset();
  yMove.interval(75, true);
  yMove.reset();
  blinker = &bulletBlinker;
  color = Red;

  song.play(&bulletSong);
}

void Bullet::loop() {
  for(byte i=0; i<MAX_SHARKS; i++) {
	if(sharks[i].isAlive() && sharks[i].x==x && sharks[i].y==y) {
	  sharks[i].kill();
	  kill();
	}
  }

  for(byte i=0; i<MAX_VICTIMS; i++) {
	if(victims[i].isAlive() && victims[i].x==x && victims[i].y==y) {
	  victims[i].kill();
	  kill();
	}
  }
  if(y>FIELD_TOP) {
	hp = -1;
  }
  
  Actor::loop();
}

void Bullet::kill() {
  for(byte i=0; i<MAX_EXPLOSIONS; i++) {
	if(!explosions[i].isAlive()) {
	  Explosion* e = &explosions[i];
	  e->setup();
	  e->x = x;
	  e->y = y;
	  addActor(e);
	  break;
	}
  }
  
  Enemy::kill();
}

PROGMEM const prog_uint32_t explosionDurations[11] =
		 {3,		1, 		1, 		1, 		1, 		1, 		1, 		1, 		2, 		2,		2};
PROGMEM const prog_uint8_t explosionStates[11] = 
		 {FullOn, 	White,	FullOn,	Yellow, FullOn, Yellow, Orange, Red,	Orange, Red,	DimRed};

PROGMEM const prog_uint8_t explosionSoundStates[11] = 
		 {0, 	1,	1,	1, 2, 2, 2, 2,	3, 3, SILENCE};

SongCommand explosionSoundCmds[4] = {
	SongCommand(128U, ToneB3, ToneB3/6), SongCommand(128U, ToneB5, ToneB5/4),
	SongCommand(128U, ToneB4, ToneB4/2), SongCommand(128U, ToneB3, ToneB3-1)
};

Sequence explosionSndSeq(explosionDurations, explosionSoundStates, 11, false);
Song explosionSong(&explosionSndSeq, explosionSoundCmds);

void Explosion::setup() {
  dx = 0;
  dy = 0;

  song.play(&explosionSong);

  myBlinker.setup(explosionDurations, explosionStates, 9, false);
  blinker = &myBlinker;
  hp = 25;
}

void Explosion::loop() {
  if(myBlinker.done())
	hp = -1;
	
//  Tone_Start(10112*rand(),10);
	
  Actor::loop();
}

void Explosion::draw() {
  int col = color;
  if(blinker != NULL)
	col = blinker->state();
	  
  ClampDrawPx(x-scrollX + random(-1,2), y-scrollY + random(-1, 2), col);
  if(col == FullOn || col == White || col == Yellow)
	ClampDrawPx(x-scrollX + random(-1,2), y-scrollY + random(-1, 2), col);
  
  if(col == FullOn || col == White)
	ClampDrawPx(x-scrollX + random(-1,2), y-scrollY + random(-1, 2), col);

  Enemy::draw();
}

//This makes one frame exactly 20ms and 3 screen refreshes long
int fps = 50;

unsigned long frameNext = 0;
unsigned long victimNext = 0;
int gameState = 0;

#define GAME_TITLE 0
#define GAME_RUN 1000
#define GAME_OVER 2000
#define GAME_END_LEVEL 1500

void setupLevel() {
  for(int i=0; i<MAX_VICTIMS; i++) {
	victims[i].hp = -1;
  }

  for(int i=0; i<MAX_SHARKS; i++) {
	sharks[i].hp = -1;
  }
  
  for(int i=0; i<MAX_BULLETS; i++) {
	bullets[i].hp = -1;
  }
  
  for(int i=0; i<MAX_EXPLOSIONS; i++) {
	explosions[i].hp = -1;
  }

  for(int i=0; i<FIELD_WIDTH; i++) {
	land[i] = 0;
  }
  
  for(int i=0; i<FIELD_WIDTH*LAND_HEIGHT/2; i++) {
	int x;
	do {
	  x = random(FIELD_WIDTH);
	} while(land[x] >= LAND_HEIGHT-1);
	
	land[x]++;
  }
  
  player.x = 4;
  victimsLeft = random(8, 24);
}

void setupGame() {    
  missesLeft = 4;
  score = 0;
  wave = 1;
  //waveNext = 12;
  victimsLeft = 12;
  
  gameState = GAME_TITLE;
  //fps = 60;
  setupLevel();
}

void setup()                    // run once, when the sketch starts
{
  pinMode(14, INPUT);
  digitalWrite(14, LOW);
  randomSeed(analogRead(0));
  digitalWrite(14, HIGH);
  MeggyJrSimpleSetup();      // Required code, line 2 of 2.
  setupActors();
  
  addActor(&player);

  Serial.begin(19200);
  serialDebug("hello, world.");

  frameCount = 0;

  setupGame();
  setupLevel();
}

void drawLand() {  
  for(int i=0; i<FIELD_WIDTH; i++) {
	for(int j=scrollY; j<land[i]-scrollY; j++) {
	  ClampDrawPx(i-scrollX, j, DimGreen);
	}
	
	byte xBlink = (frameCount>>2)&0x07;
	byte color = DimAqua;
	if(i==xBlink)
	  	ClampDrawPx(i-scrollX, land[i]-scrollY, Green);
	  
	ClampDrawPx(i-scrollX, land[i]-scrollY, DimAqua);
  }
}

void drawScoreScreen(int speed) {
	ClearSlate();
	for(int i=0; i<8; i++) {
	  for(int j=0; j<8; j++) {
		ClampDrawPx(i, j, DimGreen);
	  }
	}
	
	for(int i=0; i<score; i++) {
	  int x = 4;
	  int y = 4;
	  int tries = 0;
	  
	  do {
		x = constrain(x+random(-1, 2), 0, 7);
		y = constrain(y+random(-1, 2), 0, 7);
		tries++;
	  } while(ReadPx(x, y) != DimGreen && tries<500);
	  
	  if(tries<500)
		ClampDrawPx(x, y, White);
	  else
		ClampDrawPx(x, y, FullOn);
		
	  delay(speed);
	  DisplaySlate();
	}

}

void drawTitleScreen() {
	SongCommand whoosh(128, ToneDs9, 0U);
	song.play(&whoosh);

	while(false) {
		CheckButtonsDown();
	
		if(Button_Up) {
			whoosh.pitch+=8;
		}
	
		if(Button_Down) {
			whoosh.pitch-=8;
		}
	
		if(Button_Left) {
			whoosh.noiseRange-=8;
		}
	
		if(Button_Right) {
			whoosh.noiseRange+=8;
		}
	
//		delay(5);
		ClearSlate();
		DrawPx(whoosh.noiseRange>>13, whoosh.pitch>>13, White);
		song.updateSong();
		DisplaySlate();
	}

	for(int waveFront = FIELD_TOP+4<<2; waveFront > (FIELD_BOTTOM-24)<<2; waveFront--) { 
		//draw air
		for(int i=FIELD_BOTTOM; i<waveFront>>2; i++) {
			for(int j=FIELD_LEFT; j<=FIELD_RIGHT; j++) {
				ClampDrawPx(j, i, DimAqua);
			}
		}
		
		//draw vacuum
		for(int i=waveFront>>2; i<=FIELD_TOP; i++) {
			for(int j=FIELD_LEFT; j<=FIELD_RIGHT; j++) {
				ClampDrawPx(j, i, Dark);
			}
		}
		
		//draw spray
		for(int i=0; i<12; i++) {		
			ClampDrawPx(random(FIELD_LEFT, FIELD_RIGHT+1), random((waveFront>>2)-1, (waveFront>>2)+1), White);
		}
	
		for(int i=0; i<8; i++) {		
			ClampDrawPx(random(FIELD_LEFT, FIELD_RIGHT+1), random((waveFront>>2)-1, FIELD_TOP), White);
		}

		drawLand();

		//Lightning flashes
		if(random(0,32)<1) {
			for(int i=0; i<8; i++) {
				for(int j=0; j<8; j++) {
					ClampDrawPx(i, j, FullOn);
				}
			}
		}
	
		unsigned long msec = millis()+5;
		while(millis() < msec)
			song.updateSong();
	
		if(whoosh.pitch<65000U) {
			whoosh.pitch+=550U;
			whoosh.noiseRange = whoosh.pitch;
		}
	
		song.updateSong();
		DisplaySlate();
	}

	song.stop();
}

void doEndLevel() {
	for(int y=0; y<FIELD_HEIGHT; y++) {
		ClearSlate();	  
		scrollY--;
		drawLand();
		DisplaySlate();
		delay(125);
	}
	
	delay(500);
	setupLevel();

	for(int y=0; y<FIELD_HEIGHT; y++) {
		ClearSlate();	  
		scrollY++;
		drawLand();
		DisplaySlate();
		delay(100);
	}
}

void loop()   
{
  ClearSlate(); 

  Button_Left_Latch = Button_Left;
  Button_Right_Latch = Button_Right;
  Button_Up_Latch = Button_Up;
  Button_Down_Latch = Button_Down;
  Button_B_Latch = Button_B;
  Button_A_Latch = Button_A;

  CheckButtonsDown();   //Check to see which buttons  are down.

  if(gameState == GAME_TITLE) {
	drawTitleScreen();
	gameState = GAME_RUN;
//	serialDebug("RAM left: ");
//	serialDebug(getFreeRAM());
  }
  else if(gameState == GAME_OVER) {
	drawScoreScreen(250);
	delay(2000);
	setupGame();
  }
  else if(gameState == GAME_END_LEVEL) {
	doEndLevel();	
	gameState = GAME_RUN;
  }
  else if(gameState >= GAME_RUN) {
	fps = 60;
	if(random(0, 500) <= wave) {
	  int i;
	  for(i=0; i<MAX_VICTIMS; i++) {
		if(!victims[i].isAlive()) {
		  victims[i].setup();
		  addActor(&(victims[i]));
  //		serialDebug("Victim Added");
		  break;
		}
	  }

	  if(i>=MAX_VICTIMS) 
			  serialDebug("All victims busy??");
	}

	if(random(0, 1000) <= wave) {
	  int i;
	  for(i=0; i<MAX_SHARKS; i++) {
		if(!sharks[i].isAlive()) {
		  sharks[i].setup();
		  addActor(&(sharks[i]));
		  break;
		}
	  }
	}
	
	drawLand();
	
	for(int i=0; i<MAX_ACTORS; i++) {
	  if(actors[i] != NULL) {
		if(actors[i]->isAlive()) {
		  Actor* a = actors[i];
		  a->loop();
		  a->draw();
		}
		else {
		  actors[i] = NULL;
		}
	  }
	}
	
	if(missesLeft <= 0) {
	  gameState = GAME_OVER;
	} else if(victimsLeft<=0) {
	  gameState = GAME_END_LEVEL;
	}
  }
  
  DisplaySlate();
  frameCount++;
  while(frameNext>millis())
	    song.updateSong();
  frameNext = millis() + (1000/fps);
}