//
//  MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>


@interface MacOSaiX : NSObject
{
	NSMutableArray 	*_tilesSetupControllerClasses,
					*_imageSourceControllerClasses,
					*_loadedPlugInPaths;
}

- (void)openPreferences2:(id)sender;
- (void)discoverPlugIns;
- (NSArray *)tilesSetupControllerClasses;
- (NSArray *)imageSourceControllerClasses;

@end
