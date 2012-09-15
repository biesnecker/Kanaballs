//
//  PauseLayer.h
//  KanaBalls
//
//  Created by John Biesnecker on 2/4/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"

#define kPauseLayerPauseMode 0
#define kPauseLayerNewMode 1
#define kPauseLayerOverMode 2

@interface PauseLayer : Sprite {
	NSInteger currentMode;
}

- (id)initWithMode:(NSInteger)mode;
- (id)initWithScore:(NSInteger)score;
- (void)recordScore:(NSInteger)s;
- (void)fadeLabel;
- (void)fadeLabelIn;

@property (assign) NSInteger currentMode;

@end
