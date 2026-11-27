#ifndef SELECTBLOCKS_GAME_H
#define SELECTBLOCKS_GAME_H
#include <stdint.h>
#include <string.h>
#define GW 10
#define GH 20
// Independent falling-block game. Rotations use simple wall kicks, not SRS.
typedef struct { uint32_t magic, rng; uint8_t board[GH][GW]; int bag[7], bi;
 int type, rot, x, y, next[3], held, holdUsed, score, lines, level, over; } Game;
static const uint16_t shapes[7][4] = {
 {0x00f0,0x4444,0x0f00,0x2222}, {0x0066,0x0066,0x0066,0x0066},
 {0x0072,0x0262,0x0270,0x0232}, {0x0036,0x0462,0x0360,0x0231},
 {0x0063,0x0264,0x0630,0x0132}, {0x0071,0x0226,0x0470,0x0322},
 {0x0074,0x0622,0x0170,0x0223}
};
static int cell(int t,int r,int x,int y) { return (shapes[t][r&3]>>(y*4+x))&1; }
static uint32_t rnd(Game *g) { uint32_t x=g->rng; x^=x<<13; x^=x>>17; x^=x<<5; return g->rng=x; }
static int drawPiece(Game *g) { if(g->bi>=7){for(int i=0;i<7;i++)g->bag[i]=i;
 for(int i=6;i>0;i--){int j=(int)(rnd(g)%(unsigned)(i+1));int t=g->bag[i];g->bag[i]=g->bag[j];g->bag[j]=t;}g->bi=0;}return g->bag[g->bi++]; }
static int fits(const Game *g,int x,int y,int r){for(int j=0;j<4;j++)for(int i=0;i<4;i++)if(cell(g->type,r,i,j)){
 int a=x+i,b=y+j;if(a<0||a>=GW||b>=GH)return 0;if(b>=0&&g->board[b][a])return 0;}return 1;}
static void resetPiece(Game *g,int t){g->type=t;g->rot=0;g->x=3;g->y=-1;if(!fits(g,g->x,g->y,0))g->over=1;}
static void spawn(Game *g){int t=g->next[0];g->next[0]=g->next[1];g->next[1]=g->next[2];g->next[2]=drawPiece(g);g->holdUsed=0;resetPiece(g,t);}
static void gameNew(Game *g,uint32_t seed){memset(g,0,sizeof(*g));g->magic=0x53424c31;g->rng=seed?seed:1;g->bi=7;g->held=-1;g->level=1;for(int i=0;i<3;i++)g->next[i]=drawPiece(g);spawn(g);}
static int movePiece(Game *g,int dx,int dy){if(g->over||!fits(g,g->x+dx,g->y+dy,g->rot))return 0;g->x+=dx;g->y+=dy;return 1;}
static int rotatePiece(Game *g,int direction){if(g->over)return 0;int r=(g->rot+direction+4)&3;
 static const int kicks[6][2]={{0,0},{-1,0},{1,0},{-2,0},{2,0},{0,-1}};
 for(int i=0;i<6;i++){int x=g->x+kicks[i][0],y=g->y+kicks[i][1];if(fits(g,x,y,r)){g->x=x;g->y=y;g->rot=r;return 1;}}return 0;}
static int clearRows(Game *g){int n=0;for(int y=GH-1;y>=0;y--){int full=1;for(int x=0;x<GW;x++)if(!g->board[y][x])full=0;
 if(full){for(int j=y;j>0;j--)memcpy(g->board[j],g->board[j-1],GW);memset(g->board[0],0,GW);n++;y++;}}
 static const int points[5]={0,100,300,500,800};g->score+=points[n>4?4:n]*g->level;g->lines+=n;g->level=g->lines/10+1;return n;}
static void lockPiece(Game *g){if(g->over)return;for(int j=0;j<4;j++)for(int i=0;i<4;i++)if(cell(g->type,g->rot,i,j)&&g->y+j<0){g->over=1;return;}
 for(int j=0;j<4;j++)for(int i=0;i<4;i++)if(cell(g->type,g->rot,i,j))g->board[g->y+j][g->x+i]=(uint8_t)(g->type+1);
 clearRows(g);spawn(g);}
static void hardDrop(Game *g){if(g->over)return;while(movePiece(g,0,1))g->score+=2;lockPiece(g);}
static void holdPiece(Game *g){if(g->over||g->holdUsed)return;int t=g->type;if(g->held<0){g->held=t;spawn(g);}else{resetPiece(g,g->held);g->held=t;}g->holdUsed=1;}
static double gravity(const Game *g){double t=0.8;for(int i=1;i<g->level&&i<30;i++)t*=0.82;return t<0.065?0.065:t;}
#endif
