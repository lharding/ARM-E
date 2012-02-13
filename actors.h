#ifndef __actors__
#define __actors__
#include "WProgram.h"
#include <avr/pgmspace.h>

#include "sequence.h"

void dummy() {}; //sigh

#define onBoard(x, y) (((x)>=1) && ((x)<7) && ((y)>=1) && ((y)<7))

//FAIL! constrain() is implemented as a macro that evaluates it's parameter twice! So we need this.
void ClampDrawPx(byte x, byte y, byte color) {
	if(x>=0 && x<8 && y>=0 && y<8)
		DrawPx(x, y, color);
}

//#define ClampDrawPx(x, y, color) (onBoard((byte)(x), (byte)(y)) ? DrawPx((byte)(x), (byte)(y), (color)) : dummy())
#define FIELD_RIGHT 7
#define FIELD_TOP 7
#define FIELD_LEFT 0
#define FIELD_BOTTOM 0
#define FIELD_HEIGHT (FIELD_TOP-FIELD_BOTTOM+1)
#define FIELD_WIDTH (FIELD_RIGHT-FIELD_LEFT+1)
#define max(x, y) ( ((x) < (y)) ? (y) : (x) )
#define min(x, y) ( ((x) > (y)) ? (y) : (x) )
#define BoardClamp(x) ( min( max((x), FIELD_LEFT), FIELD_RIGHT) )

int scrollX;
int scrollY;

class Actor {
  public:
	char hp;
	byte color;
	Sequence* blinker;

	char x;
	char y;
  
	char dx;
	char dy;
		
	Metro xMove;
	Metro yMove;
	
	virtual void loop(void);
	virtual void draw(void);
	virtual char isAlive(void);
	virtual void kill(void);
  private:
};


#define MAX_ACTORS 16
Actor*	actors[MAX_ACTORS];

char spaceFree(char x, char y);
#define getMove(ary, facing, step) ((char)pgm_read_byte_near( &((ary)[facing][step]) ))
#define moveTotal(ary, facing) (getMove((ary), (facing), 0) + getMove((ary), (facing), 1) + getMove((ary), (facing), 2))
#define moveOk(x, y) (onBoard(x, y) && spaceFree(x, y))
#define distanceSqr(a, b)  (  ((a).x-(b).x)*((a).x-(b).x) + ((a).y-(b).y)*((a).y-(b).y)  )

byte Button_Right_Latch = false;
byte Button_Left_Latch = false;
byte Button_Up_Latch = false;
byte Button_Down_Latch = false;
byte Button_A_Latch = false;
byte Button_B_Latch = false;

class Player : public Actor {
  public:
	Metro armTimer;
	Metro bulletTimer;
	char arm;
	char dArm;
	Actor* grabbed;
	
	Player();
	virtual void loop(void);
	virtual void draw(void);
	  
  private:
};

Player player;

class Enemy : public Actor {
  public:
//	static Player* player;  
	byte state;
	
	virtual void kill(void);
  private:
};

class Victim : public Enemy {
public:	
//	Victim();
	virtual void setup(void);
	virtual void loop(void);
	virtual void kill(void);
  private:
};

#define MAX_VICTIMS 4
Victim victims[MAX_VICTIMS];

class Bullet : public Enemy {
  public:
	virtual void setup(void);
	virtual void loop(void);
	virtual void kill(void);
  private:
};

#define MAX_BULLETS 4
Bullet bullets[MAX_BULLETS];

class Shark : public Enemy {
public:
	virtual void setup(void);
	virtual void loop(void);
//	virtual void kill(void);	
  private:
};

#define MAX_SHARKS 4
Shark sharks[MAX_SHARKS];

class Explosion : public Enemy {
public:
	virtual void setup(void);
	virtual void loop(void);
	virtual void draw(void);
//	virtual void kill(void);	
  private:
	Sequence myBlinker;
};

#define MAX_EXPLOSIONS 4
Explosion explosions[MAX_EXPLOSIONS];
  
#endif