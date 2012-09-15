//
//  KanaBallsAppDelegate.h
//  KanaBalls
//
//  Created by John Biesnecker on 1/28/10.
//  Copyright Qingxi Labs 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FMDatabase.h"

@interface KanaBallsAppDelegate : NSObject <UIApplicationDelegate> {
	UIWindow *window;
	FMDatabase *db;
}

- (NSString *)makeEditableCopyOfDatabase;
- (void)preloadTextures;
- (void)loadDatabase:(NSString *)DBPath;

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) FMDatabase *db;

@end
