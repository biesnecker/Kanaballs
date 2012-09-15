//
//  OptionsScene.m
//  KanaBalls
//
//  Created by John Biesnecker on 2/5/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import "OptionsScene.h"
#import "FMDatabase.h"
#import "MenuScene.h"
#import "KanaBallsAppDelegate.h"


@implementation OptionsScene

@synthesize optionSetting;

+ (id)scene {
	Scene *scene = [Scene node];
	Layer *layer = [OptionsScene node];
	[scene addChild:layer];
	return scene;
}

- (id)init {
	if ((self = [super init])) {
		
		self.isTouchEnabled = YES;
		Sprite *background = [Sprite spriteWithFile:@"options.jpg"];
		background.position = ccp(240.0, 160.0);
		[self addChild:background];
		
		Label *promptLabel = [Label labelWithString:@"Show only" fontName:@"Helvetica" fontSize:16.0];
		[promptLabel setColor:ccGRAY];
		[promptLabel setAnchorPoint:ccp(0.0, 0.5)];
		[promptLabel setPosition:ccp(265.0, 220.0)];
		[self addChild:promptLabel];
		
		Label *hiraganaLabel = [Label labelWithString:@"Hiragana" fontName:@"Helvetica" fontSize:16.0];
		[hiraganaLabel setTag:3];
		[hiraganaLabel setColor:ccGRAY];
		[hiraganaLabel setAnchorPoint:ccp(0.0, 0.5)];
		[hiraganaLabel setPosition:ccp(295.0, 180.0)];
		[self addChild:hiraganaLabel];
		
		Sprite *hiraganaSprite = [Sprite spriteWithFile:@"tinyball.png"];
		[hiraganaSprite setTag:0];
		[hiraganaSprite setOpacity:0];
		[hiraganaSprite setAnchorPoint:ccp(0.0, 0.5)];
		[hiraganaSprite setPosition:ccp(265.0, 180.0)];
		[self addChild:hiraganaSprite];

		Label *katakanaLabel = [Label labelWithString:@"Katakana" fontName:@"Helvetica" fontSize:16.0];
		[katakanaLabel setTag:4];
		[katakanaLabel setColor:ccGRAY];
		[katakanaLabel setAnchorPoint:ccp(0.0, 0.5)];
		[katakanaLabel setPosition:ccp(295.0, 140.0)];
		[self addChild:katakanaLabel];
		
		Sprite *katakanaSprite = [Sprite spriteWithFile:@"tinyball.png"];
		[katakanaSprite setTag:1];
		[katakanaSprite setOpacity:0];
		[katakanaSprite setAnchorPoint:ccp(0.0, 0.5)];
		[katakanaSprite setPosition:ccp(265.0, 140.0)];
		[self addChild:katakanaSprite];
		
		Label *bothLabel = [Label labelWithString:@"Hiragana + Katakana" fontName:@"Helvetica" fontSize:16.0];
		[bothLabel setTag:5];
		[bothLabel setColor:ccGRAY];
		[bothLabel setAnchorPoint:ccp(0.0, 0.5)];
		[bothLabel setPosition:ccp(295.0, 100.0)];
		[self addChild:bothLabel];
		
		Sprite *bothSprite = [Sprite spriteWithFile:@"tinyball.png"];
		[bothSprite setTag:2];
		[bothSprite setOpacity:0];
		[bothSprite setAnchorPoint:ccp(0.0, 0.5)];
		[bothSprite setPosition:ccp(265.0, 100.0)];
		[self addChild:bothSprite];
		
		FMDatabase *db = [AppDelegate db];
		FMResultSet *rs = [db executeQuery:@"SELECT value FROM options WHERE key = 'kanaset'"];
		[rs next];
		optionSetting = [rs intForColumn:@"value"];
		[rs close];
		
		Label *selectedLabel = (Label*)[self getChildByTag:(optionSetting + 3)];
		[selectedLabel setColor:ccWHITE];
		Sprite *selectedSprite = (Sprite*)[self getChildByTag:optionSetting];
		[selectedSprite setOpacity:255];
		
	}
	return self;
}

- (void)setOption:(NSInteger)val {
	if (val == optionSetting) return; // didn't change
	NSInteger spriteTag = val;
	NSInteger labelTag = val + 3;
	for (int idx = 0; idx < 3; idx++) {
		if (idx == val) {
			// mark this as set
			Label *selectedLabel = (Label*)[self getChildByTag:(labelTag)];
			[selectedLabel setColor:ccWHITE];
			Sprite *selectedSprite = (Sprite*)[self getChildByTag:spriteTag];
			[selectedSprite runAction:[FadeIn actionWithDuration:0.25]];
		} else if (idx == optionSetting) {
			// mark this as unset
			Label *selectedLabel = (Label*)[self getChildByTag:(optionSetting + 3)];
			[selectedLabel setColor:ccGRAY];
			Sprite *selectedSprite = (Sprite*)[self getChildByTag:optionSetting];
			[selectedSprite runAction:[FadeOut actionWithDuration:0.25]];
		}
	}
	optionSetting = val;
	FMDatabase *db = [AppDelegate db];
	[db executeUpdate:[NSString stringWithFormat:@"UPDATE options SET value = %d WHERE key = 'kanaset'", val]];
}

- (BOOL)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {	
	CGPoint touchLocation = [self convertTouchToNodeSpace:[touches anyObject]];
	CGRect backButtonRect = CGRectMake(255.0, 15.0, 70.0, 25.0);
	CGRect hiraganaRect = CGRectMake(255.0, 165.0, 200.0, 30.0);
	CGRect katakanaRect = CGRectMake(255.0, 125.0, 200.0, 30.0);
	CGRect bothRect = CGRectMake(255.0, 85.0, 200.0, 30.0);
	
	if (CGRectContainsPoint(backButtonRect, touchLocation)) {
		[[Director sharedDirector] replaceScene:[FadeTransition transitionWithDuration:1 scene:[MenuScene scene] withColor:ccBLACK]];
	} else if (CGRectContainsPoint(hiraganaRect, touchLocation)) {
		DLog(@"Hiragana");
		[self setOption:0];
	} else if (CGRectContainsPoint(katakanaRect, touchLocation)) {
		DLog(@"Katakana");
		[self setOption:1];
	} else if (CGRectContainsPoint(bothRect, touchLocation)) {
		DLog(@"Both");
		[self setOption:2];
	} 
	
	return kEventHandled;
}

- (void)dealloc {
	[super dealloc];
}


@end
