#include "../Game.h"
#include <assert.h>
#include <stdio.h>
int main(void){
 Game g;
 for(int t=0;t<7;t++)for(int r=0;r<4;r++){int n=0;for(int y=0;y<4;y++)for(int x=0;x<4;x++)n+=cell(t,r,x,y);assert(n==4);}
 gameNew(&g,42);g.bi=7;for(int k=0;k<1000;k++){int mask=0;for(int i=0;i<7;i++)mask|=1<<drawPiece(&g);assert(mask==127);}
 gameNew(&g,1);assert(gravity(&g)>.7);g.level=100;assert(gravity(&g)>=.065);g.level=1;for(int y=16;y<20;y++)for(int x=0;x<10;x++)g.board[y][x]=1;assert(clearRows(&g)==4);assert(g.lines==4&&g.score==800);
 g.lines=9;for(int x=0;x<10;x++)g.board[19][x]=2;assert(clearRows(&g)==1);assert(g.level==2);
 gameNew(&g,2);int original=g.type;holdPiece(&g);assert(g.held==original&&g.holdUsed);int current=g.type;holdPiece(&g);assert(g.type==current);
 hardDrop(&g);assert(!g.holdUsed);holdPiece(&g);assert(g.type==original);
 // Four turns at an unobstructed spawn position return to original rotation.
 for(int t=0;t<7;t++){gameNew(&g,5);resetPiece(&g,t);g.y=4;for(int i=0;i<4;i++)assert(rotatePiece(&g,1));assert(g.rot==0);}
 // Randomized actions with sanitizers check board access and invariants.
 unsigned long actions=0;
 for(unsigned seed=1;seed<=2500;seed++){gameNew(&g,seed);for(int j=0;j<3000&&!g.over;j++){
  switch(rnd(&g)%7){case 0:movePiece(&g,-1,0);break;case 1:movePiece(&g,1,0);break;case 2:rotatePiece(&g,1);break;case 3:rotatePiece(&g,-1);break;case 4:holdPiece(&g);break;case 5:hardDrop(&g);break;default:if(!movePiece(&g,0,1))lockPiece(&g);break;}
  actions++;for(int y=0;y<20;y++)for(int x=0;x<10;x++)assert(g.board[y][x]<=7);
  assert(g.type>=0&&g.type<7);if(!g.over)assert(fits(&g,g.x,g.y,g.rot));
 }}
 printf("PASS: 28 shapes, 1000 bags, scoring, levels, hold, rotations, 2500 randomized games (%lu actions).\n",actions);
 return 0;
}
