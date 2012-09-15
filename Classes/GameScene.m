//
//  GameScene.m
//  KanaBalls
//
//  Created by John Biesnecker on 1/28/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import "KanaBallsAppDelegate.h"
#import "GameScene.h"
#import "FMDatabase.h"
#import "FMResultSet.h"
#import "chipmunk.h"
#import "PauseLayer.h"
#import "MenuScene.h"

#define kGameStateActive 0
#define kGameStateNew 1
#define kGameStatePaused 2
#define kGameStateOver 3

#define kCollisionTypeBall 0
#define kCollisionTypeGhost 1

#define kItemArrayIndex 0
#define kItemArrayHiragana 1
#define kItemArrayKatakana 2
#define kItemArrayPronunciation 3

#define kGameModeRomaji2Hiragana 1
#define kGameModeRomaji2Katakana 2
#define kGameModeHiragana2Romaji 3
#define kGameModeKatakana2Romaji 4
#define kGameModeHiragana2Katakana 5
#define kGameModeKatakana2Hiragana 6

#define kBackgroundSpriteTag 100
#define kBackgroundSpriteNewTag 101
#define kPauseLayerTag 102
#define kCenterBallSpriteTag 103

#define kBackgroundSpriteFiles [NSArray arrayWithObjects:@"geisha.jpg", @"mountainflowers.jpg", @"temple.jpg", @"shibuya.jpg", @"city.jpg", @"mountain.jpg", nil]

@implementation GameScene

// display
@synthesize sManager, centerBall, centerLabel, timeLabel, scoreLabel;
// game state
@synthesize gameState, balls, currentLevel, currentBalls, currentMode, maxBalls, score, optionValue, answers, answersTemp, timeRemaining, acceptTouches, nextPrompt, recentKana, didAnswerIncorrectly;
// misc objects
@synthesize timeFormatter, cacheReady, currentBackgroundImage;

+ (id)scene {
	Scene *scene = [Scene node];
	Layer *layer = [GameScene node];
	[scene addChild:layer];
	return scene;
}

- (id)init {
	if ((self = [super init])) {
		
			
		self.isTouchEnabled = YES;
		Sprite *backgroundImage = [Sprite node];
		backgroundImage.position = ccp(240.0, 160.0);
		[backgroundImage setTag:kBackgroundSpriteTag];
		[self addChild:backgroundImage];
		
		sManager = [[SpaceManager alloc] init];
		[sManager addWindowContainmentWithFriction:1.0 elasticity:1.2 inset:cpvzero];
		sManager.constantDt = 1.0/55.0;
		sManager.gravity = ccp(0, 0);
		[sManager ignoreCollionBetweenType:kCollisionTypeBall otherType:kCollisionTypeGhost];
		
		NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
		[nc addObserver:self selector:@selector(pause) name:@"UIApplicationWillResignActiveNotification" object:nil];
		
		centerBall = [sManager addCircleAt:cpv(240,160) mass:STATIC_MASS radius:58];
		centerBall->collision_type = kCollisionTypeBall;
		centerBall->e = 1.2f;
		cpSprite *centerBallSprite = [cpSprite spriteWithShape:centerBall file:@"centerball.png"];
		centerBallSprite.ignoreRotation = YES;
		[centerBallSprite setTag:kCenterBallSpriteTag];
		[self addChild:centerBallSprite];
		
		centerLabel = [Label labelWithString:@"" fontName:@"Helvetica" fontSize:40.0f];
		centerLabel.color = ccWHITE;
		centerLabel.position = ccp(centerBallSprite.contentSize.width / 2, centerBallSprite.contentSize.height / 2);
		[centerBallSprite addChild:centerLabel];
		
		timeLabel = [Label labelWithString:@"" fontName:@"Helvetica" fontSize:12.0];
		timeLabel.color = ccWHITE;
		timeLabel.position = ccp(centerBallSprite.contentSize.width / 2, (centerBallSprite.contentSize.height / 2) - 35);
		[centerBallSprite addChild:timeLabel];
		
		scoreLabel = [Label labelWithString:@"" fontName:@"Helvetica" fontSize:12.0];
		scoreLabel.color = ccWHITE;
		scoreLabel.position = ccp(centerBallSprite.contentSize.width / 2, (centerBallSprite.contentSize.height / 2) + 35);
		[centerBallSprite addChild:scoreLabel];
		
		timeFormatter = [[NSNumberFormatter alloc] init];
		[timeFormatter setMinimumFractionDigits:1];
		[timeFormatter setMaximumFractionDigits:1];
		[timeFormatter setMinimumIntegerDigits:1];
		
		[self schedule:@selector(tick:)];
		[sManager start];

		[self startGame];
	}
	return self;
}

/************************************************

 GAME (RESTART)

************************************************/

- (void)startGame {
	[self pause:YES];
	[self setInitialState];
	[self getAnswers];
	[self gameCycle];
}

- (void)setInitialState {
	if (balls == nil) {
		balls = [[NSMutableArray alloc] initWithCapacity:4];
	} else {
		for (Ball *b in balls) {
			[sManager scheduleToRemoveAndFreeShape:b.ballShape];
			[self removeChild:b.ballSprite cleanup:YES];
		}
		[balls removeAllObjects];
	}
	
	if (answers == nil) {
		answers = [[NSMutableArray alloc] init];
	} else {
		[answers removeAllObjects];
	}
	
	if (answersTemp == nil) {
		answersTemp = [[NSMutableArray alloc] init];
	} else {
		[answersTemp removeAllObjects];
	}
	
	[self setCacheReady:[NSNumber numberWithBool:NO]];
	[self updateBackgroundImage];
	
	FMDatabase *db = [AppDelegate db];
	FMResultSet *rs = [db executeQuery:@"SELECT value FROM options WHERE key = 'kanaset'"];
	[rs next];
	optionValue = [rs intForColumn:@"value"];
	[rs close];
	
	score = 0;
	gameState = kGameStateNew;
	currentLevel = 1;
	currentBalls = 0;
	currentMode = 0;
	currentMode = [self getMode];
	currentQuestion = 0;
	timeRemaining = 45.0;
	acceptTouches = YES;
	didAnswerIncorrectly = NO;
	maxBalls = [self ballCount];
	self.recentKana = [NSMutableArray array];
	[self updateTimeLabel];
	[self updateScoreLabel];
}


/************************************************
 
 GAME CYCLE
 
************************************************/

- (void)gameCycle {
	[self incrementLevel];
	[self addBalls];
	[self getQuestion];
	[self performSelectorInBackground:@selector(getAnswers) withObject:nil];
}

- (void)incrementLevel {
	//if (correctCount && (correctCount % (currentLevel * 5) == 0)) {
	DLog(@"1. Correct: %d", correctCount);
	if (correctCount && (correctCount % 10 == 0)) {
		correctCount = 0;
		currentLevel++;
		timeRemaining += 10;
		currentMode = [self getMode];
		[self resetAllBalls];
		DLog(@"2. Correct: %d", correctCount);
		[self updateBackgroundImage];
	}
	maxBalls = [self ballCount];
	
}

- (NSInteger)getMode {
	NSMutableArray *possibleModes = [NSMutableArray array];
	if (optionValue == 0) {
		if (currentMode != kGameModeRomaji2Hiragana) [possibleModes addObject:[NSNumber numberWithInt:kGameModeRomaji2Hiragana]];
		if (currentMode != kGameModeHiragana2Romaji) [possibleModes addObject:[NSNumber numberWithInt:kGameModeHiragana2Romaji]];
	} else if (optionValue == 1) {
		if (currentMode != kGameModeRomaji2Katakana) [possibleModes addObject:[NSNumber numberWithInt:kGameModeRomaji2Katakana]];
		if (currentMode != kGameModeKatakana2Romaji) [possibleModes addObject:[NSNumber numberWithInt:kGameModeKatakana2Romaji]];
	} else if (optionValue == 2) {
		if (currentMode != kGameModeRomaji2Hiragana) [possibleModes addObject:[NSNumber numberWithInt:kGameModeRomaji2Hiragana]];
		if (currentMode != kGameModeHiragana2Romaji) [possibleModes addObject:[NSNumber numberWithInt:kGameModeHiragana2Romaji]];
		if (currentMode != kGameModeRomaji2Katakana) [possibleModes addObject:[NSNumber numberWithInt:kGameModeRomaji2Katakana]];
		if (currentMode != kGameModeKatakana2Romaji) [possibleModes addObject:[NSNumber numberWithInt:kGameModeKatakana2Romaji]];
		if (currentMode != kGameModeHiragana2Katakana) [possibleModes addObject:[NSNumber numberWithInt:kGameModeHiragana2Katakana]];
		if (currentMode != kGameModeKatakana2Hiragana) [possibleModes addObject:[NSNumber numberWithInt:kGameModeKatakana2Hiragana]];
	}
	NSInteger possibleCount = [possibleModes count];
	return [[possibleModes objectAtIndex:(arc4random() % possibleCount)] intValue];
}

- (void)getAnswers {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	NSInteger answersToGet = 2;
	//NSInteger answersToGet = maxBalls - currentBalls;
	if (answersToGet == 0) return;
	NSString *limiterSQL;
	if ([recentKana count] > 0) {
		NSMutableArray *finalLimit = [[recentKana mutableCopy] autorelease];
		for (NSArray *a in answers) {
			[finalLimit addObject:[a objectAtIndex:0]];
		}
		NSString *limiter = [finalLimit componentsJoinedByString:@","];
		limiterSQL = [NSString stringWithFormat:@"AND uid NOT IN (%@)", limiter];
	} else {
		limiterSQL = @"";
	}
	
	FMDatabase *db = [AppDelegate db];
	NSAssert (db != nil, @"Database nil here");
	NSString *query = [NSString stringWithFormat:@"SELECT * FROM kana WHERE 1=1 %@ ORDER BY RANDOM() LIMIT %d", limiterSQL, answersToGet];
	FMResultSet *rs = [db executeQuery:query];
	while ([rs next]) {
		NSArray *newItem = [NSArray arrayWithObjects:[NSNumber numberWithInt:[rs intForColumn:@"uid"]], [rs stringForColumn:@"hiragana"], [rs stringForColumn:@"katakana"], [[rs stringForColumn:@"pronunciation"] uppercaseString], nil];
		[answersTemp addObject:newItem];
	}
	[rs close];
	[self setCacheReady:[NSNumber numberWithBool:YES]];
	[pool release];
}

- (void)addBalls {
	if (![cacheReady boolValue]) {
		[NSThread sleepForTimeInterval:0.1];
	}
	
	
	float minX = 36.0f;
	float maxX = 480.0f - 36.0f;
	float minY = 36.0f;
	float maxY = 320.0f - 36.0f;
	
	float coordX;
	float coordY;
	
	BOOL overlaps = NO;
	CGRect centerBallRect = CGRectMake(240 - 58, 160 - 58, 58 *2, 58 * 2);
	
	NSInteger ballsToAdd = maxBalls - currentBalls;
	for (int idx = 0; idx < ballsToAdd; idx++) {
		
		do {
			overlaps = NO;

			coordX = (float)((arc4random() % (int)(maxX - minX)) + minX);
			coordY = (float)((arc4random() % (int)(maxY - minY)) + minY);

			CGRect newBallRect = CGRectMake(coordX - 35.0f, coordY - 35.0f, 70.0f, 70.0f);
			
			if (CGRectIntersectsRect(centerBallRect, newBallRect)) {
				overlaps = YES;
			}
			if (!overlaps) {
				
			}
		} while (overlaps);
		
		cpShape *ballShape = [sManager addCircleAt:ccp(coordX, coordY) mass:10.0 radius:35.0];
		ballShape->collision_type = kCollisionTypeBall;
		ballShape->e = 0.75f;
		
		cpSprite *ballSprite = [cpSprite spriteWithShape:ballShape file:@"clickedball.png"];
		ballSprite.opacity = 0;
		ballSprite.ignoreRotation = YES;
		[ballSprite runAction:[FadeIn actionWithDuration:0.2]];
		
		Ball *ball = [[Ball alloc] initWithShape:ballShape andSprite:ballSprite];
		[self.balls addObject:ball];
		[self setTextForBall:ball withAnswer:[answersTemp objectAtIndex:idx]];
		[ball release];
		
		[recentKana insertObject:[[answersTemp objectAtIndex:idx] objectAtIndex:0] atIndex:0];
		
		CGPoint forceVector = ccp((arc4random() % 2000) * 1.0f, (arc4random() % 2000) * 1.0f);
		[ballSprite applyImpulse:forceVector];
	
		currentBalls++;
		[self addChild:ballSprite];
	}
	NSRange usedRange = NSMakeRange(0, ballsToAdd);
	[answers addObjectsFromArray:[answersTemp subarrayWithRange:usedRange]];
	
	if ([recentKana count] > 25) {
		NSRange limitCut = NSMakeRange(25, [recentKana count] - 25);
		[recentKana removeObjectsInRange:limitCut];
	}
	DLog(@"Recent kana array count: %d", [recentKana count]);
	
	[answersTemp removeAllObjects];
	acceptTouches = YES;
}

- (void)getQuestion {
	NSInteger questionCount = [answers count];
	currentQuestion = arc4random() % questionCount;
	[self setTextForPrompt:[answers objectAtIndex:currentQuestion]];
}


- (void)handleCorrectAnswer {
	
	Ball *correctBall = [balls objectAtIndex:currentQuestion];
	correctBall.ballShape->collision_type = kCollisionTypeGhost;
	
	for (int idx = 0; idx < maxBalls; idx++) {
		if (idx != currentQuestion) {
			Ball *tBall = [balls objectAtIndex:idx];
			[tBall unmark];
			//DLog(@"Velocity %f %f", tBall.ballShape->body->v.x, tBall.ballShape->body->v.y);
			//CGPoint forceVect = ccpMult(ccpNormalize(tBall.ballShape->body->v), 1000);
			//[tBall.ballSprite applyImpulse:forceVect];
			CGPoint forceVect = ccpNormalize(ccpNeg(ccpSub(correctBall.ballSprite.position, tBall.ballSprite.position)));
			[tBall.ballSprite applyImpulse:ccpMult(forceVect, 10000 / sqrt(fabs(ccpDistance(correctBall.ballSprite.position, tBall.ballSprite.position))))];
			/*if (tBall.ballShape->body->v.x > 150.0) tBall.ballShape->body->v.x = 150.0;
			if (tBall.ballShape->body->v.x < -150.0) tBall.ballShape->body->v.x = -150.0;
			if (tBall.ballShape->body->v.y > 150.0) tBall.ballShape->body->v.y = 150.0;
			if (tBall.ballShape->body->v.y < -150.0) tBall.ballShape->body->v.y = -150.0;*/
		}
	}
	correctCount ++;
	
	id promptSwitchAnimation = [Sequence actions:[FadeOut actionWithDuration:0.15], [CallFunc actionWithTarget:self selector:@selector(setPromptCorrect)] ,[FadeIn actionWithDuration:0.15], nil];
	[centerLabel runAction:promptSwitchAnimation];
	
	id scaleAction = [ScaleBy actionWithDuration:0.5 scale:3.0f];
	id fadeAction = [FadeOut actionWithDuration:0.5];
	id callback = [CallFunc actionWithTarget:self selector:@selector(removeOldBall)];
	[correctBall.ballSprite runAction:[Sequence actionOne:[Spawn actions:scaleAction, fadeAction, nil] two:callback]];
	[correctBall.textLabel runAction:[[fadeAction copy] autorelease]];
	[self reward];
}

- (void)removeOldBall {
	Ball *correctBall = [balls objectAtIndex:currentQuestion];
	[sManager scheduleToRemoveAndFreeShape:correctBall.ballShape];
	[self removeChild:correctBall.ballSprite cleanup:YES];
	[balls removeObjectAtIndex:currentQuestion];
	[answers removeObjectAtIndex:currentQuestion];
	currentBalls--;
	[self gameCycle];
}

- (void)reward {
	if (!didAnswerIncorrectly) {
		float timeChange = (2 - (currentLevel * 0.1));
		if (timeChange < 0.75) timeChange = 0.75;
		timeRemaining += timeChange;
		score += (100 * (1 + ((currentLevel - 1) * 0.1)));
		[self updateScoreLabel];
	}
	didAnswerIncorrectly = NO;
}

- (void)l:(ccTime)dt {
	if (gameState == kGameStateActive) {
		self.timeRemaining -= dt;
		[self updateTimeLabel];
		if (timeRemaining <= 0) {
			[self endGame];
		}
	}
}

- (void)pause {
	[self pause:NO];
}

- (void)pause:(BOOL)new {
	if ((gameState == kGameStateNew) || (gameState == kGameStatePaused) || (gameState == kGameStateOver)) return;
	NSInteger pauseScreenState;
	if (new) {
		gameState = kGameStateNew;
		pauseScreenState = kPauseLayerNewMode;
	} else {
		gameState = kGameStatePaused;
		pauseScreenState = kPauseLayerPauseMode;
	}
	PauseLayer *pl = [[[PauseLayer alloc] initWithMode:pauseScreenState] autorelease];
	pl.position = ccp(240.0, 160.0);
	pl.opacity = 0;
	[self addChild:pl z:99 tag:kPauseLayerTag];
	
	if (new) {
		pl.opacity = 255;
		[self finishPause];
	} else {
		[pl fadeLabelIn];
		id fadeInAction = [Sequence actions:[FadeIn actionWithDuration:0.25], [CallFunc actionWithTarget:self selector:@selector(finishPause)], nil];
		[pl runAction:fadeInAction];
	}
}

- (void)finishPause {
	[sManager stop];
	//[[Director sharedDirector] pause];
}

- (void)unpause {
	if (gameState == kGameStateActive) return;
	PauseLayer *pl = (PauseLayer*)[self getChildByTag:kPauseLayerTag];
	
	id fadeOutAndRemove = [Sequence actions:[FadeOut actionWithDuration:0.25], [CallFunc actionWithTarget:self selector:@selector(removePauseScreen)], nil];
	[pl fadeLabel];
	[pl runAction:fadeOutAndRemove];
	
	[sManager start];
	//[[Director sharedDirector] resume];
	gameState = kGameStateActive;
}

- (void)removePauseScreen {
	[self removeChildByTag:kPauseLayerTag cleanup:YES];
}

- (void)endGame {
	gameState = kGameStateOver;
	PauseLayer *pl = [[[PauseLayer alloc] initWithScore:score] autorelease];
	pl.position = ccp(240.0, 160.0);
	pl.opacity = 0;
	[self addChild:pl z:99 tag:kPauseLayerTag];
	
	[pl fadeLabelIn];
	id fadeInAction = [Sequence actions:[FadeIn actionWithDuration:0.25], [CallFunc actionWithTarget:self selector:@selector(finishPause)], nil];
	[pl runAction:fadeInAction];
}


/************************************************
 
 DISPLAY UPDATE METHODS
 
************************************************/

- (void)updateTimeLabel {
	if (timeRemaining < 10) {
		timeLabel.color = ccRED;
	} else {
		timeLabel.color = ccWHITE;
	}
	if (timeRemaining < 0) timeRemaining = 0;
	
	[timeLabel setString:[NSString stringWithFormat:@"%@s", [timeFormatter stringFromNumber:[NSNumber numberWithFloat:timeRemaining]]]];
	//[self.timeLabel setString:[NSString stringWithFormat:@"%f", timeRemaining]];
	
}

- (void)updateScoreLabel {
	[scoreLabel setString:[NSString stringWithFormat:@"%d", score]];
}

- (void)resetAllBalls {
	//[self setTextForPrompt:[answers objectAtIndex:currentQuestion]];
	for (int idx = 0; idx < [balls count]; idx++) {
		[self setTextForBall:[balls objectAtIndex:idx] withAnswer:[answers objectAtIndex:idx]];
	}
}
	 
- (void)updateBackgroundImage {
	DLog(@"Updating background image");
	NSArray *backgroundImages = kBackgroundSpriteFiles;
	BOOL found = NO;
	BOOL doFade = NO;
	
	// if there's already a background image, fade the new one in
	// otherwise just make the new one appear
	if ([self getChildByTag:kBackgroundSpriteTag] != nil) {
		doFade = YES;
	}
	
	NSString *newBackgroundImage;
	do {
		int idx = arc4random() % [backgroundImages count];
		if ((currentBackgroundImage == nil) || (![currentBackgroundImage isEqualToString:[backgroundImages objectAtIndex:idx]])) {
			newBackgroundImage = [backgroundImages objectAtIndex:idx];
			found = YES;
		}
	} while (!found);
	
	
	Sprite *bgImage = (Sprite*)[self getChildByTag:kBackgroundSpriteTag];
	if (doFade) {
		Sprite *newBg = [Sprite node];
		[newBg setTexture:[[TextureMgr sharedTextureMgr] addImage:newBackgroundImage]];
		newBg.position = ccp(240.0, 160.0);
		newBg.opacity = 0;
		[self addChild:newBg z:-1 tag:kBackgroundSpriteNewTag];
		
		id fadeOutAndRemove = [Sequence actions:[DelayTime actionWithDuration:0.1], [FadeOut actionWithDuration:0.5], [CallFunc actionWithTarget:self selector:@selector(swapBackgrounds)], nil];
		id fadeIn = [FadeIn actionWithDuration:0.5];
		[newBg runAction:fadeIn];
		[bgImage runAction:fadeOutAndRemove];
		
	} else {
		// just plant the sucker
		[bgImage setTexture:[[TextureMgr sharedTextureMgr] addImage:newBackgroundImage]];
	}
	self.currentBackgroundImage = newBackgroundImage;

}

- (void)swapBackgrounds {
	DLog(@"Swapping backgrounds");
	[self removeChildByTag:kBackgroundSpriteTag cleanup:YES];
	Sprite *bgImage = (Sprite*)[self getChildByTag:kBackgroundSpriteNewTag];
	bgImage.tag = kBackgroundSpriteTag;
}
 

/************************************************
 
 UTILITY METHODS
 
************************************************/

- (void)setTextForBall:(Ball*)ball withAnswer:(NSArray*)answerArray {
	NSInteger modeSelector;
	if ((currentMode == kGameModeRomaji2Hiragana) || (currentMode == kGameModeKatakana2Hiragana)) {
		modeSelector = kItemArrayHiragana;
	} else if ((currentMode == kGameModeRomaji2Katakana) || (currentMode == kGameModeHiragana2Katakana)) {
		modeSelector = kItemArrayKatakana;
	} else {
		modeSelector = kItemArrayPronunciation;
	}
	
	[ball setLabelText:[answerArray objectAtIndex:modeSelector]];
}
	
- (void)setTextForPrompt:(NSArray*)answerArray {
	NSInteger modeSelector;
	if ((currentMode == kGameModeRomaji2Hiragana) || (currentMode == kGameModeRomaji2Katakana)) {
		modeSelector = kItemArrayPronunciation;
	} else if ((currentMode == kGameModeHiragana2Romaji) || (currentMode == kGameModeHiragana2Katakana)) {
		modeSelector = kItemArrayHiragana;
	} else {
		modeSelector = kItemArrayKatakana;
	}
	
	self.nextPrompt = [answerArray objectAtIndex:modeSelector];
	//[centerLabel setString:[answerArray objectAtIndex:modeSelector]];
	
	id promptSwitchAnimation = [Sequence actions:[FadeOut actionWithDuration:0.15], [CallFunc actionWithTarget:self selector:@selector(finishPromptChange)] ,[FadeIn actionWithDuration:0.15], nil];
	[centerLabel runAction:promptSwitchAnimation];
	
}

- (void)finishPromptChange {
	centerLabel.color = ccWHITE;
	[centerLabel setString:nextPrompt];
}

- (void)setPromptCorrect {
	centerLabel.color = ccGREEN;
	[centerLabel setString:@"正答"];
}

- (NSInteger)ballCount {
	int extra = 0;
	int cLevel = currentLevel - 1;
	//extra = floor(cLevel / 5);
	extra = floor(cLevel / 2);
	int total = 2 + extra;
	if (total > 8) {
		return 8;
	} else {
		return total;
	}
}


- (BOOL)ccTouchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {	
	if (!acceptTouches) return kEventHandled;
	UITouch *touch = [touches anyObject];
	CGPoint touchLocation = [self convertTouchToNodeSpace:touch];
	
	if ((gameState == kGameStatePaused) || (gameState == kGameStateNew)) {
		if (gameState == kGameStatePaused) {
			CGRect quitButtonBox = CGRectMake(205, 25, 70, 70);
			if (CGRectContainsPoint(quitButtonBox, touchLocation)) {
				[[Director sharedDirector] replaceScene:[FadeTransition transitionWithDuration:1 scene:[MenuScene scene] withColor:ccBLACK]];

			}
		}
		if ([touch tapCount] == 2) {
			[self unpause];
		}
		return kEventHandled;
	} else if (gameState == kGameStateOver) {
		CGRect newButtonBox = CGRectMake(125, 25, 70, 70);
		CGRect quitButtonBox = CGRectMake(285, 25, 70, 70);
		if (CGRectContainsPoint(newButtonBox, touchLocation)) {
			DLog(@"new game");
			[self startGame];
			[self unpause];
		} else if (CGRectContainsPoint(quitButtonBox, touchLocation)) {
			DLog(@"quit game");
			[[Director sharedDirector] replaceScene:[FadeTransition transitionWithDuration:1 scene:[MenuScene scene] withColor:ccBLACK]];
		}
	} else if (gameState == kGameStateActive) {
		if ([touch tapCount] > 1) {
			Sprite *cSprite = (Sprite*)[self getChildByTag:kCenterBallSpriteTag];
			CGRect centerBallRect = CGRectMake(cSprite.position.x - (cSprite.contentSize.width / 2), cSprite.position.y - (cSprite.contentSize.height / 2), cSprite.contentSize.width, cSprite.contentSize.height);
			if (CGRectContainsPoint(centerBallRect, touchLocation)) {
				[self pause:NO];
			}
		}
		NSInteger idx = 0;
		for (Ball *b in balls) {
			//cpSprite *s = b.ballSprite;
			//CGRect ballRect = CGRectMake(s.position.x - 35, s.position.y - 35, 70, 70);
			if (cpShapePointQuery(b.ballShape, touchLocation, b.ballShape->layers, b.ballShape->group)) {
				if (idx == currentQuestion) {
					acceptTouches = NO;
					[self handleCorrectAnswer];
				} else {
					didAnswerIncorrectly = YES;
					[b mark];
				}
				return kEventHandled;
			}
			idx++;
		}
	}
	
	return kEventIgnored;
}

- (void)dealloc {
	NSNotificationCenter *ns = [NSNotificationCenter defaultCenter];
	[ns removeObserver:self];
	[recentKana release];
	[nextPrompt release];
	[cacheReady release];
	[timeFormatter release];
	[answers release];
	[answersTemp release];
	[balls release];
	//[centerLabel release];
	[sManager release];
	[super dealloc];
}

@end
