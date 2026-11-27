#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "Game.h"
#include <stdlib.h>
#include <math.h>

static UIWindow *gameWindow;
static __weak UIWindow *previousWindow;
static NSTimeInterval lastClose;
static UIColor *PieceColor(int n) {
 static NSArray<UIColor *> *colors; static dispatch_once_t once;
 dispatch_once(&once, ^{ colors=@[UIColor.clearColor, [UIColor colorWithRed:.24 green:.80 blue:.90 alpha:1], [UIColor colorWithRed:.95 green:.79 blue:.28 alpha:1], [UIColor colorWithRed:.69 green:.50 blue:.91 alpha:1], [UIColor colorWithRed:.37 green:.79 blue:.58 alpha:1], [UIColor colorWithRed:.93 green:.43 blue:.47 alpha:1], [UIColor colorWithRed:.33 green:.59 blue:.94 alpha:1], [UIColor colorWithRed:.96 green:.62 blue:.32 alpha:1]]; });
 return colors[MAX(0,MIN(7,n))];
}
@interface SBBoard : UIView
@property(nonatomic,assign) Game *game;
@end
@implementation SBBoard
- (void)drawRect:(CGRect)rect {
 Game *g=self.game; if(!g)return;
 CGContextRef c=UIGraphicsGetCurrentContext(); CGFloat s=MIN(self.bounds.size.width/10,self.bounds.size.height/20);
 CGFloat ox=(self.bounds.size.width-s*10)/2,oy=(self.bounds.size.height-s*20)/2;
 [[UIColor colorWithWhite:.07 alpha:1] setFill]; UIRectFill(self.bounds);
 for(int y=0;y<20;y++)for(int x=0;x<10;x++){
  CGRect r=CGRectMake(ox+x*s+.7,oy+y*s+.7,s-1.4,s-1.4);
  [(g->board[y][x]?PieceColor(g->board[y][x]):[UIColor colorWithWhite:.12 alpha:1]) setFill];UIRectFill(r);
 }
 if(!g->over){int ghost=g->y;while(fits(g,g->x,ghost+1,g->rot))ghost++;
  for(int pass=0;pass<2;pass++)for(int j=0;j<4;j++)for(int i=0;i<4;i++)if(cell(g->type,g->rot,i,j)){
   int y=(pass?g->y:ghost)+j;if(y<0)continue;
   CGRect r=CGRectMake(ox+(g->x+i)*s+1,oy+y*s+1,s-2,s-2);
   if(pass){[PieceColor(g->type+1) setFill];UIRectFill(r);}else{[PieceColor(g->type+1) setStroke];CGContextSetLineWidth(c,1.5);CGContextStrokeRect(c,CGRectInset(r,1,1));}
  }
 }
}
@end
@interface SBPreview : UIView
@property(nonatomic,assign) int type;
@property(nonatomic,copy) NSString *title;
@end
@implementation SBPreview
- (void)drawRect:(CGRect)r {
 [self.title drawAtPoint:CGPointMake(0,1) withAttributes:@{NSFontAttributeName:[UIFont systemFontOfSize:14 weight:UIFontWeightMedium],NSForegroundColorAttributeName:UIColor.lightGrayColor}];
 if(self.type<0)return;
 CGFloat s=10;for(int y=0;y<4;y++)for(int x=0;x<4;x++)if(cell(self.type,0,x,y)){
 [PieceColor(self.type+1) setFill];UIRectFill(CGRectMake(self.bounds.size.width-46+x*s,1+y*s,s-1,s-1));}
}
@end
@interface SBGameController : UIViewController {
 Game _game; BOOL _paused; double _lastTick,_fall,_lock,_pressedAt; int _pressed; int _best;
}
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) SBBoard *board;
@property(nonatomic,strong) UILabel *stats;
@property(nonatomic,strong) UILabel *status;
@property(nonatomic,strong) SBPreview *hold;
@property(nonatomic,strong) NSArray<SBPreview *> *previews;
@end
@implementation SBGameController
- (void)viewDidLoad {
 [super viewDidLoad]; __weak typeof(self) weakSelf=self; self.view.backgroundColor=[UIColor colorWithWhite:.075 alpha:1];
 _pressed=-1;_lastTick=NSDate.timeIntervalSinceReferenceDate;
 NSUserDefaults *d=NSUserDefaults.standardUserDefaults;NSData *save=[d dataForKey:@"SelectBlocks.state.v1"];
 BOOL valid=NO;
 if(save.length==sizeof(Game)){Game temp;[save getBytes:&temp length:sizeof temp];valid=temp.magic==0x53424c31&&temp.type>=0&&temp.type<7&&temp.rot>=0&&temp.rot<4&&temp.x>=-3&&temp.x<10&&temp.y>=-4&&temp.y<20&&temp.bi>=0&&temp.bi<=7&&temp.held>=-1&&temp.held<7&&temp.level>=1&&temp.level<10000&&temp.lines>=0&&temp.score>=0;
  for(int y=0;y<20;y++)for(int x=0;x<10;x++)if(temp.board[y][x]>7)valid=NO;
  for(int i=0;i<7;i++)if(temp.bag[i]<0||temp.bag[i]>6)valid=NO;
  for(int i=0;i<3;i++)if(temp.next[i]<0||temp.next[i]>6)valid=NO;
  if(valid){_game=temp;if(!_game.over&&!fits(&_game,_game.x,_game.y,_game.rot))valid=NO;}
 }
 if(!valid)gameNew(&_game,arc4random());_paused=valid&&!_game.over;_best=(int)[d integerForKey:@"SelectBlocks.best.v1"];
 UIScrollView *scroll=[[UIScrollView alloc]init];scroll.translatesAutoresizingMaskIntoConstraints=NO;[self.view addSubview:scroll];
 UIStackView *root=[[UIStackView alloc]init];root.axis=UILayoutConstraintAxisVertical;root.spacing=8;root.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:root];
 UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
 [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],[scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],[root.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],[root.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],[root.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:8],[root.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-8],[root.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],[root.heightAnchor constraintGreaterThanOrEqualToAnchor:scroll.frameLayoutGuide.heightAnchor constant:-16]]];
 NSLayoutConstraint *preferredHeight=[root.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor constant:-16];preferredHeight.priority=750;preferredHeight.active=YES;
 UILabel *title=[[UILabel alloc]init];title.text=@"SELECT BLOCKS";title.font=[UIFont monospacedSystemFontOfSize:20 weight:UIFontWeightBold];title.textColor=UIColor.whiteColor;
 UIButton *close=[self button:@"Закрыть" action:^{[weakSelf closeGame];}];
 UIStackView *header=[[UIStackView alloc]initWithArrangedSubviews:@[title,close]];header.spacing=8;[header.heightAnchor constraintEqualToConstant:44].active=YES;[root addArrangedSubview:header];
 self.stats=[[UILabel alloc]init];self.stats.font=[UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightMedium];self.stats.textColor=UIColor.whiteColor;self.stats.numberOfLines=2;[self.stats.heightAnchor constraintEqualToConstant:40].active=YES;[root addArrangedSubview:self.stats];
 self.hold=[[SBPreview alloc]init];self.hold.title=@"HOLD";
 NSMutableArray *previews=[NSMutableArray array];for(int i=0;i<3;i++){SBPreview *p=[[SBPreview alloc]init];p.title=i==0?@"NEXT":@"";p.backgroundColor=UIColor.clearColor;[previews addObject:p];}self.previews=previews;
 self.hold.backgroundColor=UIColor.clearColor;
 UIStackView *previewRow=[[UIStackView alloc]initWithArrangedSubviews:@[self.hold,previews[0],previews[1],previews[2]]];previewRow.spacing=8;previewRow.distribution=UIStackViewDistributionFillEqually;[previewRow.heightAnchor constraintEqualToConstant:40].active=YES;[root addArrangedSubview:previewRow];
 self.board=[[SBBoard alloc]init];self.board.game=&_game;[self.board.heightAnchor constraintGreaterThanOrEqualToConstant:160].active=YES;[root addArrangedSubview:self.board];
 self.status=[[UILabel alloc]init];self.status.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];self.status.textColor=UIColor.lightGrayColor;self.status.textAlignment=NSTextAlignmentCenter;[self.status.heightAnchor constraintEqualToConstant:22].active=YES;[root addArrangedSubview:self.status];
 NSArray *row1=@[[self repeatButton:@"◀" tag:0],[self button:@"↶" action:^{[weakSelf rotate:-1];}],[self button:@"↷" action:^{[weakSelf rotate:1];}],[self repeatButton:@"▶" tag:1]];
 NSArray *row2=@[[self button:@"HOLD" action:^{[weakSelf holdAction];}],[self repeatButton:@"▼" tag:2],[self button:@"Сброс" action:^{[weakSelf dropAction];}]];
 NSArray *row3=@[[self button:@"Пауза / ▶" action:^{[weakSelf pauseAction];}],[self button:@"Заново" action:^{[weakSelf restartAction];}]];
 for(NSArray *buttons in @[row1,row2,row3]){UIStackView *r=[[UIStackView alloc]initWithArrangedSubviews:buttons];r.spacing=8;r.distribution=UIStackViewDistributionFillEqually;[r.heightAnchor constraintEqualToConstant:44].active=YES;[root addArrangedSubview:r];}
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background:) name:UIApplicationWillResignActiveNotification object:nil];
 self.timer=[NSTimer timerWithTimeInterval:.05 repeats:YES block:^(NSTimer *t){[weakSelf tick];}];[NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];[self refresh];
}
- (UIButton *)button:(NSString *)name action:(void(^)(void))action {
 UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem];b.backgroundColor=[UIColor colorWithWhite:.17 alpha:1];b.layer.cornerRadius=8;[b setTitle:name forState:UIControlStateNormal];[b setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];b.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];b.accessibilityLabel=name;
 [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *a){action();}] forControlEvents:UIControlEventTouchUpInside];return b;
}
- (UIButton *)repeatButton:(NSString *)title tag:(NSInteger)tag {UIButton *b=[self button:title action:^{}];b.tag=tag;[b addTarget:self action:@selector(press:) forControlEvents:UIControlEventTouchDown];[b addTarget:self action:@selector(releasePress:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];return b;}
- (void)press:(UIButton *)b{if(_paused||_game.over)return;_pressed=(int)b.tag;_pressedAt=NSDate.timeIntervalSinceReferenceDate;[self step:_pressed];}
- (void)releasePress:(id)sender{_pressed=-1;}
- (void)step:(int)action {if(_paused||_game.over)return;if(action==2){if(movePiece(&_game,0,1))_game.score++;}else movePiece(&_game,action==0?-1:1,0);[self refresh];}
- (void)rotate:(int)direction {if(_paused||_game.over)return;rotatePiece(&_game,direction);[self refresh];}
- (void)holdAction {if(_paused||_game.over)return;holdPiece(&_game);_fall=_lock=0;[self refresh];}
- (void)dropAction {if(_paused||_game.over)return;hardDrop(&_game);_fall=_lock=0;[self persist];[self refresh];}
- (void)pauseAction {if(_game.over)return;_paused=!_paused;_pressed=-1;[self persist];[self refresh];}
- (void)restartAction {BOOL wasPaused=_paused;_paused=YES;_pressed=-1;[self refresh];
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Новая игра?" message:@"Текущая партия будет сброшена." preferredStyle:UIAlertControllerStyleAlert];__weak typeof(self) w=self;
 [a addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x){SBGameController *s=w;if(s){s->_paused=wasPaused;[s refresh];}}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Начать" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x){SBGameController *s=w;if(s){[s persist];gameNew(&s->_game,arc4random());s->_paused=NO;s->_fall=s->_lock=0;[s persist];[s refresh];}}]];[self presentViewController:a animated:YES completion:nil];}
- (void)tick {double now=NSDate.timeIntervalSinceReferenceDate,dt=fmin(.1,fmax(0,now-_lastTick));_lastTick=now;if(_paused||_game.over)return;
 if(_pressed>=0&&now-_pressedAt>.22){[self step:_pressed];}
 _fall+=dt;if(_fall>=gravity(&_game)){_fall=0;movePiece(&_game,0,1);}
 if(!fits(&_game,_game.x,_game.y+1,_game.rot)){_lock+=dt;if(_lock>=.45){lockPiece(&_game);_lock=0;_fall=0;[self persist];}}else _lock=0;
 [self refresh];
}
- (void)refresh {self.stats.text=[NSString stringWithFormat:@"Очки %d   Рекорд %d\nУровень %d   Линии %d",_game.score,MAX(_best,_game.score),_game.level,_game.lines];self.status.text=_game.over?@"Игра окончена · нажми «Заново»":(_paused?@"ПАУЗА · нажми «Пауза / ▶»":@"▼ мягкий спуск · Сброс — мгновенный");self.board.alpha=_paused?.12:1;self.hold.type=_game.held;[self.hold setNeedsDisplay];for(int i=0;i<3;i++){self.previews[i].type=_game.next[i];[self.previews[i] setNeedsDisplay];}[self.board setNeedsDisplay];}
- (void)persist {NSUserDefaults *d=NSUserDefaults.standardUserDefaults;_best=MAX(_best,_game.score);[d setInteger:_best forKey:@"SelectBlocks.best.v1"];[d setObject:[NSData dataWithBytes:&_game length:sizeof _game] forKey:@"SelectBlocks.state.v1"];}
- (void)background:(NSNotification *)n{_paused=YES;_pressed=-1;[self persist];[self refresh];}
- (void)closeGame {[self persist];[self.timer invalidate];self.timer=nil;[NSNotificationCenter.defaultCenter removeObserver:self];gameWindow.hidden=YES;gameWindow.rootViewController=nil;gameWindow=nil;[previousWindow makeKeyWindow];lastClose=NSDate.timeIntervalSinceReferenceDate;}
- (void)dealloc {[self.timer invalidate];[NSNotificationCenter.defaultCenter removeObserver:self];}
@end

static void ShowGame(UIView *source) {
 if(!NSThread.isMainThread||gameWindow||NSDate.timeIntervalSinceReferenceDate-lastClose<2)return;
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
 UIWindow *origin=source.window;UIWindowScene *scene=origin.windowScene;if(!scene||scene.activationState!=UISceneActivationStateForegroundActive)return;
 previousWindow=origin;[origin endEditing:YES];
 gameWindow=[[UIWindow alloc]initWithWindowScene:scene];gameWindow.frame=scene.coordinateSpace.bounds;gameWindow.windowLevel=UIWindowLevelNormal+5;gameWindow.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;gameWindow.rootViewController=[SBGameController new];[gameWindow makeKeyAndVisible];
}
static BOOL TriggerWord(NSString *text) {if(![text isKindOfClass:NSString.class]||text.length>32)return NO;return [[[text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString] isEqualToString:@"tetris"];}
static char checkKey;
static void CheckSelection(UIView<UITextInput> *view) {
 if(!NSThread.isMainThread||gameWindow)return;
 if([view isKindOfClass:UITextField.class]&&((UITextField *)view).secureTextEntry)return;
 if([view isKindOfClass:UITextView.class]&&((UITextView *)view).secureTextEntry)return;
 NSUInteger generation=[objc_getAssociatedObject(view,&checkKey) unsignedIntegerValue]+1;objc_setAssociatedObject(view,&checkKey,@(generation),OBJC_ASSOCIATION_RETAIN_NONATOMIC);
 __weak UIView<UITextInput> *weak=view;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,450*NSEC_PER_MSEC),dispatch_get_main_queue(),^{
  UIView<UITextInput> *v=weak;if(!v||!v.window||[objc_getAssociatedObject(v,&checkKey) unsignedIntegerValue]!=generation)return;
  UITextRange *range=v.selectedTextRange;if(!range||range.empty)return;
  NSInteger length=[v offsetFromPosition:range.start toPosition:range.end];if(length<=0||length>32)return;
  if(TriggerWord([v textInRange:range]))ShowGame(v);
 });
}
@interface SBWebObserver : NSObject<UIGestureRecognizerDelegate>
+ (instancetype)shared;
- (void)selectionGesture:(UILongPressGestureRecognizer *)recognizer;
@end
@implementation SBWebObserver
+ (instancetype)shared {static SBWebObserver *o;static dispatch_once_t once;dispatch_once(&once,^{o=[self new];});return o;}
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)a shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)b{return YES;}
- (void)selectionGesture:(UILongPressGestureRecognizer *)r {
 if(r.state!=UIGestureRecognizerStateEnded||gameWindow)return;
 __weak WKWebView *weak=(WKWebView *)r.view;
 dispatch_after(dispatch_time(DISPATCH_TIME_NOW,650*NSEC_PER_MSEC),dispatch_get_main_queue(),^{WKWebView *v=weak;if(!v.window||gameWindow)return;
  // Only return the exact boolean match. Never export selected page text.
  [v evaluateJavaScript:@"(()=>{const s=window.getSelection();return !!s&&s.toString().trim().toLowerCase()==='tetris';})()" completionHandler:^(id result,NSError *error){WKWebView *web=weak;if(!error&&[result isKindOfClass:NSNumber.class]&&[result boolValue]&&web.window)ShowGame(web);}];
 });
}
@end
%group SelectionHooks
%hook UITextView
- (void)setSelectedTextRange:(UITextRange *)range {%orig;CheckSelection(self);}
- (void)setSelectedRange:(NSRange)range {%orig;CheckSelection(self);}
%end
%hook UITextField
- (void)setSelectedTextRange:(UITextRange *)range {%orig;CheckSelection(self);}
%end
%hook WKWebView
- (void)didMoveToWindow {%orig;static char installed;if(!self.window||objc_getAssociatedObject(self,&installed))return;
 UILongPressGestureRecognizer *r=[[UILongPressGestureRecognizer alloc]initWithTarget:[SBWebObserver shared] action:@selector(selectionGesture:)];r.minimumPressDuration=.5;r.cancelsTouchesInView=NO;r.delaysTouchesBegan=NO;r.delaysTouchesEnded=NO;r.delegate=[SBWebObserver shared];[self addGestureRecognizer:r];objc_setAssociatedObject(self,&installed,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);}
%end
%end
%ctor {@autoreleasepool {
 NSString *bundle=NSBundle.mainBundle.bundleIdentifier;NSString *path=NSBundle.mainBundle.bundlePath;
 if(![path hasSuffix:@".app"]||[bundle isEqualToString:@"com.apple.springboard"]||[bundle isEqualToString:@"com.apple.Preferences"])return;
 if(NSProcessInfo.processInfo.operatingSystemVersion.majorVersion!=16)return;
 %init(SelectionHooks);
}}
