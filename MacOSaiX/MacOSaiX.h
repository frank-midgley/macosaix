//
//  MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXKioskController.h"


@interface MacOSaiX : NSObject
{
	IBOutlet NSMenu			*originalImagesMenu;
	
	NSMutableArray			*tileShapesClasses,
							*imageSourceClasses,
							*loadedPlugInPaths;
	BOOL					quitting;
	
		// Kiosk
	MacOSaiXKioskController	*kioskController;
	NSMutableArray			*kioskMosaicControllers;
}

- (NSMenu *)originalImagesMenu;

- (void)openPreferences:(id)sender;
- (void)discoverPlugIns;
- (NSArray *)tileShapesClasses;
- (NSArray *)imageSourceClasses;

- (BOOL)isQuitting;

- (IBAction)enterKioskMode:(id)sender;

@end
