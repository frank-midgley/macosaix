//
//  PreferencesController.h
//  MacOSaiX.app
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 Frank M. Midgley. All rights reserved.
//

@protocol MacOSaiXPlugInPreferencesEditor;


@interface MacOSaiXPreferencesController : NSWindowController
{
	IBOutlet NSTableView				*preferenceTable;
	IBOutlet NSBox						*preferenceBox;
	NSView								*mainPreferencesView; 

	NSSize								mainViewMinSize, 
										minSizeBase;
	
	NSMutableArray						*plugInClasses;
	NSMutableDictionary					*plugInControllers;
	
	id<MacOSaiXPlugInPreferencesEditor>	currentController;
	
		// General preferences
	IBOutlet NSButton					*updateCheckBox, 
										*reportCrashesCheckBox, 
										*autoStartCheckBox,
										*autoSaveCheckBox, 
										*showTooltipsCheckBox;
    IBOutlet NSTextField				*autoSaveFrequencyField;
	
		// Editors
	IBOutlet NSView						*editorsPreferencesView;
	NSSize								editorsViewMinSize;
	IBOutlet NSTableView				*editorsTable;
	
		// Disallowed images
	IBOutlet NSView						*disallowedImagesView;
	NSSize								disallowedImagesViewMinSize;
	IBOutlet NSTableView				*disallowedImagesTable;
	IBOutlet NSButton					*showDisallowedImagesButton, 
										*allowImagesButton;
}

+ (MacOSaiXPreferencesController *)sharedController;

	// General preferences
- (void)showGeneralPreferences:(id)sender;
- (IBAction)setUpdateCheck:(id)sender;
- (IBAction)setReportCrashes:(id)sender;
- (IBAction)setAutoStart:(id)sender;
- (IBAction)setAutoSave:(id)sender;
- (IBAction)setShowTileTooltips:(id)sender;
- (IBAction)resetWarnings:(id)sender;

	// Visible editors
- (void)showVisibleEditors:(id)sender;
- (IBAction)setEditorVisible:(id)sender;
- (IBAction)showEditorDescription:(id)sender;

	// Disallowed images
- (IBAction)showDisallowedImages:(id)sender;
- (IBAction)showImages:(id)sender;
- (IBAction)allowSelectedImages:(id)sender;

@end
