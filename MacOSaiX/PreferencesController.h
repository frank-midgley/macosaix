//
//  PreferencesController.h
//  MacOSaiX.app
//
//  Created by Frank Midgley on Wed May 01 2002.
//  Copyright (c) 2001 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface MacOSaiXPreferencesController : NSWindowController
{
	IBOutlet NSTableView	*preferenceTable;
	IBOutlet NSBox			*preferenceBox;
	NSView					*mainPreferencesView;

	NSMutableArray			*plugInClasses;
	NSMutableDictionary		*plugInControllers;

		// MacOSaiX preferences GUI
	IBOutlet NSButton		*updateCheckBox,
							*autoStartCheckBox,
							*autoSaveCheckBox;
    IBOutlet NSTextField	*autoSaveFrequencyField;
}

- (IBAction)setUpdateCheck:(id)sender;
- (IBAction)setAutoStart:(id)sender;
- (IBAction)setAutoSave:(id)sender;

@end
