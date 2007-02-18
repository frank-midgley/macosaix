//
//  MacOSaiX.h
//  MacOSaiX
//
//  Created by Frank Midgley on Thu Feb 21 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

@class MacOSaiXFullScreenController, MacOSaiXKioskController;


@interface MacOSaiX : NSObject
{
	IBOutlet NSMenu			*editMenu, 
							*viewMenu;
	
	NSMutableArray			*tileShapesPlugIns, 
							*imageOrientationsPlugIns, 
							*imageSourcePlugIns, 
							*loadedPlugInPaths;
	BOOL					quitting;
	
		// Kiosk
	MacOSaiXKioskController	*kioskController;
	NSMutableArray			*kioskMosaicControllers;
}

- (IBAction)openPreferences:(id)sender;

- (void)discoverPlugIns;
- (NSArray *)tileShapesPlugIns;
- (NSArray *)imageOrientationsPlugIns;
- (NSArray *)imageSourcePlugIns;
- (NSArray *)allPlugIns;
- (Class)plugInForDataSourceClass:(Class)dataSourceClass;

- (BOOL)isQuitting;

- (MacOSaiXFullScreenController *)openMosaicWindowOnScreen:(NSScreen *)screen;

- (IBAction)enterKioskMode:(id)sender;
- (BOOL)inKioskMode;

@end
