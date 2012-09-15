//
//  GameScene.h
//  KanaBalls
//
//  Created by John Biesnecker on 1/28/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"
#import "SpaceManager.h"
#import "cpSprite.h"
#import "cpShapeNode.h"
#import "Ball.h"

@interface GameScene : Layer {
	SpaceManager *sManager;
	cpShape *centerBall;
	Label *centerLabel;
	Label *timeLabel;
	Label *scoreLabel;
	
	// game state variables
	NSInteger gameState;
	NSMutableArray *balls;
	NSInteger currentLevel;
	NSInteger currentBalls;
	NSInteger currentMode;
	NSInteger maxBalls;
	NSInteger score;
	NSInteger currentQuestion;
	NSInteger correctCount;
	NSInteger optionValue;
	NSMutableArray *answers;
	NSMutableArray *answersTemp;
	float timeRemaining;
	BOOL acceptTouches;
	NSString *nextPrompt;
	NSMutableArray *recentKana;
	BOOL didAnswerIncorrectly;
	
	// misc objects
	NSNumberFormatter *timeFormatter;
	NSNumber *cacheReady;
	NSString *currentBackgroundImage;
}

+ (id)scene;

// game (re)start
- (void)startGame;
- (void)setInitialState;

// game cycle related methods
- (void)gameCycle;
- (void)incrementLevel;
- (NSInteger)getMode;
- (void)getAnswers;
- (void)addBalls;
- (void)getQuestion;
- (void)handleCorrectAnswer;
- (void)removeOldBall;
- (void)reward;
- (void)tick:(ccTime)dt;
- (void)pause;
- (void)pause:(BOOL)new;
- (void)finishPause;
- (void)unpause;
- (void)removePauseScreen;
- (void)endGame;

// display update methods
- (void)updateTimeLabel;
- (void)updateScoreLabel;
- (void)resetAllBalls;
- (void)updateBackgroundImage;
- (void)swapBackgrounds;

// utility methods
- (NSInteger)ballCount;
- (void)setTextForBall:(Ball*)ball withAnswer:(NSArray*)answerArray;
- (void)setTextForPrompt:(NSArray*)answerArray;
- (void)finishPromptChange;
- (void)setPromptCorrect;

@property (nonatomic, retain) SpaceManager *sManager;
@property cpShape *centerBall;
@property (nonatomic, retain) Label *centerLabel;
@property (nonatomic, retain) Label *timeLabel;
@property (nonatomic, retain) Label *scoreLabel;

// game state
@property (assign) NSInteger gameState;
@property (nonatomic, retain) NSMutableArray *balls;
@property (assign) NSInteger currentLevel;
@property (assign) NSInteger currentBalls;
@property (assign) NSInteger currentMode;
@property (assign) NSInteger maxBalls;
@property (assign) NSInteger score;
@property (assign) NSInteger optionValue;
@property (nonatomic, retain) NSMutableArray *answers;
@property (nonatomic, retain) NSMutableArray *answersTemp;
@property (readwrite) float timeRemaining;
@property (readwrite) BOOL acceptTouches;
@property (nonatomic, retain) NSString *nextPrompt;
@property (nonatomic, retain) NSMutableArray *recentKana;
@property (readwrite) BOOL didAnswerIncorrectly;

// misc objects

@property (nonatomic, retain) NSNumberFormatter *timeFormatter;
@property (retain) NSNumber *cacheReady;
@property (nonatomic, retain) NSString *currentBackgroundImage;


@end
