//
//  MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXFullScreenController.h"
#import "MacOSaiXKioskController.h"


@interface MacOSaiX : NSObject
{
	IBOutlet NSMenu			*mosaicMenu, 
							*viewMenu;
	
	NSMutableArray			*tileShapesClasses,
							*imageSourceClasses,
							*loadedPlugInPaths;
	BOOL					quitting;
	
		// Kiosk
	MacOSaiXKioskController	*kioskController;
	NSMutableArray			*kioskMosaicControllers;
}

- (IBAction)openPreferences:(id)sender;
- (void)discoverPlugIns;
- (NSArray *)tileShapesClasses;
- (NSArray *)imageSourceClasses;

- (BOOL)isQuitting;

- (MacOSaiXFullScreenController *)openMosaicWindowOnScreen:(NSScreen *)screen;

- (IBAction)enterKioskMode:(id)sender;

@end
