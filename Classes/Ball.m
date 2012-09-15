//
//  Ball.m
//  KanaBalls
//
//  Created by John Biesnecker on 1/28/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import "Ball.h"


@implementation Ball
@synthesize textLabel, ballShape, ballSprite, hasBeenMarked;

- (id)initWithShape:(cpShape*)shape andSprite:(cpSprite*)sprite {
	if ((self = [super init])) {
		self.hasBeenMarked = NO;
		self.ballShape = shape;
		self.ballSprite = sprite;
		self.textLabel = [Label labelWithString:@"" fontName:@"Helvetica" fontSize:25];
		textLabel.color = ccWHITE;
		textLabel.position = ccp(ballSprite.contentSize.width / 2, ballSprite.contentSize.height / 2);
		[ballSprite addChild:textLabel];
	}
	return self;
}

- (void)setLabelText:(NSString *)txt {
	[textLabel setString:txt];
}

- (void)mark {
	if (!hasBeenMarked) {
		[self.ballSprite setTexture:[[TextureMgr sharedTextureMgr] addImage:@"wrongball-2.png"]];
		self.hasBeenMarked = YES;
	}
}

- (void)unmark {
	if (hasBeenMarked) {
		[self.ballSprite setTexture:[[TextureMgr sharedTextureMgr] addImage:@"clickedball.png"]];
		self.hasBeenMarked = NO;
	}
	
}


- (void)dealloc {
	[textLabel release];
	[ballSprite release];
	[super dealloc];
}

@end
