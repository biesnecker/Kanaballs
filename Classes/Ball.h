//
//  Ball.h
//  KanaBalls
//
//  Created by John Biesnecker on 1/28/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SpaceManager.h"
#import "cpShape.h"
#import "cpSprite.h"

@interface Ball : NSObject {
	Label *textLabel;
	cpShape *ballShape;
	cpSprite *ballSprite;
	BOOL hasBeenMarked;
}

- (id)initWithShape:(cpShape*)shape andSprite:(cpSprite*)sprite;
- (void)setLabelText:(NSString *)txt;
- (void)mark;
- (void)unmark;

@property (nonatomic, retain) Label *textLabel;
@property (readwrite) cpShape* ballShape;
@property (nonatomic, retain) cpSprite *ballSprite;
@property (readwrite) BOOL hasBeenMarked;

@end
