//
//  PreferencesController.h
//  MacOSaiX.app
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

@protocol MacOSaiXPlugInPreferencesEditor;


@interface MacOSaiXPreferencesController : NSWindowController
{
	IBOutlet NSTableView				*preferenceTable;
	IBOutlet NSBox						*preferenceBox;
	NSView								*mainPreferencesView; 
	IBOutlet NSView						*editorsPreferencesView;

	NSSize								mainViewMinSize, 
										minSizeBase, 
										editorsViewMinSize;
	
	NSMutableArray						*plugInClasses;
	NSMutableDictionary					*plugInControllers;
	
	id<MacOSaiXPlugInPreferencesEditor>	currentController;
	
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
