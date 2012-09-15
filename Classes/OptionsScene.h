//
//  OptionsScene.h
//  KanaBalls
//
//  Created by John Biesnecker on 2/5/10.
//  Copyright 2010 Qingxi Labs. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"

@interface OptionsScene : Layer {
	NSInteger optionSetting;
}

+ (id)scene;
- (void)setOption:(NSInteger)val;

@property (readwrite) NSInteger optionSetting;

@end
