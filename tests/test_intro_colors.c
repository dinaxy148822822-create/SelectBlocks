#include "../IntroColors.h"
#include <assert.h>
#include <stdio.h>
int main(void){
 for(int step=0;step<=62;step++){
  double t=step*.01;int mask=0;
  for(size_t letter=0;letter<7;letter++){
   SBIntroColorSample v=SBIntroColorAt(letter,t);
   assert(v.from>=0&&v.from<7&&v.to>=0&&v.to<7&&v.mix>=0&&v.mix<=1);
   mask|=1<<v.from;
  }assert(mask==127);
 }
 for(size_t letter=0;letter<100;letter++){
  SBIntroColorSample a=SBIntroColorAt(letter,0),b=SBIntroColorAt(letter,.25);
  assert(a.mix==0&&b.mix==.5&&a.from==b.from);
  assert(SBIntroColorAt(letter,-1).from==a.from);
  assert(SBIntroColorAt(letter,NAN).from==a.from);
  assert(SBIntroColorAt(letter,99).from==SBIntroColorAt(letter,1).from);
 }
 puts("PASS: independent per-letter palette offsets, smooth blending, bounded entry duration and invalid-time safety");return 0;}
