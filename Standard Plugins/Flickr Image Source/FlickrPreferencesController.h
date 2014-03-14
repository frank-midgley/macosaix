//
//  FlickrPreferencesController.h
//  MacOSaiX
//
//  Created by Frank Midgley on 1/28/06.
//  Copyright 2006 Frank M. Midgley. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXPreferencesController.h"

@class MacOSaiXFlickrCategory;


@interface FlickrPreferencesController : NSObject <MacOSaiXPreferencesController>
{
	IBOutlet NSView					*mainView;
	
	IBOutlet NSTabView				*mainTabView;
	
		// Local Copies tab
	IBOutlet NSTextField			*maxCacheSizeField, 
									*minFreeSpaceField;
	IBOutlet NSPopUpButton			*maxCacheSizePopUp, 
									*minFreeSpacePopUp;
	IBOutlet NSImageView			*volumeImageView;
	IBOutlet NSTextField			*volumeNameField;
	
		// Favorite Groups tab
	IBOutlet NSTableView			*favoriteGroupsTable;
	IBOutlet NSButton				*removeGroupsButton;
	
		// Add Groups sheet
	IBOutlet NSPanel				*addGroupsSheet;
	IBOutlet NSTabView				*addGroupsTabView;
	IBOutlet NSTextField			*searchTextField;
	IBOutlet NSTableView			*searchGroupsView;
	IBOutlet NSOutlineView			*browseGroupsView;
	IBOutlet NSProgressIndicator	*matchingGroupsIndicator;
	IBOutlet NSTextField			*matchingGroupsCountField;
	IBOutlet NSButton				*signInOutButton;
	IBOutlet NSTextField			*signInOutField;
	IBOutlet NSButton				*addGroupsButton;
	NSMutableArray					*matchingGroups;
	NSMutableArray					*categories;
	MacOSaiXFlickrCategory			*myGroups;
	
	NSImage							*browserIcon;
}

	// Local Copies tab
- (IBAction)setMaxCacheSizeMagnitude:(id)sender;
- (IBAction)setMinFreeSpaceMagnitude:(id)sender;
- (IBAction)deleteCachedImages:(id)sender;

	// Favorite Groups tab
- (IBAction)visitGroupPage:(id)sender;
- (IBAction)showAddGroups:(id)sender;
- (IBAction)removeGroups:(id)sender;

	// Add Groups sheet
- (IBAction)signInOut:(id)sender;
- (IBAction)cancelAddGroups:(id)sender;
- (IBAction)addGroups:(id)sender;

@end
