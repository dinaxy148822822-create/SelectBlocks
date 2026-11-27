#import <Foundation/Foundation.h>
// Names only. No network, telemetry or persistent storage of selected text.
static NSString *SBNormalizeWord(NSString *text) {
 if(![text isKindOfClass:NSString.class]||text.length>96)return @"";
 NSString *s=[[[text precomposedStringWithCompatibilityMapping] lowercaseStringWithLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]] decomposedStringWithCanonicalMapping];
 static NSCharacterSet *ignored;static dispatch_once_t once;dispatch_once(&once,^{
  NSMutableCharacterSet *c=[NSMutableCharacterSet new];
  [c addCharactersInRange:NSMakeRange(0x0300,0x70)];
  [c addCharactersInRange:NSMakeRange(0x064b,0x15)];
  [c addCharactersInRange:NSMakeRange(0x2066,4)];
  [c addCharactersInString:@"\u0640\u0670\u061c\u200e\u200f\u200b"];
  ignored=[c copy];
 });
 s=[[s componentsSeparatedByCharactersInSet:ignored] componentsJoinedByString:@""];
 return [s stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}
static NSSet<NSString *> *SBTriggerAliases(void) {
 static NSSet *set;static dispatch_once_t once;dispatch_once(&once,^{
  NSArray *words=@[@"tetris", @"тетрис", @"тетріс", @"тэтрыс", @"テトリス", @"てとりす", @"테트리스", @"تتريس", @"تيتريس", @"تتریس", @"טטריס", @"τέτρις", @"τετρις", @"俄罗斯方块", @"俄羅斯方塊", @"टेट्रिस", @"เตตริส", @"เททริส"];NSMutableSet *normalized=[NSMutableSet new];
  for(NSString *word in words)[normalized addObject:SBNormalizeWord(word)];set=[normalized copy];
 });return set;
}
static BOOL TriggerWord(NSString *text) {return [SBTriggerAliases() containsObject:SBNormalizeWord(text)];}

static NSString *const SBSelectionScriptTemplate = @"(()=>{const norm=s=>s.normalize('NFKC').toLowerCase().normalize('NFD').replace(/[\\u0300-\\u036f\\u064b-\\u065f\\u0640\\u0670\\u061c\\u200e\\u200f\\u200b\\u2066-\\u2069]/g,'').trim();const names=new Set(%@);const selection=window.getSelection();if(!selection||!selection.rangeCount)return null;const text=selection.toString();if(text.length>96||!names.has(norm(text)))return null;const range=selection.getRangeAt(0);const r=range.getBoundingClientRect();const vp=window.visualViewport;const node=range.startContainer.nodeType===1?range.startContainer:range.startContainer.parentElement;const font=node?parseFloat(getComputedStyle(node).fontSize):17;return {text:text,geometry:[r.x,r.y,r.width,r.height,vp?vp.offsetLeft:0,vp?vp.offsetTop:0,vp?vp.width:innerWidth,Number.isFinite(font)?font:17]};})()";
