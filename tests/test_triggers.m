#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>
#import "../TriggerWords.h"
#include <assert.h>
int main(void) { @autoreleasepool {
 NSArray *positive=@[@"tetris",@"TETRIS",@" тетрис\n",@"ТЕТРИС",@"тетріс",@"тэтрыс",@"テトリス",@"てとりす",@"테트리스",@"تتريس",@"تيتريس",@"تتریس",@"טטריס",@"τέτρις",@"τετρις",@"俄罗斯方块",@"俄羅斯方塊",@"टेट्रिस",@"เตตริส",@"เททริส",@"ＴＥＴＲＩＳ",@"Tétris",@"تَتْرِيس",@"\u200fتتريس\u200f",@"تـتـريـس"];
 for(NSString *word in positive)assert(TriggerWord(word));
 NSArray *negative=@[@"",@"not tetris",@"tetris!",@"тетрис игра",@"password",@"tetri"];
 for(NSString *word in negative)assert(!TriggerWord(word));
 assert(!TriggerWord(nil));assert([SBSelectionScriptTemplate containsString:@"%@"]);
 printf("PASS: native Foundation trigger normalization and script template.\n");
 } return 0; }
