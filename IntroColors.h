#ifndef SELECTBLOCKS_INTRO_COLORS_H
#define SELECTBLOCKS_INTRO_COLORS_H
#include <math.h>
#include <stddef.h>
typedef struct { int from, to; double mix; } SBIntroColorSample;
/* Two gentle palette steps per second, no opacity strobe, bounded to the entry animation. */
static inline SBIntroColorSample SBIntroColorAt(size_t letter,double elapsed) {
    if(!isfinite(elapsed)||elapsed<0)elapsed=0;
    if(elapsed>1)elapsed=1;
    double phase=elapsed*2.0;int step=(int)floor(phase);
    int from=(int)((letter+(size_t)step)%7);
    SBIntroColorSample value={from,(from+1)%7,phase-step};return value;
}
#endif
