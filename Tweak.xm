#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <objc/runtime.h>
#import "Game.h"
#import "TriggerWords.h"
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
// Original, procedural bevel texture: no bundled artwork or network assets.
static void DrawBlock(CGRect r, int type) {
 UIColor *base=PieceColor(type);[base setFill];UIRectFill(r);
 CGFloat b=MAX(1,floor(r.size.width*.13));
 [[UIColor colorWithWhite:1 alpha:.40] setFill];
 UIRectFill(CGRectMake(r.origin.x,r.origin.y,r.size.width,b));
 UIRectFill(CGRectMake(r.origin.x,r.origin.y,b,r.size.height-b));
 [[UIColor colorWithWhite:0 alpha:.30] setFill];
 UIRectFill(CGRectMake(r.origin.x,CGRectGetMaxY(r)-b,r.size.width,b));
 UIRectFill(CGRectMake(CGRectGetMaxX(r)-b,r.origin.y+b,b,r.size.height-b));
 [[UIColor colorWithWhite:1 alpha:.12] setFill];UIRectFill(CGRectInset(r,b*2,b*2));
}
static void PixelText(NSString *text,CGPoint origin,CGFloat scale,UIColor *color) {
 static NSDictionary *glyphs;static dispatch_once_t once;dispatch_once(&once,^{glyphs=@{@"0":@"01110100011001110101110011000101110",
@"1":@"00100011000010000100001000010001110",
@"2":@"01110100010000100010001000100011111",
@"3":@"11110000010000101110000010000111110",
@"4":@"00010001100101010010111110001000010",
@"5":@"11111100001000011110000010000111110",
@"6":@"01110100001000011110100011000101110",
@"7":@"11111000010001000100010000100001000",
@"8":@"01110100011000101110100011000101110",
@"9":@"01110100011000101111000010000101110",
@"A":@"01110100011000111111100011000110001",
@"B":@"11110100011000111110100011000111110",
@"C":@"01111100001000010000100001000001111",
@"D":@"11110100011000110001100011000111110",
@"E":@"11111100001000011110100001000011111",
@"F":@"11111100001000011110100001000010000",
@"G":@"01111100001000010111100011000101110",
@"H":@"10001100011000111111100011000110001",
@"I":@"11111001000010000100001000010011111",
@"L":@"10000100001000010000100001000011111",
@"N":@"10001110011100110101100111001110001",
@"O":@"01110100011000110001100011000101110",
@"P":@"11110100011000111110100001000010000",
@"R":@"11110100011000111110101001001010001",
@"S":@"01111100001000001110000010000111110",
@"T":@"11111001000010000100001000010000100",
@"U":@"10001100011000110001100011000101110",
@"V":@"10001100011000110001100010101000100",
@"W":@"10001100011000110101101011010101010",
@"X":@"10001100010101000100010101000110001",
@"Y":@"10001100010101000100001000010000100"};});
 [color setFill];for(NSUInteger n=0;n<text.length;n++){
  NSString *glyph=glyphs[[text substringWithRange:NSMakeRange(n,1)]];if(!glyph)continue;
  for(int y=0;y<7;y++)for(int x=0;x<5;x++)if([glyph characterAtIndex:y*5+x]=='1')UIRectFill(CGRectMake(origin.x+(n*6+x)*scale,origin.y+y*scale,scale,scale));
 }
}
static void RetroPanel(CGRect rect) {
 [[UIColor colorWithRed:.28 green:.40 blue:.64 alpha:1] setFill];UIRectFill(rect);
 [[UIColor colorWithRed:.78 green:.84 blue:.96 alpha:1] setFill];UIRectFill(CGRectInset(rect,1,1));
 [[UIColor colorWithRed:.055 green:.075 blue:.14 alpha:1] setFill];UIRectFill(CGRectInset(rect,3,3));
}
@interface SBScorePanel : UIView
@property(nonatomic,assign) Game *game;
@property(nonatomic,assign) int best;
@end
@implementation SBScorePanel
- (void)drawRect:(CGRect)rect {
 if(!self.game)return;RetroPanel(self.bounds);
 NSArray *titles=@[@"TOP",@"SCORE",@"LEVEL",@"LINES"];
 NSArray *values=@[[NSString stringWithFormat:@"%06d",self.best],[NSString stringWithFormat:@"%06d",self.game->score],[NSString stringWithFormat:@"%02d",self.game->level],[NSString stringWithFormat:@"%03d",self.game->lines]];
 for(int i=0;i<4;i++){CGFloat y=9+i*38;PixelText(titles[i],CGPointMake(9,y),2,[UIColor colorWithRed:.62 green:.76 blue:1 alpha:1]);
 NSString *value=values[i];CGFloat scale=MIN(2,(self.bounds.size.width-18)/(value.length*6.0));PixelText(value,CGPointMake(9,y+17),scale,UIColor.whiteColor);}
}
@end
@interface SBBoard : UIView
@property(nonatomic,assign) Game *game;
@end
@implementation SBBoard
- (void)drawRect:(CGRect)rect {
 Game *g=self.game;if(!g)return;CGContextRef c=UIGraphicsGetCurrentContext();
 CGFloat s=floor(MIN((self.bounds.size.width-4)/10,(self.bounds.size.height-4)/20)*2)/2;
 CGFloat ox=(self.bounds.size.width-s*10)/2,oy=(self.bounds.size.height-s*20)/2;
 CGRect field=CGRectMake(ox-2,oy-2,s*10+4,s*20+4);
 RetroPanel(field);
 [[UIColor colorWithWhite:.055 alpha:1] setFill];UIRectFill(CGRectInset(field,2,2));
 for(int y=0;y<20;y++)for(int x=0;x<10;x++){
  CGRect r=CGRectMake(ox+x*s+.6,oy+y*s+.6,s-1.2,s-1.2);
  if(g->board[y][x])DrawBlock(r,g->board[y][x]);else{[[UIColor colorWithWhite:.095 alpha:1] setFill];UIRectFill(r);}
 }
 if(!g->over){int ghost=g->y;while(fits(g,g->x,ghost+1,g->rot))ghost++;
  for(int pass=0;pass<2;pass++)for(int j=0;j<4;j++)for(int i=0;i<4;i++)if(cell(g->type,g->rot,i,j)){
   int y=(pass?g->y:ghost)+j;if(y<0)continue;
   CGRect r=CGRectMake(ox+(g->x+i)*s+.6,oy+y*s+.6,s-1.2,s-1.2);
   if(pass)DrawBlock(r,g->type+1);else{[[PieceColor(g->type+1) colorWithAlphaComponent:.65] setStroke];CGContextSetLineWidth(c,1);CGContextStrokeRect(c,CGRectInset(r,1,1));}
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
 RetroPanel(self.bounds);PixelText(self.title,CGPointMake(8,6),2,UIColor.whiteColor);
 if(self.type<0)return;
 CGFloat size=9;for(int y=0;y<4;y++)for(int x=0;x<4;x++)if(cell(self.type,0,x,y))DrawBlock(CGRectMake(24+x*size,24+y*size,size-1,size-1),self.type+1);
}
@end
// Custom, bevelled arcade controls, with original pixel captions.
@interface SBControl : UIButton
@property(nonatomic,copy) NSString *caption;
@property(nonatomic,copy) NSString *retroSymbol;
@property(nonatomic,assign) BOOL utility;
@property(nonatomic,assign) BOOL prominent;
@end
@implementation SBControl
- (void)setHighlighted:(BOOL)value {[super setHighlighted:value];[self setNeedsDisplay];}
- (void)drawRect:(CGRect)r {
 CGFloat w=self.bounds.size.width,h=self.bounds.size.height;
 UIColor *base=self.prominent?[UIColor colorWithRed:.12 green:.28 blue:.64 alpha:1]:[UIColor colorWithRed:.14 green:.19 blue:.31 alpha:1];
 [base setFill];UIRectFill(self.bounds);CGFloat b=self.highlighted?1:3;
 [[UIColor colorWithWhite:1 alpha:.36] setFill];UIRectFill(CGRectMake(0,0,w,b));UIRectFill(CGRectMake(0,0,b,h));
 [[UIColor colorWithWhite:0 alpha:.55] setFill];UIRectFill(CGRectMake(0,h-b,w,b));UIRectFill(CGRectMake(w-b,0,b,h));
 CGFloat offset=self.highlighted?2:0;
 if(!self.utility){
 CGContextRef c=UIGraphicsGetCurrentContext();CGContextSaveGState(c);CGContextTranslateCTM(c,w/2-12,7+offset);CGContextSetLineWidth(c,3);CGContextSetLineCap(c,kCGLineCapSquare);CGContextSetStrokeColorWithColor(c,UIColor.whiteColor.CGColor);
 NSString *symbol=self.retroSymbol;
 if([symbol isEqualToString:@"left"]){CGContextMoveToPoint(c,16,2);CGContextAddLineToPoint(c,6,12);CGContextAddLineToPoint(c,16,22);CGContextMoveToPoint(c,6,12);CGContextAddLineToPoint(c,23,12);}
 else if([symbol isEqualToString:@"right"]){CGContextMoveToPoint(c,8,2);CGContextAddLineToPoint(c,18,12);CGContextAddLineToPoint(c,8,22);CGContextMoveToPoint(c,1,12);CGContextAddLineToPoint(c,18,12);}
 else if([symbol isEqualToString:@"down"]){CGContextMoveToPoint(c,2,8);CGContextAddLineToPoint(c,12,18);CGContextAddLineToPoint(c,22,8);}
 else if([symbol isEqualToString:@"hold"]){CGContextMoveToPoint(c,1,6);CGContextAddLineToPoint(c,22,6);CGContextAddLineToPoint(c,17,1);CGContextMoveToPoint(c,22,18);CGContextAddLineToPoint(c,1,18);CGContextAddLineToPoint(c,6,23);}
 else {BOOL ccw=[symbol isEqualToString:@"ccw"];if(ccw){CGContextTranslateCTM(c,24,0);CGContextScaleCTM(c,-1,1);}CGContextAddArc(c,12,12,9,.2,5.45,0);CGContextMoveToPoint(c,18,0);CGContextAddLineToPoint(c,19,7);CGContextAddLineToPoint(c,12,6);}
 CGContextStrokePath(c);CGContextRestoreGState(c);
 }
 NSString *caption=self.caption?:@"";CGFloat scale=MIN(2,(w-12)/MAX(1,caption.length*6.0));CGFloat textWidth=(caption.length*6-1)*scale;
 PixelText(caption,CGPointMake((w-textWidth)/2,(self.utility?(h-14)/2:36)+offset),scale,UIColor.whiteColor);
}
@end
@interface SBGameController : UIViewController {
 Game _game; BOOL _paused; double _lastTick,_fall,_lock,_pressedAt; int _pressed; int _best; BOOL _appeared; BOOL _closing; BOOL _entryRunning;
}
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) UIStackView *surface;
@property(nonatomic,strong) UIButton *pauseButton;
@property(nonatomic,strong) SBBoard *board;
@property(nonatomic,strong) SBScorePanel *stats;
@property(nonatomic,strong) UILabel *logo;
@property(nonatomic,copy) NSString *entryWord;
@property(nonatomic,strong) UIImage *entryImage;
@property(nonatomic,assign) CGRect entryRect;
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
 UIScrollView *scroll=[[UIScrollView alloc]init];scroll.translatesAutoresizingMaskIntoConstraints=NO;scroll.delaysContentTouches=NO;scroll.showsVerticalScrollIndicator=NO;[self.view addSubview:scroll];
 UIStackView *root=[[UIStackView alloc]init];self.surface=root;root.axis=UILayoutConstraintAxisVertical;root.spacing=8;root.semanticContentAttribute=UISemanticContentAttributeForceLeftToRight;root.translatesAutoresizingMaskIntoConstraints=NO;[scroll addSubview:root];
 UILayoutGuide *safe=self.view.safeAreaLayoutGuide;
 [NSLayoutConstraint activateConstraints:@[[scroll.leadingAnchor constraintEqualToAnchor:safe.leadingAnchor],[scroll.trailingAnchor constraintEqualToAnchor:safe.trailingAnchor],[scroll.topAnchor constraintEqualToAnchor:safe.topAnchor],[scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],[root.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor constant:16],[root.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor constant:-16],[root.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor constant:8],[root.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor constant:-8],[root.widthAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.widthAnchor constant:-32],[root.heightAnchor constraintGreaterThanOrEqualToAnchor:scroll.frameLayoutGuide.heightAnchor constant:-16]]];
 NSLayoutConstraint *preferredHeight=[root.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor constant:-16];preferredHeight.priority=750;preferredHeight.active=YES;
 UILabel *title=[[UILabel alloc]init];self.logo=title;UIFont *font=[UIFont systemFontOfSize:34 weight:UIFontWeightBlack];UIFontDescriptor *fd=[font.fontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitItalic];if(fd)font=[UIFont fontWithDescriptor:fd size:34];
 NSString *heading=self.entryWord.length?[self.entryWord uppercaseString]:@"TETRIS";
 title.attributedText=[[NSAttributedString alloc]initWithString:heading attributes:@{NSFontAttributeName:font,NSKernAttributeName:@(-1.0),NSForegroundColorAttributeName:[UIColor colorWithRed:1 green:.66 blue:.20 alpha:1],NSStrokeColorAttributeName:[UIColor colorWithWhite:.98 alpha:1],NSStrokeWidthAttributeName:@(-2)}];title.accessibilityLabel=heading;title.textAlignment=NSTextAlignmentCenter;title.adjustsFontSizeToFitWidth=YES;title.minimumScaleFactor=.5;
 [title.heightAnchor constraintEqualToConstant:44].active=YES;[root addArrangedSubview:title];
 self.pauseButton=[self button:@"Пауза" caption:@"PAUSE" symbol:@"" utility:YES prominent:NO action:^{[weakSelf pauseAction];}];
 NSArray *utilities=@[[self button:@"Мгновенный сброс фигуры" caption:@"DROP" symbol:@"" utility:YES prominent:YES action:^{[weakSelf dropAction];}],self.pauseButton,[self button:@"Новая игра" caption:@"RESET" symbol:@"" utility:YES prominent:NO action:^{[weakSelf restartAction];}],[self button:@"Выйти" caption:@"EXIT" symbol:@"" utility:YES prominent:NO action:^{[weakSelf closeGame];}]];
 UIStackView *toolbar=[[UIStackView alloc]initWithArrangedSubviews:utilities];toolbar.spacing=8;toolbar.distribution=UIStackViewDistributionFillEqually;[toolbar.heightAnchor constraintEqualToConstant:44].active=YES;[root addArrangedSubview:toolbar];
 self.stats=[[SBScorePanel alloc]init];self.stats.game=&_game;[self.stats.heightAnchor constraintEqualToConstant:168].active=YES;
 self.hold=[[SBPreview alloc]init];self.hold.title=@"HOLD";[self.hold.heightAnchor constraintEqualToConstant:44].active=YES;
 NSMutableArray *previews=[NSMutableArray array];for(int i=0;i<3;i++){SBPreview *p=[[SBPreview alloc]init];p.title=[NSString stringWithFormat:@"NEXT %d",i+1];[p.heightAnchor constraintEqualToConstant:44].active=YES;[previews addObject:p];}self.previews=previews;
 UIStackView *sidebar=[[UIStackView alloc]initWithArrangedSubviews:@[self.stats,previews[0],previews[1],previews[2],self.hold]];sidebar.axis=UILayoutConstraintAxisVertical;sidebar.spacing=6;[sidebar.widthAnchor constraintEqualToConstant:96].active=YES;[sidebar addArrangedSubview:[UIView new]];
 self.board=[[SBBoard alloc]init];self.board.backgroundColor=UIColor.clearColor;self.board.game=&_game;
 UIStackView *stage=[[UIStackView alloc]initWithArrangedSubviews:@[self.board,sidebar]];stage.spacing=8;[stage.heightAnchor constraintGreaterThanOrEqualToConstant:380].active=YES;[root addArrangedSubview:stage];
 self.status=[[UILabel alloc]init];self.status.font=[UIFont systemFontOfSize:14 weight:UIFontWeightMedium];self.status.textColor=[UIColor colorWithWhite:.78 alpha:1];self.status.textAlignment=NSTextAlignmentCenter;[self.status.heightAnchor constraintEqualToConstant:22].active=YES;[root addArrangedSubview:self.status];
 // Only movement, rotation and hold live in the lower thumb area.
 UIButton *left=[self repeatButton:@"Влево" caption:@"LEFT" symbol:@"left" tag:0];
 UIButton *right=[self repeatButton:@"Вправо" caption:@"RIGHT" symbol:@"right" tag:1];
 UIButton *ccw=[self button:@"Поворот против часовой стрелки" caption:@"B" symbol:@"ccw" utility:NO prominent:YES action:^{[weakSelf rotate:-1];}];
 UIButton *cw=[self button:@"Поворот по часовой стрелке" caption:@"A" symbol:@"cw" utility:NO prominent:YES action:^{[weakSelf rotate:1];}];
 NSArray *row1=@[left,right,ccw,cw];
 NSArray *row2=@[[self repeatButton:@"Мягкий спуск" caption:@"DOWN" symbol:@"down" tag:2],[self button:@"Удержать фигуру" caption:@"HOLD" symbol:@"hold" utility:NO prominent:NO action:^{[weakSelf holdAction];}]];
 for(NSArray *buttons in @[row1,row2]){UIStackView *r=[[UIStackView alloc]initWithArrangedSubviews:buttons];r.spacing=8;r.distribution=UIStackViewDistributionFillEqually;[r.heightAnchor constraintEqualToConstant:56].active=YES;[root addArrangedSubview:r];}
 [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(background:) name:UIApplicationWillResignActiveNotification object:nil];
 self.timer=[NSTimer timerWithTimeInterval:.05 repeats:YES block:^(NSTimer *t){[weakSelf tick];}];[NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];[self refresh];
}
- (void)viewDidAppear:(BOOL)animated {
 [super viewDidAppear:animated];if(_appeared)return;_appeared=YES;[self.view layoutIfNeeded];
 BOOL reduce=UIAccessibilityIsReduceMotionEnabled();self.surface.alpha=0;_entryRunning=YES;self.surface.userInteractionEnabled=NO;
 BOOL fly=!reduce&&self.entryImage&&!CGRectIsNull(self.entryRect)&&!CGRectIsEmpty(self.entryRect);
 if(!fly){[UIView animateWithDuration:reduce?.15:.30 animations:^{self.surface.alpha=1;} completion:^(BOOL done){self->_entryRunning=NO;self.surface.userInteractionEnabled=YES;self.entryImage=nil;}];return;}
 self.logo.alpha=0;
 UIImageView *word=[[UIImageView alloc]initWithImage:self.entryImage];word.contentMode=UIViewContentModeScaleAspectFit;word.frame=self.entryRect;word.layer.shadowColor=UIColor.whiteColor.CGColor;word.layer.shadowOpacity=.4;word.layer.shadowRadius=5;[self.view addSubview:word];
 CGRect logoText=[self.logo textRectForBounds:self.logo.bounds limitedToNumberOfLines:1];
 CGRect destination=[self.logo convertRect:logoText toView:self.view];
 [UIView animateWithDuration:.30 animations:^{self.surface.alpha=1;}];
 [UIView animateWithDuration:.62 delay:0 usingSpringWithDamping:.91 initialSpringVelocity:.1 options:0 animations:^{word.frame=destination;} completion:^(BOOL done){[word removeFromSuperview];self.logo.alpha=1;self->_entryRunning=NO;self.surface.userInteractionEnabled=YES;self.entryImage=nil;}];
 [UIView animateWithDuration:.20 delay:.42 options:0 animations:^{word.alpha=0;self.logo.alpha=1;} completion:nil];
}
- (UIButton *)button:(NSString *)name caption:(NSString *)caption symbol:(NSString *)symbol utility:(BOOL)utility prominent:(BOOL)prominent action:(void(^)(void))action {
 SBControl *b=[SBControl buttonWithType:UIButtonTypeCustom];b.caption=caption;b.retroSymbol=symbol;b.utility=utility;b.prominent=prominent;b.backgroundColor=UIColor.clearColor;b.accessibilityLabel=name;b.exclusiveTouch=YES;
 [b addAction:[UIAction actionWithHandler:^(__kindof UIAction *a){action();}] forControlEvents:UIControlEventTouchUpInside];return b;
}
- (UIButton *)repeatButton:(NSString *)name caption:(NSString *)caption symbol:(NSString *)symbol tag:(NSInteger)tag {
 UIButton *b=[self button:name caption:caption symbol:symbol utility:NO prominent:NO action:^{}];b.tag=tag;
 [b addTarget:self action:@selector(press:) forControlEvents:UIControlEventTouchDown];
 [b addTarget:self action:@selector(releasePress:) forControlEvents:UIControlEventTouchUpInside|UIControlEventTouchUpOutside|UIControlEventTouchCancel|UIControlEventTouchDragExit];return b;
}
- (void)press:(UIButton *)b{if(_paused||_game.over||_entryRunning)return;_pressed=(int)b.tag;_pressedAt=NSDate.timeIntervalSinceReferenceDate;[self step:_pressed];}
- (void)releasePress:(id)sender{_pressed=-1;}
- (void)step:(int)action {if(_paused||_game.over||_entryRunning)return;if(action==2){if(movePiece(&_game,0,1))_game.score++;}else movePiece(&_game,action==0?-1:1,0);[self refresh];}
- (void)rotate:(int)direction {if(_paused||_game.over||_entryRunning)return;rotatePiece(&_game,direction);[self refresh];}
- (void)holdAction {if(_paused||_game.over||_entryRunning)return;holdPiece(&_game);_fall=_lock=0;[self refresh];}
- (void)dropAction {if(_paused||_game.over||_entryRunning)return;hardDrop(&_game);_fall=_lock=0;[self persist];[self refresh];}
- (void)pauseAction {if(_game.over)return;_paused=!_paused;_pressed=-1;[self persist];[self refresh];}
- (void)restartAction {BOOL wasPaused=_paused;_paused=YES;_pressed=-1;[self refresh];
 UIAlertController *a=[UIAlertController alertControllerWithTitle:@"Новая игра?" message:@"Текущая партия будет сброшена." preferredStyle:UIAlertControllerStyleAlert];__weak typeof(self) w=self;
 [a addAction:[UIAlertAction actionWithTitle:@"Отмена" style:UIAlertActionStyleCancel handler:^(UIAlertAction *x){SBGameController *s=w;if(s){s->_paused=wasPaused;[s refresh];}}]];
 [a addAction:[UIAlertAction actionWithTitle:@"Начать" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *x){SBGameController *s=w;if(s){[s persist];gameNew(&s->_game,arc4random());s->_paused=NO;s->_fall=s->_lock=0;[s persist];[s refresh];}}]];[self presentViewController:a animated:YES completion:nil];}
- (void)tick {double now=NSDate.timeIntervalSinceReferenceDate,dt=fmin(.1,fmax(0,now-_lastTick));_lastTick=now;if(_paused||_game.over||_entryRunning)return;
 if(_pressed>=0&&now-_pressedAt>.22){[self step:_pressed];}
 _fall+=dt;if(_fall>=gravity(&_game)){_fall=0;movePiece(&_game,0,1);}
 if(!fits(&_game,_game.x,_game.y+1,_game.rot)){_lock+=dt;if(_lock>=.45){lockPiece(&_game);_lock=0;_fall=0;[self persist];}}else _lock=0;
 [self refresh];
}
- (void)refresh {
 self.stats.best=MAX(_best,_game.score);[self.stats setNeedsDisplay];
 self.status.text=_game.over?@"Игра окончена · RESET — заново":(_paused?@"Пауза · нажми PLAY":@"A / B — поворот · стрелки — движение");
 self.status.adjustsFontSizeToFitWidth=YES;self.status.minimumScaleFactor=.9;
 self.board.alpha=_paused?.20:1;self.hold.type=_game.held;[self.hold setNeedsDisplay];
 SBControl *pause=(SBControl *)self.pauseButton;NSString *caption=_paused?@"PLAY":@"PAUSE";
 if(![pause.caption isEqualToString:caption]){pause.caption=caption;pause.accessibilityLabel=_paused?@"Продолжить игру":@"Пауза";[pause setNeedsDisplay];}
 for(int i=0;i<3;i++){if(self.previews[i].type!=_game.next[i]){self.previews[i].type=_game.next[i];[self.previews[i] setNeedsDisplay];}}[self.board setNeedsDisplay];
}
- (void)persist {NSUserDefaults *d=NSUserDefaults.standardUserDefaults;_best=MAX(_best,_game.score);[d setInteger:_best forKey:@"SelectBlocks.best.v1"];[d setObject:[NSData dataWithBytes:&_game length:sizeof _game] forKey:@"SelectBlocks.state.v1"];}
- (void)background:(NSNotification *)n{_paused=YES;_pressed=-1;[self persist];[self refresh];}
- (void)closeGame {
 if(_closing)return;_closing=YES;[self persist];[self.timer invalidate];self.timer=nil;[NSNotificationCenter.defaultCenter removeObserver:self];self.view.userInteractionEnabled=NO;
 UIWindow *closingWindow=gameWindow;BOOL reduce=UIAccessibilityIsReduceMotionEnabled();
 [UIView animateWithDuration:reduce?.12:.20 animations:^{self.surface.alpha=0;if(!reduce)self.surface.transform=CGAffineTransformMakeTranslation(0,24);} completion:^(BOOL finished){
  closingWindow.hidden=YES;closingWindow.rootViewController=nil;if(gameWindow==closingWindow)gameWindow=nil;[previousWindow makeKeyWindow];lastClose=NSDate.timeIntervalSinceReferenceDate;
 }];
}
- (void)dealloc {[self.timer invalidate];[NSNotificationCenter.defaultCenter removeObserver:self];}
@end

static BOOL UsableRect(CGRect rect) {
 return !CGRectIsNull(rect)&&!CGRectIsEmpty(rect)&&!CGRectIsInfinite(rect)&&isfinite(rect.origin.x)&&isfinite(rect.origin.y)&&isfinite(rect.size.width)&&isfinite(rect.size.height);
}
static void ShowGame(UIView *source,NSString *selected,CGRect selectedRect,CGFloat webFontSize) {
 if(!NSThread.isMainThread||gameWindow||!TriggerWord(selected)||NSDate.timeIntervalSinceReferenceDate-lastClose<2)return;
 if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
 UIWindow *origin=source.window;UIWindowScene *scene=origin.windowScene;if(!scene||scene.activationState!=UISceneActivationStateForegroundActive)return;
 // Render only the recognized word locally. Never capture the surrounding app.
 NSString *word=[selected stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
 UIFont *font=[UIFont systemFontOfSize:webFontSize>0?MIN(80,MAX(8,webFontSize)):17];UIColor *color=UIColor.labelColor;
 if([source isKindOfClass:UITextView.class]){font=((UITextView *)source).font?:font;color=((UITextView *)source).textColor?:color;}
 else if([source isKindOfClass:UITextField.class]){font=((UITextField *)source).font?:font;color=((UITextField *)source).textColor?:color;}
 CGRect visible=UsableRect(selectedRect)?CGRectIntersection(selectedRect,source.bounds):CGRectNull;
 CGRect originRect=UsableRect(visible)?[source convertRect:visible toView:origin]:CGRectNull;
 UIImage *wordImage=nil;
 if(UsableRect(originRect)&&originRect.size.width<1500&&originRect.size.height<500){
  UIGraphicsImageRenderer *renderer=[[UIGraphicsImageRenderer alloc]initWithSize:originRect.size];
  wordImage=[renderer imageWithActions:^(UIGraphicsImageRendererContext *context){
   NSMutableParagraphStyle *style=[NSMutableParagraphStyle new];style.alignment=NSTextAlignmentNatural;style.lineBreakMode=NSLineBreakByClipping;
   [word drawInRect:CGRectMake(0,0,originRect.size.width,originRect.size.height) withAttributes:@{NSFontAttributeName:font,NSForegroundColorAttributeName:color,NSParagraphStyleAttributeName:style}];
  }];
 }
 previousWindow=origin;
 gameWindow=[[UIWindow alloc]initWithWindowScene:scene];gameWindow.frame=scene.coordinateSpace.bounds;gameWindow.windowLevel=UIWindowLevelNormal+5;gameWindow.overrideUserInterfaceStyle=UIUserInterfaceStyleDark;
 SBGameController *controller=[SBGameController new];controller.entryWord=word;controller.entryImage=wordImage;controller.entryRect=UsableRect(originRect)?[gameWindow convertRect:originRect fromWindow:origin]:CGRectNull;
 [origin endEditing:YES];gameWindow.rootViewController=controller;[gameWindow makeKeyAndVisible];
}
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
  NSInteger length=[v offsetFromPosition:range.start toPosition:range.end];if(length<=0||length>96)return;
  NSString *selected=[v textInRange:range];if(!TriggerWord(selected))return;
  CGRect rect=[v firstRectForRange:range];ShowGame(v,selected,rect,0);
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
  NSArray *aliases=[SBTriggerAliases().allObjects sortedArrayUsingSelector:@selector(compare:)];
  NSData *data=[NSJSONSerialization dataWithJSONObject:aliases options:0 error:nil];NSString *json=[[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
  // Only a recognized name and its local geometry are returned, never arbitrary selected text.
  NSString *script=[NSString stringWithFormat:SBSelectionScriptTemplate,json];
  [v evaluateJavaScript:script completionHandler:^(id result,NSError *error){
   WKWebView *web=weak;if(error||!web.window||![result isKindOfClass:NSDictionary.class])return;
   NSDictionary *d=result;NSString *text=d[@"text"];if(!TriggerWord(text))return;
   CGRect rect=CGRectNull;CGFloat fontSize=17;
   NSArray *geometry=d[@"geometry"];
   if([geometry isKindOfClass:NSArray.class]&&geometry.count==8){
    BOOL numeric=YES;for(id n in geometry)if(![n isKindOfClass:NSNumber.class])numeric=NO;
    if(numeric){CGFloat viewportWidth=[geometry[6] doubleValue];CGFloat scale=viewportWidth>0?web.bounds.size.width/viewportWidth:0;
     if(isfinite(scale)&&scale>0){rect=CGRectMake(web.bounds.origin.x+([geometry[0] doubleValue]-[geometry[4] doubleValue])*scale,web.bounds.origin.y+([geometry[1] doubleValue]-[geometry[5] doubleValue])*scale,[geometry[2] doubleValue]*scale,[geometry[3] doubleValue]*scale);fontSize=[geometry[7] doubleValue]*scale;}
    }
   }
   ShowGame(web,text,rect,fontSize);
  }];
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
