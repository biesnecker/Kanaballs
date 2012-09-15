//
//  PauseLayer.m
//  KanaBalls
//
//  Created by John Biesnecker on 2/4/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import "PauseLayer.h"
#import "GameScene.h"
#import "KanaBallsAppDelegate.h"
#import "FMDatabase.h"


#define kPauseLayerTagBackground 1
#define kPauseLayerTagPrompt 2
#define kPauseLayerNewButton 3
#define kPauseLayerQuitButton 4

@implementation PauseLayer

@synthesize currentMode;

- (id)initWithMode:(NSInteger)mode {
	
	NSString *filename = nil;
	if (mode == kPauseLayerPauseMode) {
		filename = @"pause.jpg";
	} else if (mode == kPauseLayerNewMode) {
		filename = @"begin.jpg";
	}
	
	if ((self = [super initWithFile:filename])) {
		self.currentMode = mode;
		
		
		Label *promptLabel = [Label labelWithString:@"" fontName:@"Helvetica" fontSize:18.0];
		promptLabel.position = ccp(240.0, 160.0);
		[promptLabel setTag:kPauseLayerTagPrompt];
		
		
		if (mode == kPauseLayerPauseMode) {
			[promptLabel setString:@"double tap to continue"];
			promptLabel.opacity = 0;
			
			Label *newButtonLabel = [Label labelWithString:@"QUIT" fontName:@"Helvetica" fontSize:17.0];
			newButtonLabel.position = ccp(240.0, 60.0);
			[newButtonLabel setTag:kPauseLayerQuitButton];
			newButtonLabel.color = ccWHITE;
			newButtonLabel.opacity = 0;
			[self addChild:newButtonLabel z:1];
			
		} else if (mode == kPauseLayerNewMode) {
			[promptLabel setString:@"double tap to begin"];
			promptLabel.opacity = 255;
			
		}
		[self addChild:promptLabel z:1];

	}
	return self;
	
}

- (id)initWithScore:(NSInteger)score {
	if ((self = [super initWithFile:@"gameover.jpg"])) {
		self.currentMode = kPauseLayerOverMode;
		
		Label *promptLabel = [Label labelWithString:[NSString stringWithFormat:@"final score: %d", score] fontName:@"Helvetica" fontSize:18.0];
		promptLabel.position = ccp(240.0, 160.0);
		[promptLabel setTag:kPauseLayerTagPrompt];
		promptLabel.opacity = 0;
		[self addChild:promptLabel z:1];
		
		Label *newButtonLabel = [Label labelWithString:@"NEW" fontName:@"Helvetica" fontSize:17.0];
		newButtonLabel.position = ccp(160.0, 60.0);
		[newButtonLabel setTag:kPauseLayerNewButton];
		newButtonLabel.color = ccWHITE;
		newButtonLabel.opacity = 0;
		[self addChild:newButtonLabel z:1];
		
		Label *quitButtonLabel = [Label labelWithString:@"QUIT" fontName:@"Helvetica" fontSize:18.0];
		quitButtonLabel.position = ccp(320.0, 60.0);
		[quitButtonLabel setTag:kPauseLayerQuitButton];
		quitButtonLabel.color = ccWHITE;
		quitButtonLabel.opacity = 0;
		[self addChild:quitButtonLabel z:1];
		[self recordScore:score];
	}
	return self;
}

- (void)recordScore:(NSInteger)s {
	if (s > 0) {
		FMDatabase *db = [AppDelegate db];
		NSString *query = [NSString stringWithFormat:@"INSERT INTO highscores(date, score) VALUES(%f, %d)", [[NSDate date] timeIntervalSince1970], s];
		[db executeUpdate:query];

	}
}

- (void)fadeLabel {
	Label *l = (Label*)[self getChildByTag:kPauseLayerTagPrompt];
	[l runAction:[FadeOut actionWithDuration:0.25]];
	l = (Label*)[self getChildByTag:kPauseLayerNewButton];
	[l runAction:[FadeOut actionWithDuration:0.25]];
	l = (Label*)[self getChildByTag:kPauseLayerQuitButton];
	[l runAction:[FadeOut actionWithDuration:0.25]];
}

- (void)fadeLabelIn {
	Label *l = (Label*)[self getChildByTag:kPauseLayerTagPrompt];
	[l runAction:[FadeIn actionWithDuration:0.25]];
	l = (Label*)[self getChildByTag:kPauseLayerNewButton];
	[l runAction:[FadeIn actionWithDuration:0.25]];
	l = (Label*)[self getChildByTag:kPauseLayerQuitButton];
	[l runAction:[FadeIn actionWithDuration:0.25]];
}



- (void)dealloc {
	[super dealloc];
}


@end
