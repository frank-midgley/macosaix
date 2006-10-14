//
//  PreferencesController.h
//  MacOSaiX.app
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "MacOSaiXPreferencesController.h"


@interface MacOSaiXPreferencesController : NSWindowController
{
	IBOutlet NSTableView				*preferenceTable;
	IBOutlet NSBox						*preferenceBox;
	NSView								*mainPreferencesView;

	NSSize								mainViewMinSize, 
										minSizeBase;
	
	NSMutableArray						*plugInClasses;
	NSMutableDictionary					*plugInControllers;
	
	id<MacOSaiXPreferencesController>	currentController;
	
		// MacOSaiX preferences GUI
	IBOutlet NSButton					*updateCheckBox, 
										*reportCrashesCheckBox, 
										*autoStartCheckBox,
										*autoSaveCheckBox, 
										*showTooltipsCheckBox;
    IBOutlet NSTextField				*autoSaveFrequencyField;
}

- (IBAction)setUpdateCheck:(id)sender;
- (IBAction)setReportCrashes:(id)sender;
- (IBAction)setAutoStart:(id)sender;
- (IBAction)setAutoSave:(id)sender;
- (IBAction)setShowTileTooltips:(id)sender;
- (IBAction)resetWarnings:(id)sender;

@end
