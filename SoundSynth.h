#ifndef SELECTBLOCKS_SOUND_SYNTH_H
#define SELECTBLOCKS_SOUND_SYNTH_H
#include <stdint.h>
#include <stddef.h>
#include <math.h>
#include <string.h>
// Newly composed short chiptune cues; no sampled commercial audio.
enum { SBFX_MOVE, SBFX_ROTATE, SBFX_DROP, SBFX_LOCK, SBFX_CLEAR, SBFX_FOUR, SBFX_HOLD, SBFX_OVER, SBFX_COUNT };
typedef struct { double hz, seconds; } SBNote;
static const SBNote sbNotes[SBFX_COUNT][6]={
 {{330,.025},{0,0}},
 {{660,.035},{880,.045},{0,0}},
 {{220,.035},{110,.075},{0,0}},
 {{150,.045},{0,0}},
 {{523.25,.055},{659.25,.055},{783.99,.09},{0,0}},
 {{523.25,.045},{659.25,.045},{783.99,.045},{1046.5,.045},{1318.5,.12},{0,0}},
 {{440,.04},{698.46,.06},{0,0}},
 {{392,.09},{329.63,.09},{261.63,.09},{196,.15},{0,0}}
};
#define SB_SOUND_RATE 22050
static size_t SBSoundFrames(int effect){if(effect<0||effect>=SBFX_COUNT)return 0;size_t n=0;for(int i=0;i<6&&sbNotes[effect][i].seconds>0;i++)n+=(size_t)(sbNotes[effect][i].seconds*SB_SOUND_RATE);return n;}
static size_t SBWaveSize(int effect){size_t frames=SBSoundFrames(effect);return frames?44+frames*2:0;}
static void SBLE16(unsigned char *p,uint16_t v){p[0]=(unsigned char)v;p[1]=(unsigned char)(v>>8);}
static void SBLE32(unsigned char *p,uint32_t v){for(int i=0;i<4;i++)p[i]=(unsigned char)(v>>(8*i));}
static size_t SBMakeWave(int effect,unsigned char *out,size_t capacity){
 size_t total=SBWaveSize(effect);if(!total||!out||capacity<total)return 0;memset(out,0,total);
 memcpy(out,"RIFF",4);SBLE32(out+4,(uint32_t)(total-8));memcpy(out+8,"WAVEfmt ",8);SBLE32(out+16,16);SBLE16(out+20,1);SBLE16(out+22,1);SBLE32(out+24,SB_SOUND_RATE);SBLE32(out+28,SB_SOUND_RATE*2);SBLE16(out+32,2);SBLE16(out+34,16);memcpy(out+36,"data",4);SBLE32(out+40,(uint32_t)(total-44));
 size_t offset=44;const double tau=6.283185307179586;
 for(int note=0;note<6&&sbNotes[effect][note].seconds>0;note++){
  SBNote n=sbNotes[effect][note];size_t count=(size_t)(n.seconds*SB_SOUND_RATE);
  for(size_t j=0;j<count;j++){
   double t=(double)j/SB_SOUND_RATE;double tail=(double)(count-1-j)/SB_SOUND_RATE;
   double envelope=fmin(1,fmin(t/.003,tail/.012));
   double phase=tau*n.hz*t;double wave=sin(phase)+.24*sin(3*phase)+.10*sin(5*phase);
   int16_t sample=(int16_t)(wave*envelope*.14*32767.0);SBLE16(out+offset,(uint16_t)sample);offset+=2;
  }
 }
 return offset;
}
#endif
