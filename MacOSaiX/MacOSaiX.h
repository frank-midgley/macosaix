//
//  MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>


@interface MacOSaiX : NSObject
{
	NSMutableArray 	*tileShapesClasses,
					*imageSourceClasses,
					*loadedPlugInPaths;
	BOOL			quitting;
}

- (void)openPreferences:(id)sender;
- (void)discoverPlugIns;
- (NSArray *)tileShapesClasses;
- (NSArray *)imageSourceClasses;

- (BOOL)isQuitting;

@end
