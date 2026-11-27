#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import "SoundSynth.h"
@interface SBAudio : NSObject {
 SystemSoundID _sounds[SBFX_COUNT];
 NSTimeInterval _last[SBFX_COUNT],_quietMovesUntil;
 BOOL _prepared;
}
@property(nonatomic,assign) BOOL enabled;
- (void)play:(int)effect;
@end
@implementation SBAudio
- (instancetype)init {
 if((self=[super init])){id saved=[NSUserDefaults.standardUserDefaults objectForKey:@"SelectBlocks.sound.enabled.v1"];_enabled=saved?[saved boolValue]:YES;}
 return self;
}
- (void)prepare {
 if(_prepared)return;_prepared=YES;
 NSString *base=NSSearchPathForDirectoriesInDomains(NSCachesDirectory,NSUserDomainMask,YES).firstObject;
 if(!base)return;NSString *dir=[base stringByAppendingPathComponent:@"SelectBlocksAudio-v1"];
 if(![NSFileManager.defaultManager createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil])return;
 for(int i=0;i<SBFX_COUNT;i++){
  NSString *file=[dir stringByAppendingPathComponent:[NSString stringWithFormat:@"cue-%d.wav",i]];
  if(![NSFileManager.defaultManager fileExistsAtPath:file]){
   NSMutableData *data=[NSMutableData dataWithLength:SBWaveSize(i)];
   if(!SBMakeWave(i,(unsigned char *)data.mutableBytes,data.length)||![data writeToFile:file atomically:YES])continue;
  }
  SystemSoundID sid=0;OSStatus status=AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:file],&sid);
  if(status!=kAudioServicesNoError||!sid)continue;
  _sounds[i]=sid;UInt32 uiSound=1,finishAfterExit=0;
  AudioServicesSetProperty(kAudioServicesPropertyIsUISound,sizeof(sid),&sid,sizeof(uiSound),&uiSound);
  AudioServicesSetProperty(kAudioServicesPropertyCompletePlaybackIfAppDies,sizeof(sid),&sid,sizeof(finishAfterExit),&finishAfterExit);
 }
}
- (void)play:(int)effect {
 if(!self.enabled||effect<0||effect>=SBFX_COUNT||UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
 NSTimeInterval now=NSDate.timeIntervalSinceReferenceDate;
 if(effect==SBFX_MOVE&&(now<_quietMovesUntil||now-_last[effect]<.12))return;
 if(now-_last[effect]<.04)return;
 [self prepare];if(!_sounds[effect])return;
 if(effect>=SBFX_DROP&&effect!=SBFX_HOLD)_quietMovesUntil=now+.18;
 _last[effect]=now;AudioServicesPlaySystemSound(_sounds[effect]);
}
- (void)dealloc {for(int i=0;i<SBFX_COUNT;i++)if(_sounds[i])AudioServicesDisposeSystemSoundID(_sounds[i]);}
@end
