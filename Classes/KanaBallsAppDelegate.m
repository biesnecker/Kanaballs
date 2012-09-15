//
//  KanaBallsAppDelegate.m
//  KanaBalls
//
//  Created by John Biesnecker on 1/28/10.
//  Copyright Qingxi Labs 2010. All rights reserved.
//

#import "KanaBallsAppDelegate.h"
#import "cocos2d.h"
#import "GameScene.h"
#import "MenuScene.h"

@implementation KanaBallsAppDelegate

@synthesize window, db;

- (void) applicationDidFinishLaunching:(UIApplication*)application
{
	
	[application setIdleTimerDisabled:YES];
	[self loadDatabase:[self makeEditableCopyOfDatabase]];
	NSAssert(db != nil, @"DB nil");
	// NEW: Init the window
	window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
	[window setUserInteractionEnabled:YES];
	[window setMultipleTouchEnabled:YES];
	
	
	
	[Director useFastDirector];
	[[Director sharedDirector] setDepthBufferFormat:kDepthBuffer16];

	[[Director sharedDirector] setDeviceOrientation:CCDeviceOrientationLandscapeLeft];
	//[[Director sharedDirector] setDisplayFPS:YES];
	[[Director sharedDirector] setPixelFormat:kPixelFormatRGBA8888];
	[Texture2D setDefaultAlphaPixelFormat:kTexture2DPixelFormat_RGBA8888];
	[[Director sharedDirector] setAnimationInterval:1.0/60];	
	
	[[Director sharedDirector] attachInWindow:window];	

	// preload the main screen textures
	[self preloadTextures];

	
	[window makeKeyAndVisible];	
	[[Director sharedDirector] runWithScene: [MenuScene scene]];

			
}

- (void)preloadTextures {
	
	[[TextureMgr sharedTextureMgr] addImage:@"mainscreen_splash.jpg"];
	[[TextureMgr sharedTextureMgr] addImage:@"mainscreen.jpg"];
	[[TextureMgr sharedTextureMgr] addImage:@"pause.jpg"];
	[[TextureMgr sharedTextureMgr] addImage:@"gameover.jpg"];
	[[TextureMgr sharedTextureMgr] addImage:@"highscores.jpg"];
	[[TextureMgr sharedTextureMgr] addImage:@"options.jpg"];

	NSArray *backgroundImages = [NSArray arrayWithObjects:@"geisha.jpg", @"mountainflowers.jpg", @"temple.jpg", @"shibuya.jpg", @"city.jpg", @"mountain.jpg", nil];
	for(NSString *s in backgroundImages) {
		[[TextureMgr sharedTextureMgr] addImage:s];
	}
	
}


- (void)loadDatabase:(NSString *)DBPath {	
	db = [[FMDatabase databaseWithPath:DBPath] retain];
	NSAssert(db != nil, @"Fuck, database is nil");
	DLog(@"%@", DBPath);
	if (![db open]) {
		DLog(@"Failed to open database");
		NSAssert1(0, @"Failed to open database", nil);
	} else {
		[db setShouldCacheStatements:YES];
		DLog(@"Database open");
	}	
	DLog(@"That was version %@ of sqlite", [FMDatabase sqliteLibVersion]);
	[db setBusyRetryTimeout:10000];
}

- (NSString *)makeEditableCopyOfDatabase {
    // First, test for existence.
    BOOL success;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSError *error;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    NSString *writableDBPath = [documentsDirectory stringByAppendingPathComponent:@"KBalls.sqlite"];
    success = [fileManager fileExistsAtPath:writableDBPath];
	
    if (!success) {
		// The writable database does not exist, so copy the default to the appropriate location.
		NSString *defaultDBPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"KBalls.sqlite"];
		success = [fileManager copyItemAtPath:defaultDBPath toPath:writableDBPath error:&error];
		if (!success) {
			NSAssert1(0, @"Failed to create writable database file with message '%@'.", [error localizedDescription]);
		}
	}
	return writableDBPath;
}




- (void)applicationWillResignActive:(UIApplication *)application {
	[[Director sharedDirector] pause];
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
	[[Director sharedDirector] resume];
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
	[[TextureMgr sharedTextureMgr] removeUnusedTextures];
}

- (void)applicationWillTerminate:(UIApplication *)application {
	[[Director sharedDirector] end];
}

- (void)applicationSignificantTimeChange:(UIApplication *)application {
	[[Director sharedDirector] setNextDeltaTimeZero:YES];
}

- (void)dealloc {
	[[Director sharedDirector] release];
	[db release];
	[window release];
	[super dealloc];
}

@end
