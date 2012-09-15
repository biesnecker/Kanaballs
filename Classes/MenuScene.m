//
//  MenuScene.m
//  KanaBalls
//
//  Created by John Biesnecker on 2/5/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import "MenuScene.h"
#import "GameScene.h"
#import "ScoreScene.h"
#import "OptionsScene.h"

#define kMenuSceneBackground 1
#define kMenuSceneSplash 2
#define kMenuSceneLabelGo 3
#define kMenuSceneLabelScores 4
#define kMenuSceneLabelOptions 5


@implementation MenuScene

+ (id)scene {
	Scene *scene = [Scene node];
	Layer *layer = [MenuScene node];
	[scene addChild:layer];
	return scene;
}


- (id)init {
	if ((self = [super init])) {
		self.isTouchEnabled = YES;
		Sprite *background = [Sprite spriteWithFile:@"mainscreen.jpg"];
		background.position = ccp(240.0, 160.0);
		[background setTag:kMenuSceneBackground];
		[self addChild:background];
		
		Sprite *background2 = [Sprite spriteWithFile:@"mainscreen_splash.jpg"];
		background2.position = ccp(240.0, 160.0);
		[background2 setTag:kMenuSceneSplash];
		id fadeAnimation = [Sequence actions:[FadeOut actionWithDuration:0.5], [CallFunc actionWithTarget:self selector:@selector(removeSplash)], nil];
		[background2 runAction:fadeAnimation];
		[self addChild:background2 z:99];
		
		Label *startButtonLabel = [Label labelWithString:@"START" fontName:@"Helvetica" fontSize:13.0];
		startButtonLabel.position = ccp(420.0, 50.0);
		[startButtonLabel setTag:kMenuSceneLabelGo];
		startButtonLabel.color = ccWHITE;
		[self addChild:startButtonLabel];
		
		Label *scoresButtonLabel = [Label labelWithString:@"SCORES" fontName:@"Helvetica" fontSize:13.0];
		scoresButtonLabel.position = ccp(420.0, 125.0);
		[scoresButtonLabel setTag:kMenuSceneLabelScores];
		scoresButtonLabel.color = ccWHITE;
		[self addChild:scoresButtonLabel];
		
		Label *optionsButtonLabel = [Label labelWithString:@"OPTIONS" fontName:@"Helvetica" fontSize:13.0];
		optionsButtonLabel.position = ccp(345.0, 50.0);
		[optionsButtonLabel setTag:kMenuSceneLabelOptions];
		optionsButtonLabel.color = ccWHITE;
		[self addChild:optionsButtonLabel];
		
	}
	return self;
}

- (void)removeSplash {
	[self removeChildByTag:kMenuSceneSplash cleanup:YES];
}

- (BOOL)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {	
	CGPoint touchLocation = [self convertTouchToNodeSpace:[touches anyObject]];
	CGRect startButtonRect = CGRectMake(385.0, 15.0, 70.0, 70.0);
	CGRect scoreButtonRect = CGRectMake(385.0, 90.0, 70.0, 70.0);
	CGRect optionButtonRect = CGRectMake(310.0, 15.0, 70.0, 70.0);
	
	if (CGRectContainsPoint(startButtonRect, touchLocation)) {
		[[Director sharedDirector] replaceScene:[FadeTransition transitionWithDuration:1 scene:[GameScene scene] withColor:ccBLACK]];
	} else if (CGRectContainsPoint(scoreButtonRect, touchLocation)) {
		[[Director sharedDirector] replaceScene:[FadeTransition transitionWithDuration:1 scene:[ScoreScene scene] withColor:ccBLACK]];
	} else if (CGRectContainsPoint(optionButtonRect, touchLocation)) {
		[[Director sharedDirector] replaceScene:[FadeTransition transitionWithDuration:1 scene:[OptionsScene scene] withColor:ccBLACK]];
	}
	
	
	return kEventHandled;
}


- (void)dealloc {
	[super dealloc];
}

@end
