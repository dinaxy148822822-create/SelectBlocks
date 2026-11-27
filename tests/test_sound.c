#include "../SoundSynth.h"
#include <stdio.h>
#include <stdlib.h>
#include <assert.h>
static uint32_t le32(const unsigned char *p){return (uint32_t)p[0]|((uint32_t)p[1]<<8)|((uint32_t)p[2]<<16)|((uint32_t)p[3]<<24);}
int main(void){
 assert(!SBWaveSize(-1));assert(!SBWaveSize(SBFX_COUNT));assert(!SBMakeWave(0,NULL,0));
 for(int effect=0;effect<SBFX_COUNT;effect++){
  size_t size=SBWaveSize(effect);unsigned char *data=malloc(size);assert(data);assert(!SBMakeWave(effect,data,size-1));assert(SBMakeWave(effect,data,size)==size);
  assert(!memcmp(data,"RIFF",4)&&!memcmp(data+8,"WAVEfmt ",8)&&!memcmp(data+36,"data",4));assert(le32(data+4)==size-8);assert(le32(data+40)==size-44);assert(le32(data+24)==SB_SOUND_RATE);
  assert(data[44]==0&&data[45]==0&&data[size-2]==0&&data[size-1]==0);
  double duration=(double)(size-44)/(2*SB_SOUND_RATE);assert(duration>.015&&duration<1);
  int peak=0;for(size_t i=44;i<size;i+=2){int sample=(int16_t)((uint16_t)data[i]|((uint16_t)data[i+1]<<8));if(abs(sample)>peak)peak=abs(sample);}
  assert(peak>1000&&peak<7000);free(data);
 }
 printf("PASS: eight synthesized WAV cues, headers, durations, amplitude, endpoint fades and capacity guards.\n");return 0;
}
