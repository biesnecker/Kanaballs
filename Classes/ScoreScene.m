//
//  ScoreScene.m
//  KanaBalls
//
//  Created by John Biesnecker on 2/5/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import "ScoreScene.h"
#import "FMDatabase.h"
#import "MenuScene.h"
#import "KanaBallsAppDelegate.h"

@implementation ScoreScene

@synthesize scoresArray;

+ (id)scene {
	Scene *scene = [Scene node];
	Layer *layer = [ScoreScene node];
	[scene addChild:layer];
	return scene;
}

- (id)init {
	if ((self = [super init])) {
		
		self.isTouchEnabled = YES;
		Sprite *background = [Sprite spriteWithFile:@"highscores.jpg"];
		background.position = ccp(240.0, 160.0);
		[self addChild:background];

		
		float leftOffset = 265.0;
		float topOffset = 220.0;
		
		float rowOffset = -18.0;
		
		
		NSDateFormatter *df = [[[NSDateFormatter alloc] init] autorelease];
		[df setDateFormat:@"dd MMM yyyy"];
		[df setLocale:[[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"] autorelease]];
		
		FMDatabase *db = [AppDelegate db];
		NSString *query = @"SELECT * FROM highscores ORDER BY score DESC, date DESC LIMIT 10";
		FMResultSet *rs = [db executeQuery:query];
		NSInteger idx = 0;
		while ([rs next]) {
			NSArray *scoreComponents = [NSArray arrayWithObjects:[rs dateForColumn:@"date"], [NSNumber numberWithInt:[rs intForColumn:@"score"]], nil];
			
			float currentRowOffset = topOffset + (idx * rowOffset);
			
			
			Label *col2 = [Label labelWithString:[df stringFromDate:[scoreComponents objectAtIndex:0]] fontName:@"Helvetica" fontSize:14.0];
			[col2 setColor:ccGRAY];
			[col2 setAnchorPoint:ccp(0.0, 0.5)];
			[col2 setPosition:ccp(leftOffset, currentRowOffset)];
			[self addChild:col2];
			
			Label *col3 = [Label labelWithString:[NSString stringWithFormat:@"%d", [[scoreComponents objectAtIndex:1] intValue]] fontName:@"Helvetica" fontSize:14.0];
			[col3 setColor:ccWHITE];
			[col3 setAnchorPoint:ccp(1.0, 0.5)];
			[col3 setPosition:ccp(455.0, currentRowOffset)];
			[self addChild:col3];
			
			idx++;
		}
	}
	return self;
}

- (BOOL)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {	
	CGPoint touchLocation = [self convertTouchToNodeSpace:[touches anyObject]];
	CGRect backButtonRect = CGRectMake(255.0, 15.0, 70.0, 25.0);
	DLog(@"Touching");
	DLog(@"Touch Location: %f %f", touchLocation.x, touchLocation.y);
	if (CGRectContainsPoint(backButtonRect, touchLocation)) {
		[[Director sharedDirector] replaceScene:[FadeTransition transitionWithDuration:1 scene:[MenuScene scene] withColor:ccBLACK]];
	}
	
	return kEventHandled;
}


- (void)dealloc {
	[scoresArray release];
	[super dealloc];
}


@end
